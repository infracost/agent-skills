---
description: Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations. This skill should be used when asking about the cost of a cloud project, how to optimize costs, or when there are specific questions about FinOps policies or tagging compliance in an IaC codebase. The skill uses the Infracost CLI and its plugins to perform the analysis, so it requires the user to have those set up and authenticated. The output is a detailed cost report that highlights key insights and recommendations for cost optimization.
---

# Infracost Cost Estimation

Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations.

Supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.


## Setup

**important**: Ensure that `infracost-preview` is available on the path. If it is not, offer to install it for the user by triggering the `/infracost:install` skill.


```bash
infracost-preview login
```

## Usage

Run the `scan` command, pointing to your IaC files or a repository root:

```bash
# Single CloudFormation template
infracost-preview scan /path/to/cloudformation.yaml

# Terraform project directory
infracost-preview scan /path/to/terraform/

# Repository root (auto-discovers all IaC projects in nested directories)
infracost-preview scan /path/to/repo
```


## Output

JSON is written to stdout. Diagnostics and warnings are written to stderr.

The output can be very large for repos with many resources, so always pipe it to a file:

```bash
infracost-preview scan /path/to/repo
```

## Inspecting Results

After analyzing, use the `inspect` command to explore the results instead of parsing raw JSON. Always start with a summary, then drill into areas of interest using the available flags.

**Important**: The `inspect` command reads from JSON and you DO NOT NEED to write any scripts to handle the JSON output yourself. Just use the `inspect` command with the appropriate flags to view the data in an engaging, actionable way.

```bash
# Scan and save to file
infracost-preview scan /path/to/repo

**Important**: The inspect command does not require the plugin paths to be specified, the command can be run without them

# Inspect the results (always pass --file to read from the saved JSON)
infracost-preview inspect [flags]
```

Available flags (combine as needed):
- `--summary` — high-level overview of projects, costs, and policy counts (default when no flags given)
- `--failing` — only show policies that have failing resources (finops and tagging)
- `--group-by <key>[,<key>]` — group results by one or more dimensions: `type`, `provider`, `project`, `policy`. Comma-separated or repeated. Single dimension aggregates with counts; multiple dimensions show individual rows with file locations.
- `--policy <name>` — drill into a specific policy to see its failing resources, file locations, and issue counts
- `--policy <name> --resource <address>` — full detail for one resource under a policy: issue descriptions, savings, attributes, file location with a code snippet
- `--top N` — show only the top N most expensive resources
- `--project <name>` — filter to a specific project
- `--provider <name>` — filter by cloud provider (`aws`, `google`, `azurerm`)
- `--costs-only` — hide free resources

### Drill-down workflow

Always start with a summary or high-level grouping, then offer to drill deeper. The inspect command supports a progressive drill-down:

1. **Start broad** — `--summary` or `--group-by=policy` to see what's failing
2. **Pick a policy** — `--policy "Use GP3"` to list the failing resources for that policy, with file locations
3. **Pick a resource** — `--policy "Use GP3" --resource "aws_ebs_volume.data"` to see full issue detail with a code snippet

When presenting results, always offer the user a list of policies or resources they can drill into next. For example:

> You have 3 failing FinOps policies. Would you like to drill into one?
> 1. **Use GP3** — 2 failing resources
> 2. **Use Graviton** — 5 failing resources
> 3. **Required Tags** — 12 failing resources

After showing a policy overview, offer to drill into specific resources:

> **Use GP3** has 2 failing resources. Want to see the detail for one?
> 1. `aws_ebs_volume.data` — modules/storage/main.tf:10
> 2. `aws_ebs_volume.logs` — modules/logging/main.tf:25

The resource detail view includes a code snippet showing the relevant lines from the source file — use this to explain what needs to change and suggest a fix.

**Important**: When the user asks about a specific resource (e.g., "show me the issue with the lambda", "what's wrong with the RDS instance?"), always drill down to the resource level using `--policy <name> --resource <address>` and include the code snippet in your response. Don't just describe the issue — show it with the snippet so the user can see exactly what needs to change.

Make the output engaging with emojis, tables, and graphs where appropriate.

Summarize the costs of the cloud resources, focusing on the following:
- Add clear headlines: depending on the project, break costs down by one or more of environment, module, project, service, resource type, or individual resource. The goal is to make it easy for the user to quickly understand the biggest cost drivers and where to focus their attention.
- Highlight any resources that are particularly expensive or have large savings opportunities. For example, if there are EC2 instances that could be switched to Graviton for a 20% cost saving, call that out clearly with the potential savings amount.
- If there are any FinOps policy violations, highlight those clearly with the potential savings and recommendations for how to fix them. If any violations could be fixed with a simple configuration change or version upgrade, call those out as low-hanging fruit and describe the code change briefly.
- If there are tagging policy violations, call those out with the number of untagged resources and any interesting patterns. For example, if all the untagged resources are in a specific module or environment, that could indicate a gap in the tagging strategy that should be addressed.
- If there are any resources with significant environmental impact, call those out with the relevant metrics and recommendations for reducing the impact.
- Note that usage costs may be less reliable, as we don't have _actual_ usage data for the resources, just estimated defaults based on typical usage patterns. If there are usage-based resources, call out the uncertainty around those estimates and recommend that the user review actual usage once the resources are deployed.
- Make sure to highlight what actions the user should take - the report should be _actionable_, not just informational. For example, if there are savings opportunities, clearly state "You could save $X per month by doing Y". If there are policy violations, clearly state "You have 3 resources that violate policy Z, which could be fixed by doing A, B, and C for a potential savings of $X per month".
- Don't mention informational diagnostics.

## Diffing Against a Baseline

To compare cost changes between branches, use `git worktree`:

```bash
# Create a worktree for the baseline
git worktree add /tmp/infracost-baseline origin/main

# Run against both and compare
infracost-preview scan /path/to/repo
infracost-preview scan /tmp/infracost-baseline/path/to/repo
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
- **Add context and tips** — e.g., explain *why* Graviton is cheaper, what a lifecycle policy does, or why a version upgrade avoids extended support costs
- **Show environmental metrics** (CO2, water) when available — these add real value
- **For diffs**, clearly show before/after with the delta, and explain what the change means in plain language
- **Group by module or service** when there are many resources — don't list 400 resources flat
- **Tailor depth to complexity** — a 3-resource repo gets a concise summary, a 500-resource repo gets a structured breakdown with sections


## Important Guidelines

- Do not modify or rebuild the plugin binaries — they are managed in their own repositories.
- Do not commit the authentication token or any env var values to the repository.
- Do not modify the CLI source code unless the user explicitly asks for it — this skill is for *using* the CLI, not developing it.
- Always clean up git worktrees created for diffing when done.
- Pipe JSON output to a file — do not attempt to read it inline from the command.
- Do not stash or affect the target repository's git state when running the CLI — it should be non-destructive and read-only. Create separate directories or worktrees away from the user's working directory if you need to run multiple analyses or compare branches.
