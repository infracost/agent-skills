---
name: iac-generation
description: >-
  Ensures cost optimization and FinOps/tagging policy compliance for infrastructure as code.
  BLOCKING REQUIREMENT - Invoke this skill BEFORE generating any IaC code, entering plan mode, or asking clarification questions.
  TRIGGER when: planning or writing code which creates cloud infrastructure resources (regardless of naming a specific tool to do so), imports IaC provider SDKs (pulumi-aws, hashicorp/aws, aws-cdk), or the task involves writing Pulumi, Terraform, CloudFormation, CDK, or Terragrunt.
  DO NOT TRIGGER when: general programming unrelated to infrastructure provisioning.
---

# Infracost IaC Generation Assistance

Assists when creating or modifying infrastructure as code (IaC) to ensure best practices are followed and costs are optimized from the start. Uses the Infracost CLI to analyze code as it's being written, providing real-time feedback on cost implications and optimization recommendations. The output includes actionable insights, such as suggesting more cost-effective resource types, identifying potential savings opportunities, and flagging any FinOps policy violations before the code is deployed. It also ensures guidelines supplied by the user's organization are being followed, such as tagging policies or required resource configurations, to catch problems early rather than during code review.

Directly supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.

Other IaC languages are also indirectly supported if you convert the resource definitions to Terraform (written to a temporary directory) and then scan that directory with the CLI.

## Setup

**Important**: Ensure that `infracost` is available on the path. If it is not, inform the user that they need to install the Infracost CLI by following the instructions at https://www.infracost.io/docs/features/get_started/.

The user must be logged in - if not and you receive auth errors, prompt them to use the following:

```bash
infracost login
```

## Usage

There are several tools available to you for this job.

Five commands are relevant for this skill:

1. `policies` - list all policies for the user's organization, so we can ensure we produce code that is compliant with them
2. `guardrails` - list cost guardrails (spending thresholds) configured for the repository, so we can ensure the infrastructure we generate stays within budget
3. `budgets` - list tag-scoped budgets for the organization, so we can see which tag groups are already near or over their actual cloud spend limits
4. `scan` - analyze IaC files and output JSON with costs, diagnostics, and policy violations
5. `price` - takes a (typically smaller) standalone piece of Terraform and estimates the cost of it, which is useful for quicker feedback for faster iteration on individual (or small groups of) resources

More information on each is available below.

When writing IaC code, you should do the following:

- Before starting, run the `policies` command to understand the organization's policies and ensure your code will be compliant from the start. You should ask the user for clarification for which tag values to use if the policy allows a list of acceptable values (or no specific value), or for any other parameters that are needed to ensure compliance. For example, if there is a tagging policy that requires all resources to have a `cost_center` tag with an accepted value of either `engineering` or `marketing`, ask the user which cost center to use for the resources they are creating.
- Before starting, also run the `guardrails` command to understand the cost thresholds configured for this repository. If there are guardrails with total monthly cost thresholds, you must ensure the infrastructure you generate stays within those limits. If a guardrail would block PRs, treat its threshold as a hard constraint. If it only creates alerts or PR comments, treat it as a soft constraint and warn the user if the estimated cost approaches the threshold.
- Before starting, also run the `budgets` command to see which tag scopes already have actual cloud spend tracked against them. If the resources you are about to create would match an existing budget's tags (e.g. `team=frontend`, `env=production`), note where that budget currently sits versus its limit. If a budget is already over or near its limit, surface this to the user before generating resources into that tag scope and ask whether they want to proceed, pick different tags, or resize the work. Unlike guardrails, budgets reflect actual org-wide cloud billing, not the preview scan — treat them as context for the user, not a hard constraint on the generated code.
- As you write code, use the `price` command to get quick feedback on the cost implications of the resources you are defining. This will help you make informed decisions about resource types and configurations as you go, rather than waiting until the end to analyze everything.
- Once you have a complete set of IaC files, run the `scan` command to get a comprehensive analysis of costs, savings opportunities, and any policy violations. Use the `inspect` command to explore the results and identify any areas that need optimization or changes to comply with policies before deploying the code. Pay attention to the guardrail results in the output — if any guardrails are triggered, you must adjust the code to bring costs within the configured thresholds before presenting the final result.

### Guardrails Command

The `guardrails` command lists cost guardrails configured for the repository. Guardrails define spending thresholds that, when exceeded, can trigger alerts, PR comments, or block PRs entirely.

```bash
infracost guardrails
```

The output shows each guardrail with its name, scope (repo or project-level), thresholds (total monthly cost, cost increase amount, cost increase percentage), and actions (PR comment, block PR, or alert only). Use this to understand the budget constraints before writing any infrastructure code.

### Policies Command

The `policies` command lists all tagging and FinOps policies that are configured for the user's organization. This is important to understand before writing any code, so you can ensure your code is compliant with the policies from the start.

```bash
infracost policies
```

The output includes the policy name, type (tagging or FinOps), description, and any parameters. Use this information to guide your code writing and ensure you are following the organization's guidelines. For example, if there is a tagging policy that requires all resources to have a `cost_center` tag, make sure to include that in your resource definitions.

