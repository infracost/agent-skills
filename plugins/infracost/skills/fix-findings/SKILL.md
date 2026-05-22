---
name: fix-findings
description: Walk a user through Infracost FinOps findings and apply fixes — either locally in their repo (when the task carries enough context to make a code edit), or by asking Agents to draft and open a PR / ticket on their behalf. Use this skill when the user asks to "fix the findings", "apply the recommendations", "open PRs for the FinOps issues", or otherwise wants to act on Agents' investigation results rather than just look at them.
---

# Fix Infracost Findings

Findings are org-scoped FinOps investigation results produced by Infracost's
Agents service. Each finding groups one or more **tasks** — the units of fix
work. A task carries an `action_description`, often a `code` snippet, and a
`suggested_action` of `open_pr`, `create_ticket`, or `manual`.

This skill drives the user through the findings list, lets them pick what to
work on, and then helps them apply each fix — either by editing files in their
local repository or by asking Agents to draft and open a PR / ticket via the
mutation tools.

This plugin ships an MCP server (`infracost mcp`) that's started automatically
when the plugin loads. Every Infracost operation in this skill is an MCP tool
call.

## MCP tools you'll use

| Tool | Side effect | Purpose |
|---|---|---|
| `findings_list` | none | Page through findings for the active org |
| `findings_get` | none | Full finding + nested tasks, actions, events |
| `preview_fix` | none | Ask Agents to draft a PR or ticket for a task |
| `create_fix` | **destructive** | Submit a drafted PR/ticket action — or, with `type="manual"`, **claim** a task before fixing it locally |
| `update_task_status` | **destructive** | Report what you did to a task. `confirm` = you did Agents' suggested change; `correct` = you did something different (requires reason); `dismiss` = you decided not to do the task (reason recommended). The three verbs feed different learning signals — pick by user intent, not for convenience |
| `update_finding_status` | **destructive** | Set a whole finding's status: `open` / `resolved` / `dismissed`. A dismissal with a reason emits an AgentLearning so the finding isn't re-raised |
| `retry_action` | destructive | Re-queue a Agents action whose worker landed in `failed` state |

The MCP server handles auth + active-org resolution at startup. If a tool returns "no organization selected" or "not authenticated", relay the actionable message to the user — don't retry blindly.

### What's *not* exposed via MCP

Dismissing an individual action (i.e. killing a draft PR before the worker runs) only lives in the Agents portal at https://coast.infracost.io. This is intentional: closing a real PR or archiving a real ticket should happen with the user looking at the upstream artifact. If the user wants to dismiss an *action* (not a task), point them to the dashboard.

## Workflow

The flow is always: **list → pick → drill in → check who already owns the task → choose how to fix → apply → report back to Agents**. Don't skip steps; the user needs to see what's available and consent to each action. The final "report back" step tells Agents what you did so its observation cascade can verify and close the task asynchronously. You're not verifying the change yourself — don't re-scan to second-guess Agents — you're just signalling what action was taken so Agents knows to look.

### 1. List findings

```
findings_list()
```

Useful inputs:

- `status` — `open` (default; matches both `open` and `in_progress`) is the right choice when the user wants to act on outstanding work. `resolved` / `dismissed` / `duplicate` are for history.
- `effort` — `trivial` / `small` / `medium` / `large` to narrow by how much work is involved.
- `limit` — caps page size (server defaults to 50, max 200). `cursor` pages.

The output carries `findings[]`, `total_savings` (page total — not org total), `next_cursor`, and `has_next_page`. Each finding row has `id`, `title`, `summary`, `effort`, `status`, `estimated_monthly_savings`, and `task_total`.

### 2. Present the list

Don't dump raw JSON. Present a numbered list, sorted by `estimated_monthly_savings` desc, and offer to drill in:

> You have **6 open findings** worth **~$1,240/mo** in potential savings:
>
> 1. **Idle EBS volumes** — $420/mo, 3 tasks, small effort (`f-abc`)
> 2. **Oversized RDS instances** — $310/mo, 2 tasks, medium effort (`f-def`)
> 3. **Untagged production resources** — $260/mo, 12 tasks, trivial effort (`f-ghi`)
> 4. …
>
> Which one would you like to start with?

If `has_next_page` is true, mention it and offer to page (`findings_list(cursor="...")`) — don't auto-fetch.

