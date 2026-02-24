# Infracost Cost Estimation

Analyze infrastructure as code (IaC) projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations.

Supported IaC types: Terraform, CloudFormation, Terragrunt. CDK is not yet directly supported.


## Setup

Ensure the following env vars are set. If not, set them to these default values. If the default paths don't exist, ask the user where their plugin binaries are located.

```bash
export INFRACOST_CLI_PARSER_PLUGIN=~/src/parser/bin/infracost-parser-plugin
export INFRACOST_CLI_PROVIDER_PLUGIN_AWS=~/src/providers/bin/infracost-provider-plugin-aws
export INFRACOST_CLI_PROVIDER_PLUGIN_GOOGLE=~/src/providers/bin/infracost-provider-plugin-google
export INFRACOST_CLI_PROVIDER_PLUGIN_AZURERM=~/src/providers/bin/infracost-provider-plugin-azurerm
```

Build the CLI before first use:

```bash
make build
```

The user also needs to be authenticated by running the binary with the `login` command. If your run fails for authentication reasons, ask the user to run:

```bash
./bin/infracost login
```

## Usage

Run the `analyze` command, pointing to your IaC files or a repository root:

```bash
# Single CloudFormation template
./bin/infracost analyze /path/to/cloudformation.yaml

# Terraform project directory
./bin/infracost analyze /path/to/terraform/

# Repository root (auto-discovers all IaC projects in nested directories)
./bin/infracost analyze /path/to/repo
```


## Output

JSON is written to stdout. Diagnostics and warnings are written to stderr.

The output can be very large for repos with many resources, so always pipe it to a file:

```bash
./bin/infracost analyze /path/to/repo > /tmp/infracost-output.json
```

The JSON contains, for each discovered IaC project:
- A breakdown of resources and their estimated monthly costs
- Cost components with pricing, quantities, and environmental metrics (CO2, water)
- A list of failing FinOps policies with per-resource recommendations and potential savings

Use `jq` or a Python script to parse the JSON for analysis. For large or multi-project repos, scripted analysis is strongly recommended.

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
./bin/infracost analyze /path/to/repo > /tmp/infracost-current.json
./bin/infracost analyze /tmp/infracost-baseline/path/to/repo > /tmp/infracost-baseline.json

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