### Budgets Command

The `budgets` command lists tag-scoped budgets configured for the user's organization. Each budget has a tag scope (e.g. `env=production`), a limit, a period, and the actual cloud spend recorded against that scope so far.

```bash
infracost budgets
```

**Important:** Budget spend reflects **actual cloud billing data** across the whole organization, not a preview of the current change. Use this as context for the user, not as a hard constraint on the code you generate.

The output shows each budget's name, limit, current spend, period, and tag scope. Before generating resources, check whether their tags match any budget's scope. If they do, mention where that budget stands — especially if it is already over or close to its limit — so the user can make an informed call on tags, sizing, or timing.

### Scan Command

Run the `scan` command, pointing to your IaC files or a repository root:

```bash
# Single CloudFormation template
infracost scan /path/to/cloudformation.yaml

# Terraform project directory
infracost scan /path/to/terraform/

# Repository root (auto-discovers all IaC projects in nested directories)
infracost scan /path/to/repo
```

#### Output

By default, `scan` prints a human-readable summary to stdout (projects, resources, monthly cost, FinOps and tagging policy counts, guardrails, budgets, diagnostics) followed by a "What's next?" section with suggested `inspect` commands. Diagnostics and warnings go to stderr. Pass the global `--json` flag for the full machine-readable JSON output:

```bash
# Human-readable summary (default)
infracost scan /path/to/repo

# Full JSON, redirected for large repos
infracost scan --json /path/to/repo > /tmp/scan.json
```

`--json` is global — it works on `scan`, `price`, and `inspect` and also switches log output to JSON.

#### Inspecting Results

Scan results are cached automatically, so `inspect` picks them up with no extra arguments. You don't need to redirect output or pass `--file` unless you specifically saved a JSON file with `--json`.

**Important**: The `inspect` command reads cached results and you DO NOT NEED to write any scripts to handle JSON yourself.

```bash
# Scan first (caches the result)
infracost scan /path/to/repo

# Drill in — no --file needed
infracost inspect [flags]

# Or, if you saved JSON yourself
infracost inspect --file /tmp/scan.json [flags]
```

Available flags (combine as needed):

- `--summary` — high-level overview of projects, costs, and policy counts (default when no flags given)
- `--failing` — only show policies that have failing resources (finops and tagging)
- `--group-by <key>[,<key>]` — group results by one or more dimensions. Comma-separated or repeated. See valid dimensions and combinations below.
- `--policy <name>` — drill into a specific policy to see its failing resources, file locations, and issue counts
- `--policy <name> --resource <address>` — full detail for one resource under a policy: issue descriptions, savings, attributes, file location with a code snippet
- `--budget <name>` — drill into a specific budget to see its scope, limit, actual spend, and status
- `--guardrail <name>` — drill into a specific guardrail to see its status and total monthly cost
- `--top N` — show only the top N most expensive resources
- `--project <name>` — filter to a specific project
- `--provider <name>` — filter by cloud provider (`aws`, `google`, `azurerm`)
- `--costs-only` — hide free resources
- `--json` (global) — emit the inspect result as JSON instead of a table

##### `--group-by` dimensions

Resource-context dims (aggregate the resource list): `type`, `provider`, `project`, `resource`, `file`. Use `resource` to list every resource sorted by cost (no `--top` limit needed).

Anchor dims (each routes to its own collector): `policy`, `guardrail`, `budget`.

Compatibility rules (validated up-front):
- `policy`, `guardrail`, and `budget` are pairwise mutually exclusive in a single `--group-by`.
- `guardrail` and `budget` cannot combine with resource-context dims — those rows have no resource context.
- `policy` *can* combine with resource-context dims (e.g. `--group-by policy,type`).

The same mutual-exclusion rule applies to the drill-in flags `--policy`, `--budget`, and `--guardrail` — pick one.

### Price Command

The price command reads Terraform code directly from stdin and prints a human-readable cost summary by default. For example:

```bash
echo 'resource "aws_instance" "x" { instance_type = "t2.micro" }' | infracost price
```

Pass `--json` for the same JSON shape as `scan`. Like `scan`, results are cached, so the same `inspect` command can be used to drill into the result without `--file`.

## Important Guidelines

- Do not modify or rebuild the plugin binaries — they are managed in their own repositories.
- Do not commit the authentication token or any env var values to the repository.
- When you do request `--json` output for a large repo, pipe it to a file — do not attempt to read it inline from the command. By default `scan` and `price` already print a small human-readable summary, so the file pipe is only needed when you specifically need the raw JSON.
- Do not stash or affect the target repository's git state when running the CLI — it should be non-destructive and read-only. Create separate directories or worktrees away from the user's working directory if you need to run multiple analyses or compare branches.
- When making decisions based on infracost output, add comments to the affected IaC resources/attributes that explain your decision if it's not obvious from the code itself. This will help reviewers understand the reasoning and make it easier for future maintainers to understand why certain choices were made. For example, if you choose a more expensive resource type for performance reasons, add a comment explaining that tradeoff. Or if you add specific tags to comply with a policy, comment on which policy requires those tags. Be terse, and avoid mentioning Infracost unless absolutely necessary.
