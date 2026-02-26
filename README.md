# claude-skills

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for Infracost users and customers. These skills provide custom slash commands that integrate Infracost workflows directly into your Claude Code sessions.

## Available Skills

| Skill                                                  | Description                                                                                                     |
| ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| [analyze](./plugins/infracost/skills/analyze/SKILL.md) | Analyze IaC projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations |

## Usage

> [!NOTE]
> While the cli-poc repository and the claude-skills repository are private, ensure you have a GITHUB_TOKEN env var set (`gh auth login`).

```bash
claude
/plugin marketplace add infracost/claude-skills
/plugin install infracost@infracost
# Restart Claude
```

The plugin skills will then be available as `/infracost:<skill>` slash command in Claude Code.
