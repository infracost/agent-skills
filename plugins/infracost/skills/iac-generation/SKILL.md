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

**Important**: Ensure that `infracost-preview` is available on the path. If it is not, offer to install it for the user by triggering the `/infracost:install` skill (it may also be named `infracost-install`).

The user must be logged in - if not and you receive auth errors, prompt them to use the following:

```bash
infracost-preview login
```

## Usage

There are several tools available to you for this job.

Three commands are relevant for this skill:

1. `policies` - list all policies for the user's organization, so we can ensure we produce code that is compliant with them
2. `scan` - analyze IaC files and output JSON with costs, diagnostics, and policy violations
3. `price` - takes a (typically smaller) standalone piece of Terraform and estimates the cost of it, which is useful for quicker feedback for faster iteration on individual (or small groups of) resources

More information on each is available below.

When writing IaC code, you should do the following:

- Before starting, run the `policies` command to understand the organization's policies and ensure your code will be compliant from the start. You should ask the user for clarification for which tag values to use if the policy allows a list of acceptable values (or no specific value), or for any other parameters that are needed to ensure compliance. For example, if there is a tagging policy that requires all resources to have a `cost_center` tag with an accepted value of either `engineering` or `marketing`, ask the user which cost center to use for the resources they are creating.
- As you write code, use the `price` command to get quick feedback on the cost implications of the resources you are defining. This will help you make informed decisions about resource types and configurations as you go, rather than waiting until the end to analyze everything.
- Once you have a complete set of IaC files, run the `scan` command to get a comprehensive analysis of costs, savings opportunities, and any policy violations. Use the `inspect` command to explore the results and identify any areas that need optimization or changes to comply with policies before deploying the code.

### Policies Command

The `policies` command lists all tagging and FinOps policies that are configured for the user's organization. This is important to understand before writing any code, so you can ensure your code is compliant with the policies from the start.

```bash
infracost-preview policies
```

The output includes the policy name, type (tagging or FinOps), description, and any parameters. Use this information to guide your code writing and ensure you are following the organization's guidelines. For example, if there is a tagging policy that requires all resources to have a `cost_center` tag, make sure to include that in your resource definitions.

### Scan Command

Run the `scan` command, pointing to your IaC files or a repository root:

```bash
# Single CloudFormation template
infracost-preview scan /path/to/cloudformation.yaml

# Terraform project directory
infracost-preview scan /path/to/terraform/

# Repository root (auto-discovers all IaC projects in nested directories)
infracost-preview scan /path/to/repo
```

#### Output

JSON is written to stdout. Diagnostics and warnings are written to stderr.

The output can be very large for repos with many resources, so always redirect output to a file:

```bash
infracost-preview scan /path/to/repo > /tmp/whatever
```

#### Inspecting Results

After analyzing, use the `inspect` command to explore the results instead of parsing raw JSON. Always start with a summary, then drill into areas of interest using the available flags.

**Important**: The `inspect` command reads from JSON and you DO NOT NEED to write any scripts to handle the JSON output yourself. Just use the `inspect` command with the appropriate flags to view the data in an engaging, actionable way.

```bash
# Scan and save to file
infracost-preview scan /path/to/repo > /tmp/whatever

# Inspect the results (always pass --file to read from the saved JSON)
infracost-preview inspect [flags] --file /tmp/whatever
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

### Price Command

The price command reads Terraform code directly from stdin. For example:

```bash
echo 'resource "aws_instance" "x" { instance_type= "t2.micro" }' | infracost-preview price
```

The output is identical in format to the `scan` command, so the same `inspect` command can be used to explore the results.

## Important Guidelines

- Do not modify or rebuild the plugin binaries — they are managed in their own repositories.
- Do not commit the authentication token or any env var values to the repository.
- Pipe JSON output to a file — do not attempt to read it inline from the command.
- Do not stash or affect the target repository's git state when running the CLI — it should be non-destructive and read-only. Create separate directories or worktrees away from the user's working directory if you need to run multiple analyses or compare branches.
- When making decisions based on infracost output, add comments to the affected IaC resources/attributes that explain your decision if it's not obvious from the code itself. This will help reviewers understand the reasoning and make it easier for future maintainers to understand why certain choices were made. For example, if you choose a more expensive resource type for performance reasons, add a comment explaining that tradeoff. Or if you add specific tags to comply with a policy, comment on which policy requires those tags. Be terse, and avoid mentioning Infracost unless absolutely necessary.
