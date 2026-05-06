---
name: infracost-scan
description: Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations. This skill should be used when asking about the cost of a cloud project, how to optimize costs, or when there are specific questions about FinOps policies or tagging compliance in an IaC codebase. The skill uses the Infracost CLI and its plugins to perform the analysis, so it requires the user to have those set up and authenticated. The output is a detailed cost report that highlights key insights and recommendations for cost optimization.
---

# Infracost Cost Estimation

Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations.

Supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.

## Setup

**Important**: Verify the Infracost CLI is installed and the user is authenticated before running any scans.

1. Check the CLI is on the path:

   ```bash
   infracost --version
   ```

   If this fails, inform the user that they need to install the Infracost CLI by following the instructions at https://www.infracost.io/docs/features/get_started/.

2. Check the user is logged in:

   ```bash
   infracost auth whoami
   ```

   If this reports that the user is not authenticated, ask them to run `infracost auth login` in a separate terminal window and let you know once it completes. Do not attempt to run the login command yourself — it is interactive.

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

For a compact, token-efficient text format suitable for piping into LLM prompts or other agentic tooling, pass `--llm` instead of `--json`. It carries the same data model in roughly 30–40% fewer tokens, with arrays of uniform records rendered as tabular rows so they grep cleanly.

Both `--json` and `--llm` outputs include a top-level `summary` block with pre-computed totals (`total_monthly_cost`, `total_potential_monthly_savings`, distinct failing-resource counts per policy class, per-class policy counts, guardrails triggered, budgets over). Read the `summary` first — most "how many X are failing?" or "what's the total Y?" questions can be answered from it without walking `projects[]` yourself.

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

**Views**

- `--summary` — high-level overview of projects, costs, policy counts, guardrails, and budgets (default when no flags given). Combine with `--fields` to project specific scalars (e.g. `--summary --fields failing_policies` emits the bare integer).
- `--failing` — only show policies that have failing resources (finops and tagging)
- `--group-by <key>[,<key>]` — group results by one or more dimensions. Comma-separated or repeated. See valid dimensions and combinations below.
- `--policy <name>` — drill into a specific FinOps or tagging policy to see its failing resources, file locations, and issue counts
- `--policy <name> --resource <address>` — full detail for one resource under a policy: issue descriptions, savings, attributes, file location with a code snippet
- `--budget <name>` — drill into a specific budget to see its scope (tag filters), amount, current cost, and how much is remaining or over
- `--guardrail <name>` — drill into a specific guardrail to see its status (triggered or not) and total monthly cost

**Aggregations**

- `--total-savings` — scalar sum of `monthly_savings` across every FinOps issue
- `--top-savings N` — top N FinOps issues sorted by `monthly_savings` desc

**Resource selection**

- `--top N` — top N most expensive resources
- `--project <name>` — filter to a specific project
- `--provider <name>` — `aws`, `google`, `azurerm`
- `--costs-only` — hide free resources
- `--missing-tag <key>` — resources missing the given tag entirely
- `--invalid-tag <key>` — resources where the given tag's value is outside the policy's allowed list
- `--min-cost N` / `--max-cost N` — resources with monthly cost ≥ / ≤ N
- `--filter "<expr>"` — comma-separated AND'd predicates. Supported keys: `policy=`, `project=`, `provider=`, `tag.<key>=missing`. Example: `--filter "tag.team=missing,provider=aws"`. If a predicate is rejected as too complex, file an issue describing the pattern — that's the signal we use to decide which flag to add next.

**Output projection** (replaces piping through `cut` / `awk '{print $N}'`)

- `--fields a,b,c` — per-view canonical column projection in the requested order. One field → bare value per line; multiple fields → TSV with a header row. Unknown field names error with the available set listed.
- `--addresses-only` — alias for `--fields=address`

Available fields per view (use with `--fields`):

- `--summary`: `projects`, `projects_with_errors`, `resources`, `costed_resources`, `free_resources`, `monthly_cost`, `finops_policies`, `failing_policies` (failing FinOps), `distinct_failing_finops_resources` (count of unique addresses that fail any FinOps policy), `tagging_policies`, `failing_tagging_policies`, `distinct_failing_tagging_resources` (count of unique addresses that fail any tagging policy), `guardrails`, `triggered_guardrails`, `budgets`, `over_budget`, `critical_diagnostics`, `warning_diagnostics`.
- `--top-savings`: `address`, `policy`, `policy_slug`, `project`, `monthly_savings`, `description`.
- `--missing-tag` / `--invalid-tag` / `--min-cost` / `--max-cost`: `address`, `type`, `project`, `monthly_cost`, `is_free`.

