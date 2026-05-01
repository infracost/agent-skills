---
name: infracost-scan
description: Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations. This skill should be used when asking about the cost of a cloud project, how to optimize costs, or when there are specific questions about FinOps policies or tagging compliance in an IaC codebase. The skill uses the Infracost CLI and its plugins to perform the analysis, so it requires the user to have those set up and authenticated. The output is a detailed cost report that highlights key insights and recommendations for cost optimization.
---

# Infracost Cost Estimation

Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations.

Supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.

## Setup

**important**: Ensure that `infracost` is available on the path. If it is not, inform the user that they need to install the Infracost CLI by following the instructions at https://www.infracost.io/docs/features/get_started/.

```bash
infracost login
```

## Usage

Run the `scan` command, pointing to your IaC files or a repository root:

```bash
# Single CloudFormation template
infracost scan /path/to/cloudformation.yaml

# Terraform project directory
infracost scan /path/to/terraform/

# Repository root (auto-discovers all IaC projects in nested directories)
infracost scan /path/to/repo
```

## Output

By default, `scan` prints a human-readable summary table to stdout (projects, resources, monthly cost, FinOps and tagging policy counts, guardrails, budgets, diagnostics) followed by a "What's next?" section that suggests context-aware `inspect` commands you can run to dive deeper. Diagnostics and warnings go to stderr.

For the full machine-readable JSON output, pass the global `--json` flag:

```bash
# Human-readable summary (default)
infracost scan /path/to/repo

# Full JSON output (large; redirect to a file for big repos)
infracost scan --json /path/to/repo > /tmp/scan.json
```

`--json` is a global flag — it works on `scan`, `price`, and `inspect` and also switches log output to JSON.

## Inspecting Results

After analyzing, use the `inspect` command to explore the results instead of parsing raw JSON. Scan results are cached automatically, so `inspect` picks them up with no extra arguments — you do not need to redirect scan output or pass `--file` unless you saved a JSON file yourself.

**Important**: The `inspect` command reads cached results and you DO NOT NEED to write any scripts to handle JSON yourself. Just run `inspect` with the appropriate flags.

```bash
# Scan first (caches the result)
infracost scan /path/to/repo

# Then drill in — no --file needed
infracost inspect [flags]

# Or, if you saved JSON yourself with --json, point inspect at it
infracost inspect --file /tmp/scan.json [flags]
```

Available flags (combine as needed):
- `--summary` — high-level overview of projects, costs, policy counts, guardrails, and budgets (default when no flags given)
- `--failing` — only show policies that have failing resources (finops and tagging)
- `--group-by <key>[,<key>]` — group results by one or more dimensions. Comma-separated or repeated. See valid dimensions and combinations below.
- `--policy <name>` — drill into a specific FinOps or tagging policy to see its failing resources, file locations, and issue counts
- `--policy <name> --resource <address>` — full detail for one resource under a policy: issue descriptions, savings, attributes, file location with a code snippet
- `--budget <name>` — drill into a specific budget to see its scope (tag filters), amount, current cost, and how much is remaining or over
- `--guardrail <name>` — drill into a specific guardrail to see its status (triggered or not) and total monthly cost
- `--top N` — show only the top N most expensive resources
- `--project <name>` — filter to a specific project
- `--provider <name>` — filter by cloud provider (`aws`, `google`, `azurerm`)
- `--costs-only` — hide free resources
- `--json` (global) — emit the inspect result as JSON instead of a table

#### `--group-by` dimensions

Resource-context dimensions (aggregate the resource list):
- `type` — Terraform resource type (e.g. `aws_instance`)
- `provider` — `aws`, `google`, `azurerm`, or `other`
- `project` — scan project name
- `resource` — full resource address; one row per resource sorted by cost (use this to list every resource by cost with no `--top` limit)
- `file` — `path:line` of the resource definition

Anchor dimensions (each routes to its own collector):
- `policy` — one row per failing policy / resource pairing
- `guardrail` — one row per guardrail with status and monthly cost
- `budget` — one row per budget with status, limit, and actual spend

Compatibility rules (validated up-front):
- `policy`, `guardrail`, and `budget` are pairwise mutually exclusive in a single `--group-by`.
- `guardrail` and `budget` cannot combine with resource-context dims (`type`, `provider`, `project`, `resource`, `file`) — those rows have no resource context.
- `policy` *can* combine with resource-context dims (e.g. `--group-by policy,type`).

