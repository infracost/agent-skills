# Testing the CLI binding against GitLab Duo

The agnostic layers (the `infracost` CLI and the skills) are already in production use — they don't
need re-testing here. **This plan only covers the Duo-specific integration points**: whether each Duo
surface (1) discovers our instruction files, (2) runs the `infracost` commands, and (3) behaves at
the command-approval gate the way the metacharacter-free design assumes.

All facts below are verified against docs.gitlab.com (2026); see
[duo-binding-notes.md §8](duo-binding-notes.md) for sources and version floors.

## What Duo reads (so the test repo must be laid out right)

- `AGENTS.md` — **repo root**. Primary entrypoint. (Chat 18.7 / flows GA 18.8 / UI 18.11.)
- `.gitlab/duo/chat-rules.md` — always-on guardrails. (GA 18.8.)
- Native Agent Skills would need `skills/<name>/SKILL.md` at **project root** — **we don't ship these**
  (our skills live under `plugins/infracost/skills/`). The Duo path relies on `AGENTS.md`, which points
  at the skill files. If you want to test the native `/infracost-scan` slash-command route too, that's a
  separate follow-up (requires a root `skills/` dir).

## Getting Duo access for free

- **Recommended:** start the **GitLab Ultimate trial** (30 days, no credit card) from a Free
  account → grants ~24 GitLab credits and full Agent Platform access.
  <https://docs.gitlab.com/subscriptions/gitlab_duo_trials/>
- **Local-only, fastest:** install the **Duo CLI** (`glab duo cli`, or the install script — the npm
  method is deprecated as of 19.1), authenticate with a **Personal Access Token** (`api` scope) or
  `GITLAB_TOKEN`, and run it against a local checkout. Tier is listed as Premium/Ultimate, so use the
  trial token. <https://docs.gitlab.com/user/gitlab_duo_cli/>
- GitLab.com **Free** tier *does* expose Agentic Chat but consumes credits ($1 each), so the trial is
  the cleaner "free with budget" route.

## Test repo setup

1. Push a repo (or point the Duo CLI at a local checkout) that contains, at root: `AGENTS.md`,
   `.gitlab/duo/chat-rules.md`, `GEMINI.md`, and `plugins/infracost/BINDINGS.md`.
2. Add a small Terraform fixture, e.g. `fixtures/main.tf` with a couple of priced, under-tagged
   resources (an `aws_instance` + `aws_ebs_volume`), so scans return real findings.
3. Ensure `infracost` is installed in the surface's shell and authenticated (local login for IDE/CLI;
   `INFRACOST_API_KEY` for headless — see the headless test).

## The three core task prompts (use on every surface)

1. **Full cost breakdown** — *"Use Infracost to give me a full cost breakdown of `fixtures/`."*
2. **Tagging violations** — *"Which resources in `fixtures/` are missing required tags?"*
3. **No-code price lookup** — *"How much does an RDS PostgreSQL db.r5.xlarge cost in us-east-1?"*

## Per-surface test matrix

| # | Surface | Runs shell? | What to verify | Pass criteria |
|---|---------|-------------|----------------|---------------|
| A | **VS Code** (GitLab Workflow ext, Agentic Chat) | yes | Duo loads `AGENTS.md` + `.gitlab/duo/chat-rules.md`; runs the 3 prompts via `infracost …`; honors the guardrails | All 3 tasks complete using `infracost` commands; never runs `auth login`; never prints `INFRACOST_API_KEY` |
| B | **JetBrains** (GitLab plugin, Agentic Chat) | yes | Same as A | Same as A |
| C | **Duo CLI** (`glab duo cli`, interactive) | yes | Same as A, plus that it picks up files from the local checkout | Same as A |
| D | **GitLab web UI** Agentic Chat | **no shell** | Confirm the *expected limitation*: the CLI binding can't run here | Duo reads `AGENTS.md`/rules but cannot execute `infracost`; document this as a known boundary (UI users need the MCP path or an IDE) |
| E | **Duo CLI headless / CI flow** | yes (auto-approves) | Headless auth + non-interactive run | With `INFRACOST_API_KEY` + `INFRACOST_CLI_ORG` set, the 3 tasks run with no approval prompts and no interactive login |

## Approval-gate test (the key Duo-specific behavior)

This is what the metacharacter-free design is *for*. On an IDE surface (A or B):

1. Run task 1 (full breakdown). When Duo prompts to approve `infracost scan …`, confirm the
   **"Approve all uses of this tool for session" (pattern/wildcard)** option is offered — because the
   command has no shell metacharacters.
2. Approve the pattern, then run task 2 (tagging). Confirm subsequent `infracost scan` / `infracost
   inspect` commands reuse the pattern approval **without re-prompting**.
3. Run task 3 (price). Confirm that because it uses a heredoc (`infracost price << EOF`), the
   pattern option is **not** offered and it falls back to "Approve for session" — the one documented
   exception. (Behavior is GitLab 19.1+; earlier versions only have approve-once / approve-session.)

Pass: metacharacter-free commands get pattern approval; `price` degrades to session approval; nothing
forces per-command approval for the normal flow.

## Guardrail checks (any surface)

- Ask Duo to "log in to Infracost for me" → it must **refuse to run `infracost auth login`** and ask
  you to do it in your own terminal.
- Inspect the transcript / any committed files → **no `INFRACOST_API_KEY` or token values** echoed or
  written; no generated price-lookup `.tf` left in the repo.
- Confirm no `jq`/`awk`/redirect pipelines — Duo should use `--llm` / `--fields` / `--filter`.

## Out of scope

`fix-findings` (MCP-only) is not part of the Duo binding — don't test it here.
