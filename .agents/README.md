# Multi-Agent Collaboration Protocol

This file defines the local handoff protocol for Codex and Claude in this repository.

GitHub remains the source of truth for PR review, comments, checks, and merge state. `tasks/README.md` remains the project task board. The `.agents/` runtime mailbox is only a same-machine notification channel, not project history.

## Startup Checklist

Each agent should read these files before starting work:

1. `AGENTS.md`
2. `tasks/README.md`
3. `.agents/README.md`
4. Its own local inbox, if present:
   - Codex reads `.agents/inbox/codex/new/`
   - Claude reads `.agents/inbox/claude/new/`

Create local runtime directories when needed:

```sh
mkdir -p .agents/inbox/codex/{new,wip,done} \
  .agents/inbox/claude/{new,wip,done} \
  .agents/claims
```

The runtime directories are ignored by git:

```text
.agents/inbox/
.agents/claims/
```

Do not commit mailbox messages, claims, or runtime handoff files. They are ephemeral coordination on one machine.

## Mailbox Flow

Use one Markdown file per message. Put it in the recipient's local `new/` inbox.

Suggested filename:

```text
YYYYMMDD-HHMM-from-to-short-topic.md
```

Minimum message template:

```markdown
---
from: Codex
to: Claude
task: task-short-name
pr: https://github.com/owner/repo/pull/123
---

Context:

Request:

Completed:

Notes:
```

Message state is represented by directory moves:

- `new/`: not handled yet
- `wip/`: claimed and being handled
- `done/`: handled or no longer needed

When an agent starts handling a message, it moves the file from `new/` to `wip/`. When finished, it moves the file to `done/`. Directory moves are used instead of frontmatter edits so status changes are atomic and easy to inspect with `ls`.

## Claims

Before editing shared files, check `.agents/claims/` for active ownership. If a task needs a temporary lock, create a local claim file:

```text
.agents/claims/task-short-name.codex.claim
.agents/claims/task-short-name.claude.claim
```

Claim template:

```markdown
---
task: task-short-name
owner: Codex
created: YYYY-MM-DDTHH:MM:SS-07:00
---

Scope:
- Work being handled

Files:
- Files expected to change
```

Remove or move the claim when the work is handed off or complete.

## GitHub PR Notification Choreography

Follow `AGENTS.md` for branch names, task scope, PR titles, review rules, and merge rules. This protocol only adds mailbox notifications around GitHub events.

Recommended flow:

1. The author agent implements the scoped task, pushes the branch, and opens a PR according to `AGENTS.md`.
2. The author agent writes a review-request message to the reviewer inbox. Include the PR URL, branch, commit, validation results, and files needing special attention.
3. The reviewer agent reviews on GitHub. Review comments and verdicts belong on the PR.
4. After commenting on GitHub, the reviewer agent writes a local inbox message to the author with the PR URL and a short result: `changes requested`, `non-blocking comments`, or `ready`.
5. The author agent addresses PR comments on the same branch, replies on GitHub where useful, pushes follow-up commits, and notifies the reviewer through inbox.
6. After merge, the agent that observed or performed the merge writes a local completion message with the PR URL, final commit, and check result.

Because both agents may operate through the same GitHub account on this machine, do not treat a formal GitHub approval as required when it is technically unavailable. Use the PR comment verdict required by `AGENTS.md` and the owner override rules in that file.

## Message Templates

Review request:

```markdown
---
from: Codex
to: Claude
task: task-short-name
pr: https://github.com/owner/repo/pull/123
---

Review request:

- PR:
- Branch:
- Commit:
- Validation:
- Focus areas:
```

Comments posted:

```markdown
---
from: Claude
to: Codex
task: task-short-name
pr: https://github.com/owner/repo/pull/123
---

I left PR review comments:

- PR:
- Result: changes requested / non-blocking comments / ready
- Author next step:
```

Merged:

```markdown
---
from: Claude
to: Codex
task: task-short-name
pr: https://github.com/owner/repo/pull/123
---

PR merged:

- PR:
- Final commit:
- Checks:
- Cleanup:
```

## Trigger Mechanism

While a session is active, each agent should watch its own `new/` inbox:

- Claude can use its harness monitor or a file watcher on `.agents/inbox/claude/new/`.
- Codex can use a local watch loop around the relevant runner for `.agents/inbox/codex/new/`.

Checkpoint reads are still required as a fallback:

- before starting work
- before editing shared files
- after opening a PR
- after posting PR comments
- after pushing follow-up commits
- after a failed validation run or blocker
- after finishing a milestone
- before ending the session

Between active sessions, the user should only need to start the relevant agent. The user should not need to relay message contents.