The same mutual-exclusion rule applies to the drill-in flags: `--policy`, `--budget`, and `--guardrail` cannot be used together — pick one.

### Drill-down workflow

Always start with a summary or high-level grouping, then offer to drill deeper. The inspect command supports a progressive drill-down:

#### Policies

1. **Start broad** — `--summary` or `--group-by=policy` to see what's failing
2. **Pick a policy** — `--policy "Use GP3"` to list the failing resources for that policy, with file locations
3. **Pick a resource** — `--policy "Use GP3" --resource "aws_ebs_volume.data"` to see full issue detail with a code snippet

When presenting results, always offer the user a list of policies or resources they can drill into next. For example:

> You have 3 failing FinOps policies. Would you like to drill into one?
>
> 1. **Use GP3** — 2 failing resources
> 2. **Use Graviton** — 5 failing resources
> 3. **Required Tags** — 12 failing resources

After showing a policy overview, offer to drill into specific resources:

> **Use GP3** has 2 failing resources. Want to see the detail for one?
>
> 1. `aws_ebs_volume.data` — modules/storage/main.tf:10
> 2. `aws_ebs_volume.logs` — modules/logging/main.tf:25

The resource detail view includes a code snippet showing the relevant lines from the source file — use this to explain what needs to change and suggest a fix.

**Important**: When the user asks about a specific resource (e.g., "show me the issue with the lambda", "what's wrong with the RDS instance?"), always drill down to the resource level using `--policy <name> --resource <address>` and include the code snippet in your response. Don't just describe the issue — show it with the snippet so the user can see exactly what needs to change.

#### Guardrails

When the summary shows triggered guardrails (e.g., `Guardrails: 2 (1 triggered)`), drill into them:

1. **List all** — `--group-by=guardrail` to see all guardrails with their status and monthly cost
2. **Pick one** — `--guardrail "Cost increase > $100"` to see detail: whether it triggered, the total monthly cost, and configured thresholds

Present triggered guardrails prominently — they may block the PR. For example:

> 1 guardrail triggered. The total monthly cost of $500 exceeded the "Cost increase > $100" threshold.
> Would you like to see the detail?

#### Budgets

**Important context:** Budget costs represent **actual org-wide cloud spend** from cloud billing data — they are NOT computed from the IaC scan and are NOT affected by the changes in the current PR. Budgets are shown on a PR because the PR touches resources with matching tags, but the dollar amounts reflect what the org has already spent across all repos and resources with those tags. Do not describe budget costs as "estimated" or imply the PR caused them.

When the summary shows budgets over limit (e.g., `Budgets: 3 (1 over)`), drill into them:

1. **List all** — `--group-by=budget` to see all budgets with their name, status, actual spend, and limit
2. **Pick one** — `--budget "Production budget"` to see full detail: tag scope, limit, actual spend, remaining/over, custom message, matching resources from the scan, and potential savings from FinOps policies on those resources

The budget detail view shows:
- **Limit and actual spend** — the org-wide cloud billing spend against the budget
- **Resources in this scan matching budget tags** — which resources in the current scan are tagged with the budget's scope, grouped by type with count and monthly cost
- **FinOps policy violations on matching resources** — any policy violations on resources with the budget's tags, with estimated per-policy savings

**Important:** The savings shown are estimates from the IaC scan. They may not directly reduce the org-wide budget spend — for example, if the resources are newly created and haven't been deployed yet, or if the savings depend on usage changes. Present savings as "areas to investigate" rather than guaranteed reductions.

Present over-budget items clearly with the dollar amount over. For example:

> 1 of 3 budgets is relevant to this change (matched by resource tags):
> | Budget | Status | Actual Spend | Limit |
> |--------|--------|---------|-------|
> | Production budget | under | $500 | $1,000 (50% left) |
> | Frontend Q2 | **OVER** | $400 | $300 |
> | Backend annual | under | $200 | $5,000 (96% left) |
>
> **Frontend Q2** is $100 over its org-wide budget. Let me drill in for detail...
>
> (runs `--budget "Frontend Q2"`)
>
> The budget detail shows 3 resources matching `team=frontend` tags in this scan. There are also FinOps policy violations on some of these resources (Use GP3: up to $30/mo, Use Graviton: up to $45/mo) — addressing these could help reduce spend over time.
>
> *Note: Actual spend is based on cloud billing data across the organization. Savings estimates are from the IaC scan and may not directly translate to budget reductions.*

When a budget is over, always drill in with `--budget <name>` to check for related FinOps violations — they highlight areas where spend on matching resources could potentially be reduced.

