# Infracost AI Agent Skills

Cloud cost intelligence for AI coding agents.

[![License](https://img.shields.io/github/license/infracost/agent-skills)](LICENSE)

https://github.com/user-attachments/assets/16eef8f1-5bc1-4e5f-b5c4-c7594d883057

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
| [fix-findings](./plugins/infracost/skills/fix-findings/SKILL.md)     | Apply Agents FinOps findings — fix locally when the task carries the code, or have Agents draft a PR / ticket     |

Works with **Terraform, Terragrunt, and CloudFormation**. Supports **AWS, GCP, and Azure**.

## Prerequisites

- A free **Infracost account** — [sign up at infracost.io](https://dashboard.infracost.io) (takes
  under a minute; no credit card required).

## Installation

> [!IMPORTANT]
>
> Make sure you've signed up for a [free **Infracost account**](https://dashboard.infracost.io) before trying to use the AI skills (takes under a minute; no credit card required).

Instructions on how to install these skills in your favorite agent are available via our [official AI Agent Skills docs](https://www.infracost.io/docs/ai_editor_plugins/ai_skills/)

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

**Fix the FinOps findings on this repo:**

```
Walk me through my open Infracost findings and help me fix them. Open PRs via
Agents where it makes sense; do the simple ones locally.
```

## How It Works

The skills are single-sourced and written in terms of **capabilities** (`scan`, `price`,
`policies`, `budgets`, `guardrails`, and the `inspect`/`inspect_*` drill-ins). Each capability
has two thin **bindings** — the same Infracost engine, invoked two ways — and each agent uses
whichever fits how it works. The capability ↔ binding map is in
[`plugins/infracost/BINDINGS.md`](./plugins/infracost/BINDINGS.md).

| Binding | Used by | How it's invoked |
| ------- | ------- | ---------------- |
| **MCP** | Claude Code, Cursor, other MCP clients | The plugin ships an MCP server (`infracost mcp`) that starts automatically; the agent calls typed tools and reads structured JSON — no flags, no shell pipelines, no JSON files to parse. |
| **CLI** | GitLab Duo, Gemini CLI, other shell-running agents | The agent runs `infracost …` commands directly. Commands are kept metacharacter-free (using the CLI's own `--llm` / `--fields` / `--filter` / `--group-by` flags) so Duo can offer pattern-based approval. See [AGENTS.md](./AGENTS.md) and [.gitlab/duo/chat-rules.md](./.gitlab/duo/chat-rules.md). |

The skill bodies hold one rule: *if the Infracost MCP server is available, use its tools; otherwise
run the equivalent CLI command from the matrix.* So the workflow, FinOps concepts, and presentation
guidance stay in one place — only the binding differs.

> **Note:** `fix-findings` (Infracost Agents) is MCP / Claude-Code-only and is not part of the CLI
> binding.

Under the hood both bindings connect to **Infracost Cloud** for live pricing data and your
organization's policies, and read your local IaC files. With MCP, auth + active organization are
resolved once at startup; with the CLI, they come from your existing `infracost` login (or
`INFRACOST_API_KEY` + `INFRACOST_CLI_ORG` on headless runners).

## Docs

- [AI Skills overview](https://infracost.io/docs/infracost_cloud/ai_skills/)

## Contributing

We welcome contributions! Please start by opening a thread in [GitHub Discussions](https://github.com/infracost/infracost/discussions) to discuss your idea before submitting a PR.

## Bugs and feedback

If you run into any issues or have feedback, please open a thread in [GitHub Discussions](https://github.com/infracost/infracost/discussions). We'd love to hear from you!

## Links

- **Website:** [infracost.io](https://infracost.io)
- **Sign up (free):** [dashboard.infracost.io](https://dashboard.infracost.io)
- **Docs:** [infracost.io/docs/infracost_cloud/ai_skills/](https://infracost.io/docs/infracost_cloud/ai_skills/)
- **Issues / feedback:** [github.com/infracost/infracost/discussions](https://github.com/infracost/infracost/discussions)
