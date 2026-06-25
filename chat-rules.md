# Infracost — agent guardrails

Always-on rules for any agent driving Infracost via the `infracost` CLI. Full guide:
[AGENTS.md](AGENTS.md). Command matrix: [plugins/infracost/BINDINGS.md](plugins/infracost/BINDINGS.md).

- **Keep `infracost` commands free of shell metacharacters** (`;`, `&&`, `|`, `$`, `>` redirects).
  Use the CLI's own flags (`--llm`, `--fields`, `--filter`, `--group-by`, `--top-savings`) instead of
  piping to `jq`/`awk`/`cut` or redirecting to files. **Only exception:** `infracost price` reads IaC
  from stdin via a heredoc.
- **Never run `infracost auth login`** — it is interactive and will hang. Ask the user to run it
  themselves if they aren't authenticated.
- **Never echo, log, or commit** `INFRACOST_API_KEY`, tokens, or other env-var values. Never write
  generated price-lookup Terraform into the user's repo.
- **Run preflight before analysis:** `infracost --version`, then `infracost auth whoami`. Select the
  org with `--org <slug>` / `INFRACOST_CLI_ORG` if more than one exists.
- **Don't alter the target repo's git state.** Read operations are non-destructive; for branch diffs
  use separate worktrees and clean them up.
- **Requires `infracost ≥ v2.2.0`.**
