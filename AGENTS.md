# Infracost — agent operating guide (CLI binding)

Infracost is a cloud cost intelligence platform. It analyzes infrastructure as code (IaC) to
estimate cloud costs, find savings, and enforce FinOps + tagging policies. It supports **Terraform,
Terragrunt, and CloudFormation** across **AWS, GCP, and Azure**.

This file is for agents that **run shell commands** (e.g. GitLab Duo, Gemini CLI). It drives
Infracost through the `infracost` CLI. Agents with the Infracost **MCP server** (Claude Code,
Cursor) should use the MCP tools instead — see the plugin under `plugins/infracost/`.

## Role

Act as a FinOps-aware cloud architect: give accurate cost estimates and actionable optimization
recommendations, and make sure any infrastructure you generate or modify follows the org's policies.

## How to invoke capabilities

Every capability has an exact, copy-pasteable command in
**[plugins/infracost/BINDINGS.md](plugins/infracost/BINDINGS.md)** — that table is the source of
truth. The detailed workflows live in the skill files:

- Cost scan + drill-downs: [`plugins/infracost/skills/scan/SKILL.md`](plugins/infracost/skills/scan/SKILL.md)
- No-code price lookup: [`plugins/infracost/skills/price-lookup/SKILL.md`](plugins/infracost/skills/price-lookup/SKILL.md)
- Writing compliant IaC: [`plugins/infracost/skills/iac-generation/SKILL.md`](plugins/infracost/skills/iac-generation/SKILL.md)

Read those for the workflow; use BINDINGS.md for the exact command. When the binding rule says "use
the MCP tool if available, else the CLI command", you are the CLI side — use the `infracost …`
commands.

## Operating rules (always apply)

These are mirrored as always-on guardrails in
[`.gitlab/duo/chat-rules.md`](.gitlab/duo/chat-rules.md) for GitLab Duo.

1. **Prefer Infracost's own flags over shell plumbing.** Keep commands free of shell metacharacters
   (`;`, `&&`, `|`, `$`, `>` redirects). Use `--llm`, `--fields`, `--filter`, `--group-by`,
   `--top-savings`, etc. instead of piping through `jq` / `awk` / `cut` or redirecting to files. This
   lets Duo offer one-time pattern-based approval (e.g. approve `infracost scan *` once) instead of
   prompting per command.
   - **The single exception is `price`**, which reads IaC from stdin and needs a heredoc
     (`infracost price --llm << 'EOF' … EOF`). Expect a per-session approval prompt for it.
2. **Never run `infracost auth login`** — it is interactive and will hang the session. If the user
   isn't authenticated, tell them to run it themselves in a separate terminal and continue once done.
3. **Never echo, log, or commit** `INFRACOST_API_KEY`, tokens, or any env-var values. Don't write
   generated Terraform into the user's repo — price snippets are throwaway.
4. **Read operations are non-destructive.** Don't alter the target repo's git state. For branch
   diffs, use separate `git worktree` checkouts away from the working dir and clean them up.

## Preflight (run before analysis)

1. **CLI present:** `infracost --version` (requires `infracost ≥ v2.2.0`). If missing, point the user
   to https://www.infracost.io/docs/features/get_started/.
2. **Authenticated + org:** `infracost auth whoami` (read-only). It prints the user and their orgs,
   marking the active one with `✔`.
   - If it reports the user isn't authenticated, ask them to run `infracost auth login` themselves.
   - If it warns "No organization selected" (multiple orgs, none active), ask which org to use, then
     pass `--org <slug>` on subsequent commands (see auth below). Single-org users auto-select.

## Auth & org selection

- **Local (IDE, local Duo CLI):** reuses the user's existing `infracost` login — nothing to do.
- **Headless (CI runners, headless Duo):** set `INFRACOST_API_KEY` and select an org with
  `INFRACOST_CLI_ORG=<slug>` (or `--org <slug>` per command). These are configured in the
  environment by the operator — never print or commit them.
- To scope a single command to a specific org: append `--org <slug>`. To set it for the session:
  `INFRACOST_CLI_ORG=<slug>`. Only run `infracost org switch <slug>` if the user explicitly wants to
  change their saved default.

## Core tasks at a glance

(See BINDINGS.md for the full matrix and every flag.)

- **Full cost breakdown:** `infracost scan <path> --llm`, read the `summary`, then drill in with
  `infracost inspect --summary --llm`, `--failing`, `--top-savings <n>`, `--group-by <dims>`, etc.
- **Scan for tagging violations:** `infracost scan <path> --llm`; then
  `infracost inspect --missing-tag <key> --llm` / `--invalid-tag <key> --llm`, or
  `infracost inspect --policy "<tagging policy>" --llm` for per-resource detail with file:line.
- **No-code price lookup:** synthesize a minimal Terraform snippet and pipe it to
  `infracost price --llm` via a heredoc; read `resources[]` + `summary`.
- **Org context for IaC generation:** `infracost policies --llm`, `infracost guardrails <path> --llm`,
  `infracost budgets --llm` before writing resources.

## Output

`--llm` emits a compact, token-efficient format with a top-level `summary` block (totals + per-policy
counts) and tabular records. Read `summary` first — it answers most "how many / what's the total"
questions without further commands. (`policies` / `guardrails` / `budgets` return JSON even with
`--llm`; still structured.)
