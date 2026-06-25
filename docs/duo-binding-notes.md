# Phase 0 findings — direct-CLI binding for the Infracost agent-skills (GitLab Duo support)

Status: **investigation complete, no code changes made.** This note records what was
confirmed empirically against the installed CLI and this repo's git history, so the
implementation phases don't have to rediscover it.

Environment used for verification:

- `infracost version v2.5.2` (installed locally, on `PATH` at `/opt/homebrew/bin/infracost`).
- Authenticated as a real user with three orgs; `glenngillen` active. `auth whoami` works read-only.

---

## 0. Spec assumptions that need correcting

- **Spec §2 says the repo already has a "top-level `SKILL.md` router".** Confirmed — `SKILL.md`
  exists at the repo root and links to the four skill modules. ✅ (no correction needed)
- **Spec §3 / §5 imply `price` takes an in-memory snippet and the CLI equivalent is the open
  question.** Confirmed and sharper than the spec assumed: `infracost price` reads IaC **only
  from stdin** — there is no `--file`/path argument. Every way to feed it (`<`, `|`, heredoc)
  uses a shell metacharacter, so `price` **cannot** be invoked metacharacter-free. See §5 and §6.
- **Spec §6 Phase-3 says "replace the SessionStart hook".** The hook
  (`hooks/hooks.json` → `scripts/validate_setup.sh`) is Claude-Code-plugin-specific. It does not
  need replacing for the MCP path; for Duo we add inline preflight instructions instead. The
  existing hook stays untouched (no MCP regression).
- **fix-findings is broader than the spec's §5 inventory.** The spec's capability list omits the
  Agents findings/fix tools. They are only partially mappable to the CLI (see §5) — flag, don't
  silently drop.

---

## 1. MCP transport (Phase 0 Q1)

`infracost mcp --help`:

> Run as a Model Context Protocol (MCP) **stdio** server. … launched by an MCP-aware client
> which communicates over stdin/stdout.

**stdio only. No remote/HTTP transport.** Consistent with the non-goal of a remote MCP server.
The `.mcp.json` declares `command: infracost, args: ["mcp"]` — unchanged by this work.

---

## 2. Recovered pre-MCP CLI command set (Phase 0 Q2)

The pre-MCP release drove Infracost via direct CLI. Recovered from the parent of the MCP-switch
commit `17a79a6 feat: switch skills to the Infracost MCP server (FIX-156) (#51)`:

- `git show 17a79a6^:plugins/infracost/skills/scan/SKILL.md`
- `git show 17a79a6^:plugins/infracost/skills/price-lookup/SKILL.md`

Those files contain a full, mature CLI binding: `infracost scan <path>`, the entire
`infracost inspect` flag surface (`--summary`, `--failing`, `--group-by`, `--policy`,
`--budget`, `--guardrail`, `--top-savings`, `--missing-tag`, `--fields`, `--filter`, …),
`infracost price` via heredoc, plus `--json` / `--llm` output flags and an explicit
"use native flags, not jq/awk" anti-pattern table.

**Reconciled against the installed v2.5.2 CLI** (`infracost <cmd> --help`): every recovered
flag still exists. The flag surface in the pre-MCP `scan`/`price-lookup` skills matches v2.5.2
1:1. `fix-findings` was added *after* the MCP switch and never had a CLI form.

### `--llm` flag (Phase 0 Q2 cont.)

`--llm` is a **global** flag, present on `scan`, `price`, `inspect`, `policies`, `guardrails`,
`budgets`, `findings`, and `mcp`. Help text: *"Output command results in a compact,
token-efficient format intended for LLM prompts."* This is the current equivalent of the old
`--llm`; it has not been renamed.

---

## 3. Output parity: CLI `--llm` vs MCP tools (Phase 0 Q3)

`infracost mcp --help` states the MCP server *"Exposes the same operations as the top-level CLI
commands as MCP tools, **backed by the same Go functions**."* The MCP-switch commit message says
the same. So parity is structural, not coincidental.

Verified empirically (AWS Terraform snippet, `glenngillen` org):

- **`infracost scan --llm <dir>`** emits a top-level `currency` + `summary` block whose fields
  match the MCP `scan` summary documented in the current skill (`projects`, `resources`,
  `costed_resources`, `monthly_cost`, `finops_policies`, `failing_tagging_policies`,
  `distinct_failing_tagging_resources`, `guardrails`, `triggered_guardrails`, `budgets`,
  `over_budget`, diagnostics, per-project rows), plus nested `finops_results` / `tagging_results`.