For "how many distinct resources fail X policy" questions, prefer `--summary --fields distinct_failing_finops_resources` / `distinct_failing_tagging_resources` over enumerating the failing-resource list and piping through `sort -u | wc -l` or awk. The summary already de-dupes addresses across multiple policies.

**Format**

- `--json` (global) — emit results as JSON instead of a table
- `--llm` (global) — emit results in a compact, token-efficient indentation-based text format (about 30–40% fewer tokens than `--json` for the same data; preferred for LLM pipelines)

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
- `policy` _can_ combine with resource-context dims (e.g. `--group-by policy,type`).

The same mutual-exclusion rule applies to the drill-in flags: `--policy`, `--budget`, and `--guardrail` cannot be used together — pick one.

### Use native flags before reaching for jq / python / cut

Many common queries that look like they need `--json | jq` or a `python3 -c` heredoc have dedicated `inspect` flags. Reach for these first:

| Question                                  | Use this                                                                  | Not this                                                            |
| ----------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Total monthly cost?                       | `infracost inspect --summary --fields monthly_cost`                       | `infracost scan --json \| jq '.summary.total_monthly_cost'`         |
| How many failing FinOps policies?         | `infracost inspect --summary --fields failing_policies`                   | `infracost inspect --failing --group-by policy \| sort -u \| wc -l` |
| How many resources fail FinOps policies?  | `infracost inspect --summary --fields distinct_failing_finops_resources`  | `... --policy "X" --addresses-only \| sort -u \| wc -l` per policy  |
| How many resources fail tagging policies? | `infracost inspect --summary --fields distinct_failing_tagging_resources` | `... --policy "X" --addresses-only \| sort -u \| wc -l` per policy  |
| Total potential savings?                  | `infracost inspect --total-savings`                                       | `jq '[..monthly_savings] \| add'`                                   |
| Top N savings opportunities?              | `infracost inspect --top-savings N`                                       | `jq 'sort_by(.savings)' \| head`                                    |
| Resources missing the `team` tag?         | `infracost inspect --missing-tag team`                                    | `jq 'select(.tags.team == null)'`                                   |
| Just the addresses for a view?            | `infracost inspect --policy "X" --addresses-only`                         | `... \| awk '{print $1}'`                                           |
| Custom column projection?                 | `infracost inspect --top-savings 10 --fields address,monthly_savings`     | `... \| awk '{print $1, $5}'`or`cut -f1,5`                          |

These flags exist because they capture intent in a structured way the CLI logs as telemetry — when you reach for a flag instead of an ad-hoc pipeline, we can see which patterns are common and decide what to support natively next.

#### Worked examples

```bash
# Setup: populate the cache.
infracost scan /path/to/repo

# Counts and totals (single --summary call answers most "how many" questions):
infracost inspect --summary                                                   # full summary block
infracost inspect --summary --fields failing_policies                         # just the count, bare value
infracost inspect --summary --fields failing_policies,failing_tagging_policies,resources
infracost inspect --summary --fields distinct_failing_tagging_resources       # distinct resources failing tagging
infracost inspect --summary --fields distinct_failing_finops_resources        # distinct resources failing finops
infracost inspect --total-savings                                             # one number

# "List the top N highest-savings opportunities" (no jq, no awk):
infracost inspect --top-savings 5 --fields address,monthly_savings

# "Which resources fail the tagging policy?":
infracost inspect --missing-tag team                        # default: one address per line
infracost inspect --missing-tag team --fields address,type  # with type column

# "All resources failing a specific policy" (preserves full list, no truncation):
infracost inspect --policy "Required Tags" --addresses-only

# Composable filter (multiple predicates, AND'd):
infracost inspect --filter "tag.team=missing,provider=aws" --fields address,monthly_cost
```

#### Anti-patterns

Do not:

- Write `jq` pipelines or `python3 -c` heredocs over the raw scan output for any of the patterns above. The dedicated flags exist for them.
- Pipe through `cut -f` or `awk '{print $N}'` — use `--fields` to project columns directly.
- Run `infracost scan --json` and parse the result yourself for aggregates that `--summary` already computes.

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
> _Note: Actual spend is based on cloud billing data across the organization. Savings estimates are from the IaC scan and may not directly translate to budget reductions._

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
- Do not write `jq` pipelines, `python3 -c` heredocs, or shell post-processing chains (`cut`, `awk '{print $N}'`, `sort -u`) over the raw scan output for queries that have a dedicated flag (see "Use native flags before reaching for jq / python / cut" above). When the model writes a pipeline instead of using a flag, we have no signal in telemetry that this is a pattern worth supporting natively.
