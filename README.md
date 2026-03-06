# agent-skills

A collection of AI coding agent skills for Infracost users and customers. These skills integrate Infracost workflows directly into your AI coding agent, providing cost estimation, optimization recommendations, and FinOps policy compliance for infrastructure as code.

## Available Skills

| Skill                                                                | Description                                                                                                     |
|----------------------------------------------------------------------| --------------------------------------------------------------------------------------------------------------- |
| [iac-generation](./plugins/infracost/skills/iac-generation/SKILL.md) | Ensure cost optimization and policy compliance when writing infrastructure as code                              |
| [install](./plugins/infracost/skills/install/SKILL.md)               | Install or update the Infracost CLI from GitHub releases                                                        |
| [price-lookup](./plugins/infracost/skills/price-lookup/SKILL.md)     | Look up cloud resource pricing by generating sample Terraform and running Infracost                             |
| [scan](./plugins/infracost/skills/scan/SKILL.md)                     | Analyze IaC projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations |
| [uninstall](./plugins/infracost/skills/uninstall/SKILL.md)           | Uninstall the Infracost CLI                                                                                     |

## Usage

### Claude Code

Install the plugin from the marketplace:

```bash
claude
/plugin marketplace add infracost/agent-skills
/plugin install infracost@infracost
# Restart Claude
```

The skills will then be available as `/infracost:<skill>` slash commands.