- **scan→inspect "latest scan" caching works.** After a `scan`, `infracost inspect --summary --llm`
  (no `--file`) read the cached result. This is the CLI analogue of the MCP session cache that the
  `inspect_*` tools read. ✅ Same semantics.
- **`inspect --failing --llm`** returns tabular rows (`kind,policy,project,resource,file,line`)
  + `triggered_guardrails` + `over_budget` — the union view the MCP `inspect_failing` returns.
- **`inspect --summary --fields <name>`** projects a single scalar (bare value) — the
  metacharacter-free replacement for `--json | jq`.

### Divergences found (document, don't code around)

1. **Summary scalar field name.** `infracost scan --llm` prints the headline number as
   `total_monthly_cost`, but `inspect --summary --fields` calls the same field **`monthly_cost`**
   (`--fields total_monthly_cost` errors with the valid-field list). The current MCP skill already
   uses `monthly_cost` for the summary — so the matrix should standardize on the **`inspect`**
   field names. Minor, but it will bite anyone copying field names between the two outputs.
2. **`policies` / `guardrails` / `budgets` ignore `--llm` and emit JSON.** `infracost policies
   --finops-only --llm` returned pretty-printed JSON, not the compact indentation format. Still
   structured and metacharacter-free, just not the token-compact shape. The MCP `policies` tool
   returns JSON too, so this is parity-preserving; note it so nobody expects `--llm` compaction here.
3. **`price` has no `--llm`-able file input** — see §5/§6.

Net: **output parity is HIGH.** The CLI binding is thin. This drives the Phase 4 recommendation
(single dual-binding file, no build step).

---

## 4. Version floor (Phase 0 Q4)

The MCP path floors at `infracost ≥ v2.2.0` (`scripts/validate_setup.sh`, first shipped `infracost
mcp` in FIX-154). For the CLI/`--llm` path, `scan`/`inspect`/`price`/`policies`/`guardrails`/
`budgets` + `--llm` all predate the MCP refactor (they're the pre-MCP binding), so they exist at or
below the 2.2.0-era floor. **Recommendation: document the same `v2.2.0` floor for the CLI binding**
— one number, simpler messaging.

**Caveat:** `infracost findings list|get|update` is a newer subcommand and may need a higher floor.
This only matters for a CLI form of `fix-findings`, which is a documented gap anyway (§5). Exact
floor for `findings` should be confirmed against the CLI changelog if/when fix-findings gets a CLI
binding. Flagged as a minor open item.

---

## 5. Capability inventory → CLI mapping (Phase 0 Q3 detail / preview of the Phase 1 matrix)

All commands below are **metacharacter-free** unless marked. Auth/org via `--org <slug>` (per-call,
clean) or `INFRACOST_API_KEY` + `INFRACOST_CLI_ORG` (headless).

| Capability (MCP tool) | CLI equivalent | Notes |
|---|---|---|
| `scan(path)` | `infracost scan <path> --llm` | caches result for inspect |
| `inspect_summary` | `infracost inspect --summary --llm` | reads latest cached scan |
| `inspect_failing` | `infracost inspect --failing --llm` | |
| `inspect_top_savings(n)` | `infracost inspect --top-savings <n> --llm` | |
| `inspect_resources` (flat) | `infracost inspect --llm` + `--missing-tag` / `--invalid-tag` / `--min-cost` / `--max-cost` / `--top` / `--costs-only` | |
| `inspect_resources` (group_by) | `infracost inspect --group-by <dims> --llm` | dims: type,provider,project,resource,file,policy,guardrail,budget |
| `inspect_diagnostics` | `infracost inspect --diagnostics --llm` | |
| `inspect_policy_detail` | `infracost inspect --policy "<name>" --llm` (+ `--resource "<addr>"`) | |
| `inspect_budget_detail` | `infracost inspect --budget "<name>" --llm` | |
| `inspect_guardrail_detail` | `infracost inspect --guardrail "<name>" --llm` | |
| `price(iac=...)` | **GAP / workaround** — `price` is stdin-only | see §6 |
| `policies` | `infracost policies --llm` (+ `--finops-only` / `--tagging-only` / `--providers`) | emits JSON |
| `guardrails` | `infracost guardrails <path> --llm` | emits JSON |
| `budgets` | `infracost budgets --llm` | emits JSON |
| preflight: CLI present | `infracost --version` | |
| preflight: authed | `infracost auth whoami` | read-only; lists orgs + active marker |
| preflight: org | `--org <slug>` per call / `INFRACOST_CLI_ORG` / `infracost org switch <slug>` | never run `auth login` |

**`--filter` is metacharacter-safe:** `--filter "tag.team=missing,provider=aws"` — the value uses
`=` and `,`, neither of which is in Duo's metacharacter set (`;`, `&&`, `|`, `$`, redirects). The
surrounding quotes are fine.

### fix-findings — out of scope (decision: MCP-only)

`fix-findings` is backed by Infracost Agents, an **early-access prototype that is not being
documented yet** (owner decision, 2026-06-25). It therefore gets **no CLI binding** and stays
MCP / Claude-Code-only. Its underlying CLI surface is intentionally left undocumented here. It is
not part of the Duo target and not in the spec's core acceptance tasks (cost breakdown, tagging
scan, price lookup).

