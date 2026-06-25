# Infracost capability ↔ binding matrix

**This file is the single source of truth for how each Infracost capability is invoked.**

The skills describe *what* to do in capability-level language ("get a scan summary", "drill
into a failing policy"). This file maps each capability to the two concrete bindings:

- **MCP binding** — a typed tool call. Used by Claude Code, Cursor, and other MCP clients (the
  plugin starts `infracost mcp` automatically).
- **CLI binding** — an `infracost …` command. Used by agents that run shell commands (GitLab Duo,
  Gemini CLI).

**Invocation rule (every skill follows this):** *If the Infracost MCP server is available, use its
tools. Otherwise, run the equivalent CLI command from this table.*

Adding a new capability = adding one row here.

---

## Conventions

- **CLI output flag:** append `--llm` to every analysis command — a compact, token-efficient format.
  (`policies` / `guardrails` / `budgets` accept the flag but emit JSON regardless; still structured.)
- **Org/auth:** add `--org <slug>` to scope a single call, or set `INFRACOST_CLI_ORG` for the
  session. Never run `infracost auth login` (interactive) from an agent.
- **Metacharacter-free:** every CLI command below avoids shell metacharacters (`;`, `&&`, `|`, `$`,
  `>` redirects) so Duo can offer pattern-based approval. **The one exception is `price`** — it reads
  IaC from stdin and needs a heredoc; see its row.
- **Field names:** when projecting summary scalars, use the **`inspect --fields`** names (e.g.
  `monthly_cost`, not `total_monthly_cost`). `scan --llm` prints `total_monthly_cost` in its block,
  but the canonical field name for projection is `monthly_cost`.

---

## Analysis capabilities

| Capability | MCP tool | CLI command |
|---|---|---|
| **Scan an IaC path** (caches a "latest scan" the inspect ops read) | `scan(path, currency?)` | `infracost scan <path> --llm` (add `--currency <ISO>`) |
| **Summary of the latest scan** | `inspect_summary(path?, project?, provider?, fields?)` | `infracost inspect --summary --llm` (add `--project` / `--provider`; `--fields <a,b>` to project columns; one field → bare scalar) |
| **Everything currently failing** (failing policies + triggered guardrails + over-budget) | `inspect_failing(path?, project?, provider?, filter?)` | `infracost inspect --failing --llm` |
| **Top N savings opportunities** | `inspect_top_savings(n=10, path?, …filters)` | `infracost inspect --top-savings <n> --llm` |
| **List resources by predicate** (flat) | `inspect_resources(missing_tag?, invalid_tag?, min_cost?, max_cost?, resource?, costs_only?, top?, project?, provider?, filter?, path?)` | `infracost inspect --llm` + any of `--missing-tag <k>` / `--invalid-tag <k>` / `--min-cost <n>` / `--max-cost <n>` / `--resource <addr>` / `--costs-only` / `--top <n>` |
| **Aggregate resources by dimension** (grouped) | `inspect_resources(group_by=[…], top?, …filters, path?)` | `infracost inspect --group-by <dims> --llm` (dims: `type,provider,project,resource,file,policy,guardrail,budget`; comma-separated) |
| **Per-project diagnostics** | `inspect_diagnostics(project?, critical_only?, path?)` | `infracost inspect --diagnostics --llm` |
| **Failing-resource detail for one policy** | `inspect_policy_detail(policy, resource?, path?)` | `infracost inspect --policy "<name>" --llm` (add `--resource "<addr>"` for one resource) |
| **Detail for one budget** (matching resources + savings) | `inspect_budget_detail(budget, path?)` | `infracost inspect --budget "<name>" --llm` |
| **Status + cost for one guardrail** | `inspect_guardrail_detail(guardrail, path?)` | `infracost inspect --guardrail "<name>" --llm` |
| **Price a standalone Terraform snippet** (no files on disk) | `price(iac, currency?)` | **heredoc (metacharacter exception):** `infracost price --llm` ⟵ IaC on stdin via `<< 'EOF' … EOF` (add `--currency <ISO>`). See note below. |

### `inspect` compatibility rules (apply to both bindings)

- `--policy` / `--budget` / `--guardrail` (MCP: `policy` / `budget` / `guardrail` group-by keys) are
  pairwise mutually exclusive in one call.
- `guardrail` and `budget` can't combine with resource-context dims (`type`, `provider`, `project`,
  `resource`, `file`). `policy` *can* (e.g. `--group-by policy,type`).
- Resource predicates (`missing_tag`, `invalid_tag`, `min_cost`, `max_cost`) only apply in flat mode.

### `price` note (the one metacharacter exception)

`infracost price` reads IaC **only from stdin** — there is no path/`--file` flag. The CLI binding
feeds it with a heredoc:

```bash
infracost price --llm << 'EOF'
provider "aws" { region = "us-east-1" }
resource "aws_instance" "web_server" {
  instance_type = "m5.xlarge"
}
EOF
```

The heredoc (`<<`) is a shell metacharacter, so under Duo's approval gate this falls back to
per-session approval rather than smooth pattern approval. This is the single accepted exception;
every other command stays metacharacter-free. `price` caches its result like `scan`, so the
`inspect_*` / `infracost inspect` capabilities read it afterward.

---

## Org settings capabilities

| Capability | MCP tool | CLI command |
|---|---|---|
| **List FinOps + tagging policies** | `policies(providers?)` | `infracost policies --llm` (add `--finops-only` / `--tagging-only` / `--providers <aws,…>`) |
| **List repo cost guardrails** | `guardrails(path)` | `infracost guardrails <path> --llm` |
| **List org tag-scoped budgets** | `budgets()` | `infracost budgets --llm` |

---

## Preflight capabilities

| Capability | MCP binding | CLI command |
|---|---|---|
| **CLI present** | (n/a — plugin requires it) | `infracost --version` |
| **Authenticated** | resolved at MCP startup | `infracost auth whoami` (read-only; lists orgs + active marker) |
| **Org selected** | resolved at MCP startup | per call: `--org <slug>`; session: `INFRACOST_CLI_ORG=<slug>`; persist: `infracost org switch <slug>` (only if the user wants to change their default) |

**Auth model:**
- *Local surfaces* (IDE, local Duo CLI) reuse the user's existing `infracost` login — nothing to do.
- *Headless surfaces* (CI runners, headless Duo) use `INFRACOST_API_KEY` + org selection
  (`INFRACOST_CLI_ORG` or `--org <slug>`).
- **Never** run `infracost auth login` — it is interactive and will hang an agent session.

---

## Version floor

Both bindings target **`infracost ≥ v2.2.0`** (the MCP path's existing floor; the CLI
`scan`/`inspect`/`price`/`policies`/`guardrails`/`budgets` + `--llm` surface predates that floor).

---

## Out of scope

`fix-findings` (Infracost Agents) is MCP / Claude-Code-only and **not** part of the CLI binding —
it is an early-access prototype that is not being documented yet. It has no row here.
