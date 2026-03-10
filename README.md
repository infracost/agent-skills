# Infracost AI Agent Skills

Cloud cost intelligence for AI coding agents.

[![License](https://img.shields.io/github/license/infracost/agent-skills)](LICENSE)
[![Alpha](https://img.shields.io/badge/status-alpha-orange)](https://github.com/infracost/agent-skills/issues)


https://github.com/user-attachments/assets/16eef8f1-5bc1-4e5f-b5c4-c7594d883057

> [!WARNING]
>
> These skills are in early alpha. Features may change and rough edges are expected.
> [Open a discussion thread](https://github.com/infracost/infracost/discussions) to report bugs or
> share feedback — it is genuinely appreciated.

A collection of AI coding agent skills for [Infracost](https://infracost.io) users. These
skills integrate Infracost workflows directly into your AI coding agent, providing cost
estimation, optimization recommendations, and FinOps policy compliance for infrastructure
as code.

## Available Skills

| Skill                                                                | Description                                                                                                     |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [iac-generation](./plugins/infracost/skills/iac-generation/SKILL.md) | Ensure cost optimization and FinOps/tagging policy compliance when writing infrastructure as code               |
| [scan](./plugins/infracost/skills/scan/SKILL.md)                     | Analyze IaC projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations |
| [price-lookup](./plugins/infracost/skills/price-lookup/SKILL.md)     | Look up cloud resource pricing by generating sample Terraform and running Infracost — no existing IaC required  |
| [install](./plugins/infracost/skills/install/SKILL.md)               | Install or update the Infracost CLI from GitHub releases                                                        |
| [uninstall](./plugins/infracost/skills/uninstall/SKILL.md)           | Uninstall the Infracost CLI                                                                                     |
| [install-lsp](./plugins/infracost/skills/install-lsp/SKILL.md)      | Install or update the Infracost Language Server                                                                  |

Works with **Terraform, Terragrunt, and CloudFormation**. Supports **AWS, GCP, and Azure**.

## Prerequisites

- A free **Infracost account** — [sign up at infracost.io](https://dashboard.infracost.io) (takes
  under a minute; no credit card required).

## Installation

> [!IMPORTANT]
>
> Make sure you've signed up for a [free **Infracost account**](https://dashboard.infracost.io) before trying to use the AI skills (takes under a minute; no credit card required).

### Claude Code

Install the plugin from the marketplace:

```claude-code
/plugin marketplace add infracost/agent-skills
/plugin install infracost@infracost
# Restart Claude
```

The skills will then be available as `/infracost:<skill>` slash commands.

## Quick Start

After installing, try any of these prompts:

**Scan for costs and policy violations:**

```
Scan this Terraform project and tell me which resources are missing required tags.
```

**Look up pricing without any existing code:**

```
How much does an RDS PostgreSQL db.r5.xlarge cost in us-east-1?
```

**Optimize to a budget:**

```
Our budget is $2,000/month. Which resources are pushing us over, and what is the quickest
way to get under budget?
```

**Generate compliant infrastructure:**

```
Write Terraform for an RDS PostgreSQL instance for our payments service in us-east-1.
Required tags: team=payments, env=prod, cost-center=platform. Budget: $500/month.
```

## How It Works

The Infracost skills connect to **Infracost Cloud** to retrieve real pricing data and your
organization's policies. They read your local IaC files and combine that with live
pricing and policy data to answer questions, surface violations, suggest fixes, and
generate compliant new resources.

## Docs

- [AI Skills overview](https://infracost.io/docs/infracost_cloud/ai_skills/)

## Links

- **Website:** [infracost.io](https://infracost.io)
- **Sign up (free):** [dashboard.infracost.io](https://dashboard.infracost.io)
- **Docs:** [infracost.io/docs/infracost_cloud/ai_skills/](https://infracost.io/docs/infracost_cloud/ai_skills/)
- **Issues / feedback:** [github.com/infracost/infracost/discussions](https://github.com/infracost/infracost/discussions)