---

## 6. The one real gap: `price` is stdin-only

`infracost price --help`: *"Read IaC from stdin, scan it, and print the cost estimate."* No path
argument, no `--file`. Pre-MCP, the skill used a heredoc (`infracost price << 'EOF' … EOF`) — a
metacharacter (`<<`). Under Duo's approval gate that forces per-session approval, defeating smooth
pattern-based approval.

**Verified workaround (recommended):** the agent writes a minimal `.tf` file to a temp dir using
its *file-write* capability (not a shell redirect), then runs a metacharacter-free
`infracost scan <tempdir> --llm`. Empirically, scanning a generated single-resource dir produced
the **same** `summary` + `finops_results` + `tagging_results` shape as `price` would — `price` is
literally "scan from stdin", so a scan of a temp file is output-equivalent. Clean up the temp dir
after. The current MCP `price-lookup` skill already says "the snippet is throwaway, never written
to the user's workspace" — a temp dir outside the workspace honors that.

**Decision (owner, 2026-06-25): option B — heredoc, accept the approval fallback.** Stay close to
the existing skill; accept that `infracost price << EOF … EOF` triggers Duo's per-session approval
rather than smooth pattern-based approval. The metacharacter-free rule still applies to **every
other** command so they stay pattern-approvable; `price` is the single documented exception.

Options that were considered:
- **(A)** temp-file + `infracost scan <dir>` — fully metacharacter-free, output-identical. Not chosen
  (adds temp-file lifecycle; owner preferred staying close to the existing heredoc skill).
- **(B, chosen)** `infracost price` with a heredoc, accepting per-session approval fallback in Duo.
- **(C)** request a CLI enhancement: `infracost price --file <path>`. Cleanest long-term; needs a
  CLI change. Worth raising separately but not blocking this work.

---

## 7. Decisions + recommendations feeding the work plan

1. **Structure (Phase 4) — DECIDED:** parity is high and the binding is thin → **single dual-binding
   `SKILL.md` per skill, no build step.** Keep skill bodies capability-level (Phase 2), push exact
   commands into one `BINDINGS.md` matrix (Phase 1), add a one-line runtime-detection invocation
   rule ("MCP server present → use its tools; else run the matrix CLI command"). Single source of
   truth, no build toolchain.
2. **No MCP regression:** don't touch `.mcp.json`, `hooks/hooks.json`, `validate_setup.sh`, or the
   plugin manifest. The Claude Code reading path must stay behaviorally identical.
3. **Duo packaging (Phase 3):** add Duo-facing files referencing the same skills + matrix, inline the
   preflight (`--version`, `auth whoami`, org selection), document headless auth (`INFRACOST_API_KEY`,
   `INFRACOST_CLI_ORG`/`--org`), and state the never-run-`auth login` rule. Exact file set
   (`AGENTS.md` vs `+ chat-rules.md`) — see §8.
4. **price — DECIDED:** option **B**, heredoc + per-session approval fallback (§6). `price` is the one
   documented metacharacter exception; everything else stays pattern-approvable.
5. **fix-findings — DECIDED:** MCP-only. Early-access prototype, not documented (§5).

## 8. Open questions for the owner (don't guess)

1. **Exact Duo file layout + `SKILL.md`/`AGENTS.md` support floor** on the GitLab versions Infracost
   users actually run. Spec says ~GitLab 19.0–19.1, experimental — **unverified from this repo or the
   CLI**; needs confirmation from Duo docs / real user versions. (`AGENTS.md` carries capability
   logic + binding rules; `chat-rules.md` is optional always-on guardrails — add only if rules need
   to be enforced separately from the skill body.)