### 3. Drill into the chosen finding

```
findings_get(id="f-abc")
```

This returns the finding header plus every nested task with full `action_description`, `code`, `suggested_action`, `effort`, `savings`, plus any existing `actions` and timeline `events`. **Read this carefully** — the task body tells you whether each task is locally fixable.

Present the tasks under the finding, again numbered, with savings and a one-line summary. If a task has a clear `code` snippet that looks like a diff or a drop-in replacement, mention that — it's the signal for Path A below.

### 4. Check whether the task is already claimed

Before doing any work on a task, look at the data in the `findings_get` response to confirm it isn't already in flight:

- **`task.status`** — anything other than `open` means somebody (or something) has already started. The common non-open values are `in_progress` (Agents worker is opening a PR / creating a ticket), `awaiting_resolution` (a manual action exists and is waiting for confirmation), `resolved`, and `dismissed`.
- **`finding.actions[]`** — find any action whose `task_ids` includes the current task and whose `action_status` is not in the terminal set (`done` / `merged` / `deployed` / `verified` / `failed` / `cancelled` / `dismissed`). A `draft` or `open` action linked to the task means it's claimed.

If the task is claimed:

> Tell the user, surface the existing `action_id` + `type` + `action_status`, and direct them to the Agents portal at https://coast.infracost.io to dismiss or close the existing action before claiming the task themselves. Do **not** try to dismiss the action via MCP — that capability lives in the portal on purpose.

If the task is `open` *and* has no non-terminal linked action, you can move on to step 5.

### 5. Decide how to fix the task

There are three paths. Pick one — don't run more than one for the same task.

#### Path A — Fix it locally (preferred when feasible)

Choose this when **all** of the following hold:

- The task's `action_description` and/or `code` describe a concrete code change.
- The change is in IaC the user has on disk (Terraform, CloudFormation, Terragrunt) — i.e. you can find the file the change should land in.
- The change is bounded — single file or a small set of files, not a sweeping refactor.

How to do it:

1. **Claim the task in Agents first.** Call `create_fix` with `type="manual"` to register a manual action linked to the task. This moves the task to `awaiting_resolution` server-side, so another user or session can see it's in flight and won't double-claim it. The `config` is opaque JSON; a reasonable shape names what you're about to change:

   ```
   create_fix(
     finding_id="f-abc",
     task_id="t-1",
     type="manual",
     config={
       "intent": "Rename bucket attribute from \"hello\" to \"example-bucket-prod\"",
       "files": ["bin/example/main.tf"],
     },
   )
   ```

   Confirm the action with the user before calling — it's a destructive tool. The returned `action_id` is what you'll close in step 6.

2. Locate the target file(s). The task's `action_description` usually names them; if not, `grep` the user's repo for the resource address or distinctive attribute the snippet touches.

3. **Show the user the proposed edit before you make it** — quote the relevant lines and explain the change. This is the point at which the user can redirect: maybe Agents' suggestion isn't the right call and they want to make a different change instead. If that conversation happens, follow what the user decides — your job is to report *what was done*, not to defend Agents' original suggestion.

4. Apply the edit with the standard file-editing tools.

5. **Report what you did to Agents.** You're signalling *what action was taken*, not judging whether it worked — Agents' observation cascade verifies and resolves the task asynchronously. Don't re-scan locally to second-guess the cascade.

   The verb depends on the user's intent. If the user redirected you mid-edit (e.g. "actually, let's do X instead"), follow the conversation: ask what they want to do, then pick the verb that matches.

   - **You did Agents' suggested change** (the edit matched the `action_description` / `code` snippet) → `update_task_status(task_id="t-1", status="confirm")`. Advances the manual action to `done` so the cascade can pick it up. No reason needed.
   - **You did something different** (alternative code, different resource, fix at a different layer) → `update_task_status(task_id="t-1", status="correct", reason="<what you did instead>")`. Agents records the reason as the dismissed_reason on the task + linked manual action, and emits an `AgentLearning(source=correction)` so the agent learns the user's preferred approach. **Reason is required** — the learning is useless without it.
   - **You and the user decided not to do anything right now, but the task is still valid** (release the claim — someone else, or the user later, might pick it up) → don't call `update_task_status`. Tell the user to open the manual action you created in step 1 from the Agents portal at https://coast.infracost.io and dismiss it there; that releases the claim and leaves the underlying task `open`.
   - **You and the user decided the task isn't worth doing at all** (not now, not later) → that's Path C, not Path A. Call `update_task_status(task_id="t-1", status="dismiss", reason="<why>")`. It also cascade-dismisses the manual action you created in step 1, so you don't need to touch the portal.

   The verb difference matters: `correct` and `dismiss` both end the task as dismissed, but they emit different learning signals (`correction` vs `task_dismissed`). Don't use `correct` for a no-op decline — that mis-trains the agent into thinking the user took an alternative action.

   If you skipped step 1 (no claim), `update_task_status status=confirm` has nothing to advance and is a silent no-op. Don't skip the claim and then assume the report covered it.

