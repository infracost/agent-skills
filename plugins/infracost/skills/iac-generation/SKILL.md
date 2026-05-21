---
name: iac-generation
description: >-
  Ensures cost optimization and FinOps/tagging policy compliance for infrastructure as code.
  BLOCKING REQUIREMENT - Invoke this skill BEFORE generating any IaC code, entering plan mode, or asking clarification questions.
  TRIGGER when: planning or writing code which creates cloud infrastructure resources (regardless of naming a specific tool to do so), imports IaC provider SDKs (pulumi-aws, hashicorp/aws, aws-cdk), or the task involves writing Pulumi, Terraform, CloudFormation, CDK, or Terragrunt.
  DO NOT TRIGGER when: general programming unrelated to infrastructure provisioning.
---

# Infracost IaC Generation Assistance

Assists when creating or modifying infrastructure as code (IaC) to ensure best practices are followed and costs are optimized from the start. Uses the Infracost MCP server (started automatically by this plugin) to analyze code as it's being written, providing real-time feedback on cost implications and optimization recommendations.

The output includes actionable insights: more cost-effective resource types, savings opportunities, FinOps policy violations flagged before deploy, and guidance on the user's organization's guidelines (tagging policies, required resource configurations) so problems are caught early rather than during code review.

Directly supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.

Other IaC languages are also indirectly supported if you convert the resource definitions to Terraform (written to a temporary directory) and then scan that directory.

## MCP tools you'll use

Five tools matter for this workflow:

1. `policies` — list all FinOps + tagging policies for the user's organization, so we can write compliant code from the start.
2. `guardrails` — list cost guardrails (spending thresholds) configured for the repository, so we can keep the generated infrastructure within budget.
3. `budgets` — list tag-scoped budgets for the organization, so we can see which tag groups are already near or over their actual cloud spend limits.
4. `price` — price a small, standalone piece of Terraform without writing it to disk. Use for fast feedback while iterating on individual resources.
5. `scan` — analyze an IaC directory and return costs, diagnostics, and policy violations. Use once you have a complete set of files.

The MCP server handles auth + active-org resolution at startup. If any tool returns "no organization selected" or "not authenticated", relay the actionable message to the user — don't retry blindly.

## Workflow

When writing or modifying IaC, follow this order:

### 1. Establish org context

Before generating any code, call the three "what's the org configured?" tools so the generated infrastructure is compliant by construction:

- `policies()` — list FinOps and tagging policies. For tagging policies with `requirements`, note any `mandatory` tags and the `allowed_values` lists. **If a tagging policy allows a list of acceptable values (or no specific value) and you're not sure which to pick, ask the user.** E.g., if a policy requires `cost_center` ∈ {`engineering`, `marketing`}, ask which one to apply.
- `guardrails(path="/abs/path/to/repo")` — list cost guardrails for the repo's resolved branch. Note the thresholds (`total_threshold` / `increase_threshold` / `increase_percent_threshold`) and the actions (`pr_comment` / `block_pr`). A `block_pr` action means the threshold is a hard constraint — the generated infrastructure must stay under it. Soft constraints (alert / PR comment only) become warnings to surface.
- `budgets()` — list every tag-scoped budget. If the resources you're about to create would match an existing budget's tag scope (`env=production`, `team=frontend`, etc.), note where that budget currently sits versus its `amount`. Budgets reflect **actual org-wide cloud billing**, not the preview — treat them as context for the user, not a hard constraint on the code.

Narrow the policies call when you know the provider: `policies(providers=["aws"])` skips downloading provider plugins for clouds you're not touching.

### 2. Iterate quickly with `price`

While drafting resources, call `price` with a small Terraform snippet to get a cost on what you've written so far. This is faster than writing the whole file and scanning — useful for choosing between two configurations:

```
price(iac="""
provider "aws" { region = "us-east-1" }

resource "aws_instance" "web" {
  instance_type = "m5.xlarge"
  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }
}
""")
```

The result includes per-resource cost components and any applicable FinOps recommendations (e.g. "use Graviton for ~20% savings"). Use it to make informed sizing / region / type calls as you go.

For non-USD pricing pass `currency="EUR"` (or any ISO 4217 code).

### 3. Scan the full result

Once the IaC files are complete, scan the directory:

```
scan(path="/abs/path/to/written/iac")
```

Read the `summary` block first. Most of what you need is there:

- `monthly_cost` — total cost of what you generated.
- `total_monthly_savings` — sum of potential savings if every FinOps issue were fixed.
- `failing_policies`, `failing_tagging_policies` — counts; if non-zero, drill in.
- `triggered_guardrails`, `over_budget` — counts; **if any guardrail with `block_pr` triggered, the generated code must be changed**.
- `critical_diagnostics`, `warning_diagnostics` — non-zero means the scanner couldn't fully analyze something; surface via `inspect_diagnostics`.

### 4. Drill in where needed

When the summary flags an issue, the `inspect_*` tools surface the detail. Each reads the latest cached scan automatically; pass `path` to target a specific previously-scanned directory.

| Question | Tool |
|---|---|
| Everything failing right now (policies + guardrails + budgets in one view) | `inspect_failing` |
| Top N savings opportunities | `inspect_top_savings` (default `n=10`) |
| Resources missing / with-invalid a specific tag | `inspect_resources` with `missing_tag` or `invalid_tag` |
| Resources by cost band | `inspect_resources` with `min_cost` / `max_cost` |
| Group resources by type / provider / file | `inspect_resources` with `group_by=["type"]` (etc.) |
| Per-project parse / lint diagnostics | `inspect_diagnostics` (defaults to all severities; `critical_only=true` to filter) |
| Which resources fail a specific policy | `inspect_policy_detail(policy="Use GP3")` |
| Per-resource detail under a policy | `inspect_policy_detail(policy="Use GP3", resource="aws_ebs_volume.data")` |
| Detail for one budget (matching resources + savings) | `inspect_budget_detail(budget="Production budget")` |
| Triggered state + monthly cost for one guardrail | `inspect_guardrail_detail(guardrail="Cost increase > $100")` |

### 5. Iterate until clean

Adjust the IaC based on what the drill-ins surface. Re-scan to confirm:

- All `block_pr` guardrails are under threshold.
- Mandatory tags are present on every resource.
- Cost is reasonable — the user gets the value they expected for the spend.

When you make a non-obvious sizing / tagging decision based on an Infracost finding, add a brief comment to the IaC explaining the choice (e.g. _"using Graviton — ~20% cheaper than equivalent x86"_, _"team tag required by org tagging policy"_). Be terse. Avoid mentioning Infracost unless absolutely necessary — comments rot less when they reference the constraint, not the tool that surfaced it.

## Important Guidelines

- Do not commit the authentication token or any env var values to the repository.
- Do not write `jq` pipelines, `python3 -c` heredocs, or shell post-processing — the MCP tools return structured data already. If the data you need isn't on one of the typed shapes, that's a signal we should add it; file an issue describing the gap.
- Do not stash or affect the target repository's git state — the MCP tools are non-destructive and read-only. If you need to compare branches, use separate worktrees away from the user's working directory.
- Pre-flight (steps 1–2 above) is non-negotiable for any code that creates cloud resources. Even when the user hasn't asked about cost, the org's policy + guardrail context shapes what "good" looks like.
- Budgets aren't hard constraints. Surface where they sit, but don't refuse to write code because a budget is full — that's the user's call to make.