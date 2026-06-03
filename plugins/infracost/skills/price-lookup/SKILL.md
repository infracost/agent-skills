---
name: infracost-price-lookup
description: Look up cloud resource pricing by generating sample Terraform and pricing it via the Infracost MCP server. Use this skill when the user asks "how much does X cost?" or wants to compare pricing between resource configurations, instance types, regions, or cloud providers. This does not require the user to have any existing infrastructure code.
---

# Price Lookup

Look up cloud resource pricing without needing existing infrastructure code. Supports any resource type that Terraform and Infracost support across AWS, GCP, and Azure.

This plugin ships an MCP server that exposes a `price` tool. The agent passes a Terraform snippet as a string and the tool returns a per-resource breakdown plus a headline summary — no temp files, no stdin pipes, no JSON parsing.

## Setup

**Important**: Verify the Infracost CLI is installed, the user is authenticated, and an organization is selected before running any price lookups.

1. Check the CLI is on the path:

   ```bash
   infracost --version
   ```

   If this fails, inform the user that they need to install the Infracost CLI by following the instructions at https://www.infracost.io/docs/features/get_started/.

2. Check the user is logged in and has an organization selected:

   ```bash
   infracost auth whoami
   ```

   If this reports that the user is not authenticated, ask them to run `infracost auth login` in a separate terminal window and let you know once it completes. Do not attempt to run the login command yourself — it is interactive.

   The output also lists the user's organizations. If there is more than one and none is marked active (a `✔` next to its slug), `whoami` prints a "No organization selected" warning at the bottom — when you see that warning, the CLI cannot pick an org for you in a non-interactive session and downstream commands will fail with `no organization selected`. Ask the user which organization they want to use for this session, then apply their answer using one of these (in order of preference for agentic use):

   - Pass `--org <slug>` on every subsequent `infracost` command — scoped to the current call only.
   - Or set `export INFRACOST_CLI_ORG=<slug>` for the rest of the shell session.
   - Or run `infracost org switch <slug>` once to save the choice globally (only if the user explicitly wants to change their default), or `infracost org switch <slug> --repo` to pin it to the current repository.

   Single-org users never need this step — the CLI auto-selects.

   If a later command fails with `no organization selected`, the error message lists the available slugs inline; loop back and apply the user's choice via one of the methods above before retrying.

## Workflow

### 1. Write minimal Terraform

Synthesize a small Terraform snippet for the resource(s) the user is asking about. Rules:

- **Minimal config only** — no backends, no variable files, no outputs, no data sources. Just a provider block and the resource(s).
- **Include attributes that affect pricing** — instance type, storage size/type, engine version, throughput, IOPS, etc. These are the knobs that change the price, so they must be present.
- **Use the user's requested configuration** — if they ask for "m5.xlarge with 100GB gp3", write exactly that. If they ask generically ("how much does an RDS instance cost?"), pick reasonable defaults and clearly state what you chose.
- **Set the region** — use the region the user asks for, or default to `us-east-1` and mention it.
- **Multiple resources are fine** — if the user asks about several resource types, put them all in the same snippet.
- **Use realistic names** — name resources descriptively (e.g. `aws_instance.web_server`, not `aws_instance.example`) so the output is easier to read.

### 2. Call the `price` MCP tool

Pass the Terraform as the `iac` field:

```
price(iac="""
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "m5.xlarge"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }
}
""")
```

For non-USD currencies pass the `currency` field (ISO 4217 code — `EUR`, `GBP`, `JPY`, `CAD`, `AUD`, …):

```
price(iac="...", currency="EUR")
```

If the user doesn't specify a currency, the tool uses the org-configured default (typically `USD`).

### 3. Read the result

`price` returns:

- `currency` — the ISO code in use.
- `summary` — headline counts (resource counts, monthly cost, etc.) — the same shape `scan` returns.
- `resources[]` — one row per top-level resource you sent in, with:
  - `name`, `type`, `is_supported`, `is_free`
  - `total_monthly_cost` — pre-summed across cost components AND any nested subresources (e.g. an EKS NodeGroup's LaunchTemplate + EBS volumes are folded into the parent's total).
  - `cost_components[]` — per-component breakdown (vCPU, storage, IOPS, …) with unit, price, quantity, and the monthly costs.
  - `tags`, `supports_tags`, `supports_default_tags`, `metadata` (filename + line in the synthesized Terraform).

Unlike `scan`, `price` always includes the per-resource list — the agent has just shipped the IaC, so the cost of returning it is fixed and small.

### 4. Optional: drill in with inspect tools

The price result is cached in the MCP session just like a scan result. If you want to project the data differently (e.g. group by type, top N by cost), call any of the `inspect_*` tools — they all read the latest cached result by default:

- `inspect_summary` — same summary block but rebuilt through the inspect filter pipeline (lets you project to specific fields or scope by project / provider).
- `inspect_top_savings(n=5)` — top N FinOps savings opportunities on the priced resources (if any).
- `inspect_resources(group_by=["type"])` — aggregate the per-resource list by type, provider, etc.

These rarely add value over reading `resources[]` directly when the snippet is small, but they're handy for "what would the top 5 savings be on this?" follow-ups.

## Presenting Results

Lead with the monthly cost — that's what the user came for.

- **Total monthly cost first**, then the per-component breakdown.
- **Call out usage-based costs.** Some line items (data transfer, requests, etc.) depend on actual usage and use typical-default assumptions. Be explicit about what the estimate assumed.
- **State the region.** Pricing varies by region — always say which one you used.
- **Compare side-by-side when asked.** For "m5.xlarge vs m5.2xlarge" questions, call `price` once with both resources in the IaC and present a comparison table.
- **Surface FinOps recommendations.** If the result shows applicable FinOps policies (e.g., "use GP3 instead of GP2", "consider Graviton"), highlight them with the potential savings.

### Example presentation

> **AWS RDS MySQL — db.r5.xlarge, 100GB gp3**
> Region: us-east-1
>
> | Component            | Monthly Cost |
> | -------------------- | ------------ |
> | Instance (on-demand) | $365.00      |
> | Storage (100GB gp3)  | $11.50       |
> | **Total**            | **$376.50**  |
>
> Usage-based costs (estimated):
>
> - I/O requests: ~$X/mo based on typical usage
>
> Savings opportunity: Consider Graviton (db.r6g.xlarge) for ~20% savings (~$73/mo).

## Important Guidelines

- Do not commit any generated Terraform — the snippet you build for the `price` tool is throwaway, never written to the user's workspace.
- Do not modify the CLI source code unless the user explicitly asks for it — this skill is for _using_ the MCP server.
- If `price` returns an error like "no organizations selected" or "not authenticated", relay the actionable message back to the user — don't retry blindly. The MCP server checks auth + org at startup; a runtime error means the user needs to act (`infracost auth login`, `infracost org switch <slug>`).
- If you're unsure of the Terraform resource name for what the user is asking about, look it up rather than guessing — an incorrect resource type will produce no pricing data.