6. Report back: what file(s) changed, the before/after diff for the lines you touched, the manual `action_id` you created, and which `update_task_status` verb (if any) you sent. Don't claim Agents verified the fix — the cascade hasn't run yet at the moment you're reporting; the user will see that resolution land asynchronously.

#### Path B — Have Agents draft a PR or ticket

Choose this when **any** of the following hold:

- The task's `code` is empty or too abstract to drop in directly.
- The change touches code or systems you don't have in this repo (e.g. another service, Terraform state already in production, a cloud console action).
- The task's `suggested_action` is `create_ticket` — Agents knows the right ticketing integration to use.
- The user explicitly wants a PR to review rather than a local edit.

How to do it:

1. Draft the action without creating it:

   ```
   preview_fix(finding_id="f-abc", task_id="t-1", type="open_pr")
   ```

   Use `type="create_ticket"` for ticket-shaped tasks. `type="manual"` is not supported by `preview_fix` (the LLM can't draft a manual action) — for those, switch to Path A (where `create_fix(..., type="manual")` is the claim step).

2. **Show the user the draft.** The tool returns `{type, config}`. Surface the relevant fields — for an `open_pr` config that's typically the PR title, target branch, body summary, and files touched; for a `create_ticket` config it's the ticket title, team, description. Do **not** submit anything yet.

3. Ask whether they want to edit anything. Common edits: PR title, target branch, ticket assignee. If they want changes, hold the `config` value and update the relevant fields before passing it to `create_fix`.

4. Only on **explicit confirmation**, submit:

   ```
   create_fix(
     finding_id="f-abc",
     task_id="t-1",
     type="<the type from preview_fix>",
     config=<the (possibly-edited) config from preview_fix>,
   )
   ```

   This is destructive — it creates a real PR or ticket against the connected integration. The MCP host should prompt for confirmation (the tool is marked `destructiveHint`), but that's a backstop, not a substitute for showing the diff yourself.

5. **Agents handles the post-action transitions automatically.** `create_fix` moves the task to `in_progress`; when the PR merges (or the ticket closes), Agents' webhooks advance the action and the observation cascade resolves the task. You don't need to call `update_task_status` after a successful Path B.

   The exception is recovery: if the action ends up in `failed` state (the worker errored opening the PR / creating the ticket), see [Recovering from a failed action](#recovering-from-a-failed-action).

6. Report the new `action_id` and, if Agents surfaced one, the PR URL.

#### Path C — Decline a task or dismiss a finding

Choose this when the user reads the task or finding and decides not to do it: a false positive, a business decision to keep the current config, scope drift, etc. Always ask for a reason — Agents turns the reason into an AgentLearning so the same suggestion doesn't come back on the next scan.

Two scopes:

- **Per-task** — `update_task_status(task_id="t-1", status="dismiss", reason="<why>")`. Dismisses just this task and cascade-dismisses any draft/open actions linked to it. Emits a learning with source `task_dismissed`. Use when only one task on the finding is off-base but the others are still worth doing. **No claim required** — you can dismiss a task without first calling `create_fix(type=manual)`.

  Important: do **not** use `status=correct` for this case. `correct` is for "the user did something different"; `dismiss` is for "the user declined". They feed different learning signals.

- **Per-finding** — `update_finding_status(id="f-abc", status="dismissed", reason="<why>")`. Dismisses the whole finding and cascades dismissal to every task and linked action under it. Emits a learning with source `finding_dismissed`. Use when the entire investigation is off-base.

If the user can't articulate a reason, push back ("would it help to leave it open and revisit later?") rather than dismissing blindly — a dismissal without a reason still flips the status, but the agent learns nothing and may re-raise an equivalent finding on the next scan.

### 6. Loop

After each task, ask whether they want to do another from the same finding, jump to a different finding, or stop. Don't auto-advance — making cost changes is high-stakes and pace matters.

If every task under a finding has been resolved or dismissed, Agents' status-derivation rolls the finding's own status up automatically — you usually don't need to call `update_finding_status` for the resolved case. The explicit call is for dismissals, reopens, or when the user wants to force the state ahead of the cascade.

## Recovering from a failed action

If a Agents action lands in `action_status: failed` — typically a Path B PR worker that hit a 500 trying to push the branch or open the PR — re-fetch the finding to confirm the failure and surface what Agents captured:

```
findings_get(id="f-abc")
```

Look at the action's `result` blob for the error message Agents recorded. If it's transient (rate limit, network blip), offer the retry:

```
retry_action(action_id="a-1")
```

This re-publishes the same action config to the worker queue with no edits. **Don't auto-retry** on first failure — tell the user what failed and only retry on their confirmation. If the failure is structural (bad config, missing integration permission), retrying won't help: surface the message and ask the user how they want to proceed (edit the integration, dismiss the action via the portal, switch to Path A, etc.).

## Choosing between paths

Use the table below as a starting heuristic — but always read the task and ask the user what they want.

| Signal                                                              | Path A (local) | Path B (PR/ticket) | Path C (decline) |
| ------------------------------------------------------------------- | -------------- | ------------------ | ---------------- |
| `code` is a clear diff or replacement snippet                       | ✅              | also OK             |                  |
| `action_description` names a file path you can find                 | ✅              | also OK             |                  |
| Resource address resolves to a file in the user's working dir       | ✅              | also OK             |                  |
| `suggested_action` is `create_ticket`                               | ❌              | ✅ (ticket)         |                  |
| Change is cross-repo or requires cloud console action               | ❌              | ✅ (ticket / manual) |                 |
| Task `code` is empty or vague                                       | ❌              | ✅                  |                  |
| User explicitly wants a PR to review and merge                      | ❌              | ✅ (`open_pr`)      |                  |
| User wants a quick experimental change to validate locally first    | ✅              | ❌                  |                  |
| User reads the task and says "we don't want to do this"             |                |                    | ✅ (per-task)     |
| User reads the finding and says "this whole investigation is off"   |                |                    | ✅ (per-finding)  |

When you're not sure between A and B, **default to Path B**. A Agents-drafted PR is lower-risk than silently editing their files because it leaves a reviewable artifact and a Agents action you can later inspect.

Path C should never be the default — confirm with the user that they're sure they want to decline, and capture a reason for the AgentLearning.

## Presenting results

- **Lead with the dollars.** Always say what the user is saving (per month and annualized) when you've applied or queued a fix.
- **Show before/after for local edits.** Quote the lines you changed; don't just say "edited `main.tf`".
- **Surface the action id (and URL when Agents provides one) for Agents fixes.** The user wants the link to share with their team.
- **Note unresolved tasks.** If a finding has 4 tasks and you've fixed 2, tell the user which 2 remain and the savings on each.
- **Don't promise savings you haven't verified.** Agents' `estimated_monthly_saving` is an estimate; for local fixes, a follow-up `scan` + `inspect_policy_detail` is what confirms the change actually moved the needle.

## Important Guidelines

- **Confirm before destructive actions.** Never call `create_fix` without explicit user confirmation on the specific draft you're about to submit.
- **One task at a time.** Don't batch multiple `create_fix` calls in a single confirmation — each PR / ticket is a separate decision.
- **Don't auto-pick tasks.** Always present options and let the user choose, even when one task obviously dominates the savings — they may have context you don't.
- **Don't fabricate task / finding IDs.** If `findings_list` shows nothing matching, say so — never make up an id to keep the conversation moving.
- **Don't modify the CLI source code** unless the user explicitly asks for it — this skill is for *using* the MCP server.
- **Don't commit auth tokens or env var values** to the user's repository.
- **Don't stash or affect the target repository's git state** beyond the file edits the user agreed to.