### Presenting scan results

Make the output engaging with emojis, tables, and graphs where appropriate.

Summarize the costs of the cloud resources, focusing on the following:

- Add clear headlines: depending on the project, break costs down by one or more of environment, module, project, service, resource type, or individual resource. The goal is to make it easy for the user to quickly understand the biggest cost drivers and where to focus their attention.
- Highlight any resources that are particularly expensive or have large savings opportunities. For example, if there are EC2 instances that could be switched to Graviton for a 20% cost saving, call that out clearly with the potential savings amount.
- If there are any FinOps policy violations, highlight those clearly with the potential savings and recommendations for how to fix them. If any violations could be fixed with a simple configuration change or version upgrade, call those out as low-hanging fruit and describe the code change briefly.
- If there are tagging policy violations, call those out with the number of untagged resources and any interesting patterns. For example, if all the untagged resources are in a specific module or environment, that could indicate a gap in the tagging strategy that should be addressed.
- If any cost guardrails are triggered, highlight them clearly. Distinguish between guardrails that block PRs (hard constraints requiring changes before merging) and those that only create alerts or PR comments (soft constraints). Show the configured threshold alongside the actual cost so the user can see how far over they are. Always offer to drill in with `--guardrail <name>`.
- If any budgets are over their limit, highlight them prominently with the amount over and any custom overrun messages. Even for budgets that are under, show how much headroom remains. Always offer to drill in with `--budget <name>`. Remember: budget costs are actual org-wide cloud spend, not IaC estimates — frame them as "your organization has spent $X against this budget" not "this change costs $X."
- If there are any resources with significant environmental impact, call those out with the relevant metrics and recommendations for reducing the impact.
- Note that usage costs may be less reliable, as we don't have _actual_ usage data for the resources, just estimated defaults based on typical usage patterns. If there are usage-based resources, call out the uncertainty around those estimates and recommend that the user review actual usage once the resources are deployed.
- Make sure to highlight what actions the user should take - the report should be _actionable_, not just informational. For example, if there are savings opportunities, clearly state "You could save $X per month by doing Y". If there are policy violations, clearly state "You have 3 resources that violate policy Z, which could be fixed by doing A, B, and C for a potential savings of $X per month".
- Don't mention informational diagnostics.

## Diffing Against a Baseline

To compare cost changes between branches, use `git worktree` and capture each scan's JSON output:

```bash
# Create a worktree for the baseline
git worktree add /tmp/infracost-baseline origin/main

# Run against both and capture full JSON for diffing
infracost scan --json /path/to/repo > /tmp/head.json
infracost scan --json /tmp/infracost-baseline/path/to/repo > /tmp/base.json

# Clean up
git worktree remove /tmp/infracost-baseline
```

Compare the two JSON files to identify cost differences introduced by the current branch.

## Presenting Results

Always present cost analysis in an engaging, actionable way tailored to what the data shows. Don't just dump raw numbers — tell a story with the data:

- **Use tables** for comparisons, resource lists, and cost breakdowns
- **Use bullet points** for recommendations and action items
- **Highlight the biggest cost drivers** — call out the top spenders and what % of total they represent
- **Include savings opportunities** with concrete dollar amounts (monthly and annualized)
- **Add context and tips** — e.g., explain _why_ Graviton is cheaper, what a lifecycle policy does, or why a version upgrade avoids extended support costs
- **Show environmental metrics** (CO2, water) when available — these add real value
- **For diffs**, clearly show before/after with the delta, and explain what the change means in plain language
- **Group by module or service** when there are many resources — don't list 400 resources flat
- **Tailor depth to complexity** — a 3-resource repo gets a concise summary, a 500-resource repo gets a structured breakdown with sections

## Important Guidelines

- Do not modify or rebuild the plugin binaries — they are managed in their own repositories.
- Do not commit the authentication token or any env var values to the repository.
- Do not modify the CLI source code unless the user explicitly asks for it — this skill is for _using_ the CLI, not developing it.
- Always clean up git worktrees created for diffing when done.
- When you do request `--json` output for a large repo, pipe it to a file — do not attempt to read it inline from the command. By default `scan` already prints a small human-readable summary, so the file pipe is only needed when you specifically need the raw JSON.
- Do not stash or affect the target repository's git state when running the CLI — it should be non-destructive and read-only. Create separate directories or worktrees away from the user's working directory if you need to run multiple analyses or compare branches.
