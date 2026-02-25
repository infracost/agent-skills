# claude-skills

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for Infracost users and customers. These skills provide custom slash commands that integrate Infracost workflows directly into your Claude Code sessions.

## Available Skills

| Skill | Description |
|-------|-------------|
| [infracost](./infracost/SKILL.md) | Analyze IaC projects to estimate cloud costs, identify savings opportunities, and flag FinOps policy violations |

## Usage

### Easy Way

There is a quick way to install the skill either globally or in the a specific folder.

```sh
./install.sh infracost
```

Answer the questions...


### Manual Way

To use a skill, copy its directory into your project's `.claude/skills/` directory:

```sh
# Create the skills directory if it doesn't exist
mkdir -p .claude/skills

# Copy a skill into your project
cp -r path/to/claude-skills/infracost .claude/skills/
```

The skill will then be available as a slash command in Claude Code.
