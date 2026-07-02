# Multi-Agent Collaboration Protocol

This directory lets Codex and Claude coordinate in the same repository without using chat as the only handoff channel. GitHub pull requests remain the source of truth for code review and merge state; `.agents/` is for routing, ownership, and lightweight handoffs.

## Startup Checklist

Each agent should read these files before starting work:

1. `.agents/README.md`
2. `.agents/BOARD.md`
3. Its own inbox:
   - Codex reads `.agents/inbox/codex/`
   - Claude reads `.agents/inbox/claude/`
4. Repository rules such as `AGENTS.md`, `README.md`, and relevant task specs.

## Status Values

General task and message statuses:

- `open`: not handled yet
- `claimed`: accepted and being worked on
- `blocked`: waiting on another agent, the user, or an external condition
- `answered`: reply posted, waiting for confirmation or follow-up
- `done`: completed
- `cancelled`: no longer needed

GitHub PR statuses:

- `pr_opened`: PR has been created
- `review_requested`: another agent has been asked to review
- `changes_requested`: reviewer requested changes on the PR
- `comments_posted`: reviewer left PR comments
- `approved`: reviewer approved the PR
- `merged`: PR has been merged

## Message Format

Use one Markdown file per message. Put it in the recipient's inbox.

Suggested filename:

```text
YYYYMMDD-HHMM-from-to-short-topic.md
```

Template:

```markdown
---
id: msg-YYYYMMDD-HHMM-short-topic
from: Codex
to: Claude
task: task-short-name
status: open
priority: normal
created: YYYY-MM-DDTHH:MM:SS-07:00
branch:
pr:
files:
  - path/to/file
---

Context:

Request:

Completed:

Notes:
```

## Claiming Work

Before taking ownership of a task:

1. Update the message or `.agents/BOARD.md` row to `claimed`.
2. Create a claim file in `.agents/claims/`.

Suggested claim filename:

```text
task-short-name.codex.claim
task-short-name.claude.claim
```

Claim template:

```markdown
---
task: task-short-name
owner: Codex
status: claimed
created: YYYY-MM-DDTHH:MM:SS-07:00
---

Scope:
- Work being handled

Files:
- Files expected to change
```

## Collaboration Rules

1. Do not overwrite another agent's conclusion directly. If you disagree, write a new message with the reasoning.
2. Before editing shared files, check `.agents/claims/` for active ownership.
3. Update `.agents/BOARD.md` after each meaningful milestone.
4. If blocked, set the status to `blocked` and state exactly what is needed.
5. End every work session with a handoff: what changed, what did not change, validation results, and the next suggested owner.

## GitHub PR Workflow

When Codex and Claude collaborate in a GitHub repository, code review and merge decisions happen on GitHub. Use `.agents/` to notify the other agent that GitHub state has changed.

Recommended flow:

1. The author agent branches from the latest default branch or the task branch required by the repository.
2. The author agent implements the scoped change, commits it, pushes the branch, and opens a PR.
3. The author agent updates `.agents/BOARD.md` to `pr_opened` or `review_requested`, including the branch and PR URL.
4. The author agent writes a review-request message to the reviewer inbox. The message must include the PR URL, branch, commit, validation results, and files needing special attention.
5. The reviewer agent reviews the PR on GitHub. Review comments must be posted on the PR, not only in `.agents/`.
6. After posting PR comments, the reviewer agent writes a message to the author inbox with `comments_posted` or `changes_requested` and the PR URL.
7. The author agent addresses PR comments on the same branch, replies on GitHub where useful, pushes follow-up commits, and notifies the reviewer through inbox.
8. When the reviewer believes the PR is ready, the reviewer approves it on GitHub and updates `.agents/BOARD.md` to `approved`.
9. If all merge gates pass, the reviewer may merge the PR and update `.agents/BOARD.md` to `merged`.

## PR Approval And Merge Gates

The reviewer agent may approve and merge only when all of these are true:

1. The PR was authored by the other agent. Do not self-approve or self-merge unless the user explicitly overrides the rule.
2. There are no unresolved blocking comments or requested changes on GitHub.
3. Required CI/checks have passed, or repository rules explicitly allow merging without CI.
4. The PR branch has no conflict with the target branch.
5. `.agents/BOARD.md` has no `blocked` row for the same task.
6. The user has not requested review-only behavior.
7. The merge method follows repository convention: merge commit, squash merge, or rebase merge.
8. Repository-specific rules in `AGENTS.md` and task specs are satisfied.

After merging, the merge owner must:

1. Update `.agents/BOARD.md` to `merged`.
2. Write a completion message to the author inbox.
3. Record the PR URL, merge commit or final commit, and CI result in the handoff section.

## PR Message Templates

Review request:

```markdown
---
id: msg-YYYYMMDD-HHMM-review-request
from: Codex
to: Claude
task: task-short-name
status: review_requested
priority: normal
created: YYYY-MM-DDTHH:MM:SS-07:00
branch: feature/task-short-name
pr: https://github.com/owner/repo/pull/123
files:
  - path/to/file
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
id: msg-YYYYMMDD-HHMM-pr-comments
from: Claude
to: Codex
task: task-short-name
status: comments_posted
priority: normal
created: YYYY-MM-DDTHH:MM:SS-07:00
branch: feature/task-short-name
pr: https://github.com/owner/repo/pull/123
files:
  - path/to/file
---

I left PR review comments:

- PR:
- Result: changes requested / non-blocking comments / approved
- Author next step:
```

Merged:

```markdown
---
id: msg-YYYYMMDD-HHMM-pr-merged
from: Claude
to: Codex
task: task-short-name
status: merged
priority: normal
created: YYYY-MM-DDTHH:MM:SS-07:00
branch: feature/task-short-name
pr: https://github.com/owner/repo/pull/123
files:
  - path/to/file
---

PR approved and merged:

- PR:
- Merge commit:
- Checks:
- Cleanup:
```

## Checkpoints

Agents should check this directory at these moments:

- before starting work
- before editing shared files
- after opening a PR
- after posting PR comments
- after approving or merging a PR
- after a failed validation run or blocker
- after finishing a milestone
- before ending the session
