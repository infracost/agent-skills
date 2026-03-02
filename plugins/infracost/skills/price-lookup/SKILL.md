---
description: Look up cloud resource pricing by generating sample Terraform and running Infracost against it. Use this skill when the user asks "how much does X cost?" or wants to compare pricing between resource configurations, instance types, regions, or cloud providers. This does not require the user to have any existing infrastructure code.
allowed-tools: Bash(infracost-poc*)
---

# Price Lookup

Look up cloud resource pricing without needing existing infrastructure code. Supports any resource type that Terraform and Infracost support across AWS, GCP, and Azure.

## Setup

**Important**: Ensure that `infracost-poc` is available on the path and if it is not, direct the user to install from github.com/infracost/cli-poc. Do not attempt to install or modify the CLI yourself.

```bash
infracost-poc login
```

## Workflow

### 1. Run Infracost

Pipe the Terraform configuration directly into `infracost-poc price`. This command reads Terraform from stdin, analyzes it, and prints the cost estimate as JSON to stdout. Temporary files are created and cleaned up automatically.

```bash
infracost-poc price << 'EOF'
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
EOF
```

Rules for writing the Terraform:

- **Minimal config only** — no backends, no variable files, no outputs, no data sources. Just a provider block and the resource(s).
- **Include attributes that affect pricing** — instance type, storage size/type, engine version, throughput, IOPS, etc. These are the knobs that change the price, so they must be present.
- **Use the user's requested configuration** — if they ask for "m5.xlarge with 100GB gp3", write exactly that. If they ask generically ("how much does an RDS instance cost?"), pick reasonable defaults and clearly state what you chose.
- **Set the region** — use the region the user asks for, or default to `us-east-1` and mention it.
- **Multiple resources are fine** — if the user asks about several resource types, put them all in the same file.
- **Use realistic names** — name resources descriptively (e.g., `aws_instance.web_server` not `aws_instance.example`) so the output is easier to read.

**Currency**: If the user requests pricing in a non-USD currency, set the `INFRACOST_CLI_CURRENCY` environment variable when running the command. For example:

```bash
INFRACOST_CLI_CURRENCY=EUR infracost-poc price << 'EOF'
...
EOF
```

Use standard [ISO 4217](https://en.wikipedia.org/wiki/ISO_4217) currency codes (e.g., `EUR`, `GBP`, `JPY`, `CAD`, `AUD`). If the user doesn't specify a currency, default to USD.

### 2. Inspect the results

Use the `inspect` command to read the results rather than parsing JSON manually.

```bash
# Summary overview
infracost-poc inspect --summary

# Detailed cost breakdown
infracost-poc inspect --costs-only

# Top expensive resources
infracost-poc inspect --top 5
```

## Presenting Results

Present pricing in a clear, structured way:

- **Lead with the monthly cost** — this is what the user cares about most
- **Break down cost components** — show what makes up the total (compute, storage, data transfer, etc.)
- **Call out usage-based costs** — note that some costs depend on actual usage (requests, data transferred, etc.) and the estimates use typical defaults. Be explicit about what assumptions were made.
- **Compare when asked** — if the user wants to compare configurations (e.g., m5.xlarge vs m5.2xlarge), create both resources and present a side-by-side table
- **Include FinOps recommendations** — if Infracost flags any policies (e.g., "use GP3 instead of GP2", "consider Graviton"), highlight those with potential savings
- **Mention the region** — pricing varies by region, so always state which region was used

### Example presentation

> **AWS RDS MySQL — db.r5.xlarge, 100GB gp3**
> Region: us-east-1
>
> | Component | Monthly Cost |
> |-----------|-------------|
> | Instance (on-demand) | $365.00 |
> | Storage (100GB gp3) | $11.50 |
> | **Total** | **$376.50** |
>
> Usage-based costs (estimated):
> - I/O requests: ~$X/mo based on typical usage
>
> Savings opportunity: Consider Graviton (db.r6g.xlarge) for ~20% savings (~$73/mo).

## Important Guidelines

- Do not commit any generated Terraform files — they are throwaway.
- Do not modify the CLI source code — this skill is for *using* the CLI.
- If `infracost-poc scan` prompts for login, ask the user to run `infracost-poc login` first.
- If the user asks about a resource type you're unsure of the Terraform resource name for, look it up rather than guessing — an incorrect resource type will produce no pricing data.
