---
name: infracost-scan
description: Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations. This skill should be used when asking about the cost of a cloud project, how to optimize costs, or when there are specific questions about FinOps policies or tagging compliance in an IaC codebase. The skill uses Infracost (via its MCP server when available, otherwise the Infracost CLI) to perform the analysis. The output is a detailed cost report that highlights key insights and recommendations for cost optimization.
---

# Infracost Cost Estimation

Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations.

Supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.

## Invoking capabilities

This skill is written in terms of **capabilities** (e.g. "scan a path", "get the summary", "drill
into a failing policy"). Each capability has two bindings — a typed MCP tool call and an
`infracost …` CLI command — listed in [BINDINGS.md](../../BINDINGS.md).

**Rule: if the Infracost MCP server is available, use its tools; otherwise run the equivalent CLI
command from BINDINGS.md.** The Claude Code plugin starts the MCP server automatically, so on Claude
Code/Cursor you use the tools. On agents that run shell commands (GitLab Duo, Gemini CLI) you use the
CLI binding. Either way, the workflow below is identical.

**Before any analysis**, satisfy the three preflight capabilities (see BINDINGS.md): the CLI is
present, the user is authenticated, and an organization is selected. With MCP these are resolved on
the first tool call (failures come back as readable errors, not a dropped connection); with the CLI,
check them inline. Never run `infracost auth login` — it is interactive.

## Workflow

### 1. Run a scan

Use the **scan** capability with the absolute path to the IaC directory.

It returns a `currency` field and a `summary` block — the same headline numbers the CLI's "Scan
Summary" box prints to a human: project count, resource counts (total / costed / free), monthly
cost, per-policy and per-domain failing counts, diagnostic counts, and a per-project breakdown.

A scan does not return per-resource detail. That's intentional — drill in via the **inspect**
capabilities when you need it (see step 3).

The scan result is cached under the scanned path. Subsequent inspect operations read the most recent
scan by default; target a specific previously-scanned directory by passing its path.

Optional: a `currency` (ISO 4217 code — `USD`, `EUR`, `GBP`, …). Defaults to the org-configured currency.

### 2. Triage with the summary

The `summary` block answers most "how many X?" and "what's the total Y?" questions without further calls:

- `monthly_cost`, `total_monthly_savings`
- `resources`, `costed_resources`, `free_resources`
- `finops_policies`, `failing_policies`, `distinct_failing_finops_resources`
- `tagging_policies`, `failing_tagging_policies`, `distinct_failing_tagging_resources`
- `guardrails`, `triggered_guardrails`
- `budgets`, `over_budget`
- `critical_diagnostics`, `warning_diagnostics`
- `project_details[]` — one row per project with name, path, monthly cost, per-policy counts, and a `has_errors` flag

When you need more than the headline, reach for one of the inspect capabilities.

### 3. Drill in

The cached scan is read by every inspect capability. Each can target a specific scan by path; omit
it to use the latest. Filter inputs (`project`, `provider`, `filter`, `costs_only`) compose across
the views.

| Question | Capability | Notable inputs |
|---|---|---|
| Everything that's currently failing (failing policies + triggered guardrails + over-budget items) | *everything currently failing* | `project`, `provider`, `filter` |
| Top N savings opportunities sorted by monthly_savings | *top N savings* | `n` (default 10), filter inputs |
| List resources matching predicates (missing tag, invalid tag, cost band) | *list resources by predicate* | `missing_tag`, `invalid_tag`, `min_cost`, `max_cost`, `resource`, filter inputs |
| Group / aggregate resources by dimension | *aggregate resources by dimension* | `group_by` (e.g. `type`, `policy,type`, `budget`), `top` |
| Per-project diagnostic messages (parse errors, missing vars, …) | *per-project diagnostics* | `project`, `critical_only` |
| Failing-resource detail for one FinOps or tagging policy | *policy detail* | `policy` (name or slug), `resource` (narrows to one address) |
| Per-resource detail for a specific budget — matching resources + savings | *budget detail* | `budget` (name or id) |
| Status + monthly cost for one guardrail | *guardrail detail* | `guardrail` (name or id) |

Listing resources switches modes on `group_by`:

- **Flat mode** (no `group_by`): one row per resource matching the predicate filters. Resource-shaped predicates (`missing_tag`, `invalid_tag`, `min_cost`, `max_cost`) only apply here.
- **Grouped mode** (`group_by` set): one row per aggregation key. Valid dimensions: `type`, `provider`, `project`, `file`, `resource`, `policy`, `budget`, `guardrail`. `top` only applies here.

Compatibility rules (validated up front):

- `policy`, `guardrail`, and `budget` are pairwise mutually exclusive in a single grouping.
- `guardrail` and `budget` can't combine with resource-context dims (`type`, `provider`, `project`, `resource`, `file`) — those rows have no resource context.
- `policy` _can_ combine with resource-context dims (e.g. `group_by=policy,type`).

### 4. Drill-down workflow

Always start with the summary, then offer to drill deeper. The natural progression:

#### Policies

1. **Start broad** — scan → read `summary` and `summary.project_details`. If `failing_policies` > 0, list which policies are failing.
2. **Pick a policy** — *policy detail* for that policy (e.g. policy = "Use GP3") to list its failing resources, with file:line locations.
3. **Pick a resource** — *policy detail* with both the policy and a resource address (e.g. policy = "Use GP3", resource = "aws_ebs_volume.data") to see the full issue detail with metadata.

When presenting results, always offer the user a list of policies or resources they can drill into next:

> You have 3 failing FinOps policies. Would you like to drill into one?
>
> 1. **Use GP3** — 2 failing resources
> 2. **Use Graviton** — 5 failing resources
> 3. **Required Tags** — 12 failing resources

**Important**: When the user asks about a specific resource (e.g., "what's wrong with the RDS instance?"), drill down to the resource level with *policy detail* (policy + resource) and explain what needs to change. Don't just describe the issue — point at the specific attribute and the metadata's `file` / `start_line` so the user knows where to look.

#### Guardrails

When the summary shows triggered guardrails (e.g., `triggered_guardrails: 1`), drill in:

1. **List all configured guardrails** — use the *list guardrails* capability. Each entry includes its thresholds and actions (configured state, not post-scan).
2. **Get triggered state for the latest scan** — *guardrail detail* (e.g. guardrail = "Cost increase > $100") returns the matching guardrail from the scan results: `triggered` flag + `total_monthly_cost` rolled up by the scan.

Present triggered guardrails prominently — they may block the PR:

> 1 guardrail triggered. The total monthly cost of $500 exceeded the "Cost increase > $100" threshold.
> Would you like to see the detail?

#### Budgets

**Important context:** Budget costs represent **actual org-wide cloud spend** from cloud billing data — they are NOT computed from the IaC scan and are NOT affected by the changes in the current PR. Budgets are shown because the PR touches resources with matching tags, but the dollar amounts reflect what the org has already spent across all repos and resources with those tags. Do not describe budget costs as "estimated" or imply the PR caused them.

When the summary shows budgets over limit (e.g., `over_budget: 1`), drill in:

1. **List all configured budgets** — use the *list budgets* capability to see every budget's amount, current spend, period, and tag scope.
2. **Get post-scan detail for one budget** — *budget detail* (e.g. budget = "Production budget") returns the budget plus the resources in the current scan whose tags match its scope, grouped by type with monthly cost, and any FinOps savings available on those resources.

The budget detail view surfaces three things:

- **Limit and actual spend** — the org-wide cloud billing spend against the budget.
- **Resources in this scan matching budget tags** — which resources in the current scan are tagged with the budget's scope.
- **FinOps policy violations on matching resources** — any policy violations on resources with the budget's tags, with estimated per-policy savings.

**Important:** The savings shown are estimates from the IaC scan. They may not directly reduce the org-wide budget spend — for example, if the resources are newly created and haven't been deployed yet, or if the savings depend on usage changes. Present savings as "areas to investigate" rather than guaranteed reductions.

Present over-budget items clearly with the dollar amount over:

> 1 of 3 budgets is relevant to this change (matched by resource tags):
>
> | Budget            | Status   | Actual Spend | Limit                 |
> | ----------------- | -------- | ------------ | --------------------- |
> | Production budget | under    | $500         | $1,000 (50% left)     |
> | Frontend Q2       | **OVER** | $400         | $300                  |
> | Backend annual    | under    | $200         | $5,000 (96% left)     |
>
> **Frontend Q2** is $100 over its org-wide budget. Let me drill in for detail…
>
> (drills in with *budget detail* for "Frontend Q2")
>
> The budget detail shows 3 resources matching `team=frontend` tags in this scan. There are also FinOps policy violations on some of these resources (Use GP3: up to $30/mo, Use Graviton: up to $45/mo) — addressing these could help reduce spend over time.
>
> _Note: Actual spend is based on cloud billing data across the organization. Savings estimates are from the IaC scan and may not directly translate to budget reductions._

When a budget is over, always use *budget detail* to check for related FinOps violations — they highlight areas where spend on matching resources could potentially be reduced.

### Presenting scan results

Make the output engaging with tables and clear callouts. Tailor depth to complexity — a 3-resource repo gets a concise summary, a 500-resource repo gets a structured breakdown.

- **Lead with the biggest cost drivers.** Break costs down by environment, module, project, service, resource type, or individual resource depending on what the data shows.
- **Highlight expensive resources or large savings opportunities.** If EC2 instances could switch to Graviton for 20% off, call that out with the dollar amount.
- **FinOps violations get concrete dollar amounts and recommendations.** If the fix is a simple config change or version upgrade, call it out as low-hanging fruit and sketch the change.
- **Tagging violations get the resource count and any patterns.** If all the untagged resources are in one module, that's the lead — suggests a gap in the tagging strategy.
- **Triggered guardrails are prominent.** Distinguish hard constraints (block PR) from soft (alert / PR comment). Show the configured threshold next to the actual cost so the gap is visible. Always offer to drill in with *guardrail detail*.
- **Over-budget items are also prominent**, with the amount over and any custom overrun messages. Even for budgets that are under, show how much headroom remains. Always offer to drill in with *budget detail*. Frame as "your organization has spent $X against this budget", not "this change costs $X".
- **Environmental impact metrics** (CO2, water) when available — they add real value alongside the cost numbers.
- **Usage-based costs come with a caveat.** We don't have actual usage data; the estimates use typical defaults. Call out the uncertainty for those resources and recommend reviewing actual usage post-deploy.
- **Make it actionable.** Don't just say "FinOps policy Z has 3 violations" — say "You could save $X per month by doing Y. The 3 affected resources are…" Concrete dollar amounts (monthly and annualized) and concrete code changes.
- **Don't mention informational diagnostics** unless the user is debugging a scan.

## Diffing Against a Baseline

To compare cost changes between branches, run two scans against different working trees (use `git worktree` to create a parallel checkout) and compare the `summary` blocks each returns. The inspect capabilities can reference each scan separately by path — both stay cached for the lifetime of the session.

```
# Pseudo-flow:
scan the current branch at /abs/path/to/repo
scan the baseline checkout at /abs/path/to/repo-baseline-worktree
# Compare the two summary.monthly_cost / failing_policies / etc. values.
# Then for each side, optionally get the summary for each path.
```

Clean up any worktrees you created when you're done.

## Important Guidelines

- Do not commit the authentication token or any env var values to the repository.
- Do not modify the CLI source code unless the user explicitly asks for it — this skill is for _using_ Infracost, not developing it.
- Always clean up git worktrees created for diffing when done.
- Do not stash or affect the target repository's git state — scan operations are non-destructive and read-only. If you need to compare branches, use separate worktrees away from the user's working directory.
- Prefer the structured fields on the `summary` block over recomputing things from `summary.project_details[]`. The summary already de-dupes failing-resource counts across multiple policies.
- Auth and the active organization are resolved on the first tool call (MCP binding) or checked inline (CLI binding) — either way, failures surface as readable errors, not a dropped connection. On an **authentication error**, have the user run `infracost auth login` in a separate terminal (interactive — never run it yourself), then retry. On **"no organization selected"**, the error lists the available org slugs; ask which one to use and have the user run `infracost org switch <slug>` (add `--repo` to pin it to this repo), then retry — the running MCP server picks up the selection on its next call. If an operation reports "no scan results available", relay that too. Relay these actionable errors to the user — don't retry blindly.
