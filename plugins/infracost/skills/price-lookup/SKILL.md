---
name: infracost-price-lookup
description: Look up cloud resource pricing by generating sample Terraform and pricing it with Infracost. Use this skill when the user asks "how much does X cost?" or wants to compare pricing between resource configurations, instance types, regions, or cloud providers. This does not require the user to have any existing infrastructure code.
---

# Price Lookup

Look up cloud resource pricing without needing existing infrastructure code. Supports any resource type that Terraform and Infracost support across AWS, GCP, and Azure.

You synthesize a small Terraform snippet for what the user is asking about and price it. The result is a per-resource breakdown plus a headline summary.

## Invoking capabilities

This skill uses the **price** capability (and optionally the **inspect** capabilities to reproject
the result). Each has two bindings — a typed MCP tool call and an `infracost …` CLI command —
listed in [BINDINGS.md](../../BINDINGS.md).

**Rule: if the Infracost MCP server is available, use its tools; otherwise run the equivalent CLI
command from BINDINGS.md.** With MCP, the snippet is passed as a string to the `price` tool. With
the CLI, the snippet is fed to `infracost price` on stdin via a heredoc (this is the one command in
the skill set that needs a shell metacharacter — see BINDINGS.md).

**Before pricing**, satisfy the three preflight capabilities (see BINDINGS.md): the CLI is present,
the user is authenticated, and an organization is selected. With MCP these are resolved on the first
tool call (failures come back as readable errors, not a dropped connection); with the CLI, check
them inline. Never run `infracost auth login` — it is interactive.

## Workflow

### 1. Write minimal Terraform

Synthesize a small Terraform snippet for the resource(s) the user is asking about. Rules:

- **Minimal config only** — no backends, no variable files, no outputs, no data sources. Just a provider block and the resource(s).
- **Include attributes that affect pricing** — instance type, storage size/type, engine version, throughput, IOPS, etc. These are the knobs that change the price, so they must be present.
- **Use the user's requested configuration** — if they ask for "m5.xlarge with 100GB gp3", write exactly that. If they ask generically ("how much does an RDS instance cost?"), pick reasonable defaults and clearly state what you chose.
- **Set the region** — use the region the user asks for, or default to `us-east-1` and mention it.
- **Multiple resources are fine** — if the user asks about several resource types, put them all in the same snippet.
- **Use realistic names** — name resources descriptively (e.g. `aws_instance.web_server`, not `aws_instance.example`) so the output is easier to read.

### 2. Price the snippet

Use the **price** capability with the Terraform snippet (see BINDINGS.md for the exact MCP tool /
CLI invocation):

```hcl
provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "m5.xlarge"

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }
}
```

For non-USD currencies pass a `currency` (ISO 4217 code — `EUR`, `GBP`, `JPY`, `CAD`, `AUD`, …). If
the user doesn't specify a currency, the org-configured default is used (typically `USD`).

### 3. Read the result

A price returns:

- `currency` — the ISO code in use.
- `summary` — headline counts (resource counts, monthly cost, etc.) — the same shape a scan returns.
- `resources[]` — one row per top-level resource you sent in, with:
  - `name`, `type`, `is_supported`, `is_free`
  - `total_monthly_cost` — pre-summed across cost components AND any nested subresources (e.g. an EKS NodeGroup's LaunchTemplate + EBS volumes are folded into the parent's total).
  - `cost_components[]` — per-component breakdown (vCPU, storage, IOPS, …) with unit, price, quantity, and the monthly costs.
  - `tags`, `supports_tags`, `supports_default_tags`, `metadata` (filename + line in the synthesized Terraform).

Unlike a scan, a price always includes the per-resource list — you've just shipped the IaC, so the cost of returning it is fixed and small.

### 4. Optional: drill in with the inspect capabilities

The price result is cached just like a scan result. If you want to project the data differently
(e.g. group by type, top N by cost), use any of the inspect capabilities — they all read the latest
cached result by default:

- *summary* — same summary block rebuilt through the inspect filter pipeline (project to specific fields or scope by project / provider).
- *top N savings* — top N FinOps savings opportunities on the priced resources (if any).
- *aggregate resources by dimension* (e.g. by type, provider) — reproject the per-resource list.

These rarely add value over reading `resources[]` directly when the snippet is small, but they're handy for "what would the top 5 savings be on this?" follow-ups.

## Presenting Results

Lead with the monthly cost — that's what the user came for.

- **Total monthly cost first**, then the per-component breakdown.
- **Call out usage-based costs.** Some line items (data transfer, requests, etc.) depend on actual usage and use typical-default assumptions. Be explicit about what the estimate assumed.
- **State the region.** Pricing varies by region — always say which one you used.
- **Compare side-by-side when asked.** For "m5.xlarge vs m5.2xlarge" questions, price once with both resources in the snippet and present a comparison table.
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

- Do not commit any generated Terraform — the snippet you build is throwaway, never written to the user's workspace.
- Do not modify the CLI source code unless the user explicitly asks for it — this skill is for _using_ Infracost.
- If a price reports an authentication error or "no organization selected", relay the actionable message back to the user — don't retry blindly. Auth + org are resolved on the first tool call, so the message tells the user what to do: run `infracost auth login` in their own terminal (interactive — never run it yourself), or `infracost org switch <slug>` for one of the slugs the error lists. The running MCP server picks up a saved org selection on its next call.
- If you're unsure of the Terraform resource name for what the user is asking about, look it up rather than guessing — an incorrect resource type will produce no pricing data.
