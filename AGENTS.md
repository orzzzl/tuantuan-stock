# AGENTS.md — Working agreement for the implementer

This file defines how to work in this repo. **Claude** (the architect) owns architecture,
design, and review; the **implementer** owns turning task specs into code.

This is a personal, for-fun project: a cute US-stock **price viewer** (look only, never trade).
It reuses the visual language and "mascot mood = your state" soul of the sister project `nudge`.

## Your role

You implement well-scoped task specs from `tasks/`. You do **not** make architectural
decisions, add dependencies, or change public interfaces on your own — if a task seems to
require that, stop and leave a note in the PR instead of guessing.

## Workflow

1. Pick the task file in `tasks/` whose status is `READY` (see `tasks/README.md`).
2. Create a branch: `task/<id>-<short-slug>` (e.g. `task/04-quote-domain`).
3. Implement **only what the task spec asks**. Keep the diff minimal and focused.
4. Run the checks in "Definition of done" below. They must pass.
5. Open a PR. The title MUST start with an author tag — `[codex]`, `[claude]`, or
   `[antigravity]`, naming the agent that wrote it. In the description, link the task
   file and fill the PR checklist.
6. **Every PR must be reviewed before merge — no exceptions, no self-merge.** Cross-
   review: every PR is reviewed by a DIFFERENT agent than its author. Default pairing
   is Codex↔Claude; Antigravity (Gemini) is an equal reviewer — route reviews to it
   (mailbox `~/agents/inbox/antigravity/new/`) when the default reviewer is out of
   quota or unresponsive. The owner can always override or add review. Address review
   comments on the same branch; merge only after an explicit approval.
7. **Agent-to-agent notifications go through the machine-level mailbox** at
   `~/agents/` (spec: `~/agents/PROTOCOL.md`) — e.g. "PR #N is ready for your
   review". Review content itself stays on the GitHub PR. Never commit mailbox
   material into this repository.

## Hard rules (do not violate)

- **Comments and identifiers in English.** All docs in this repo are English. User-facing
  strings go through i18n (ARB), never hard-coded. No Chinese in hand-written code except
  inside `*.arb` translation files.
- **Look-only product.** No order placement, no brokerage account, no portfolio P&L, no
  trading anything. The app fetches and displays quotes. That is the whole scope.
- **Respect the architecture seams.** Depend on interfaces in `lib/domain`, never on concrete
  implementations across layers. The seams: `QuoteRepository`, `WatchlistRepository`,
  `SearchRepository`. Swapping the data provider must touch only `lib/data`.
- **No new dependencies** without an explicit OK written in the task spec.
- **No account, no analytics SDK.** Local-first: the watchlist lives on-device. The only
  network calls are read-only quote/search requests to the configured market-data provider.
- **Keep secrets out of git.** The data-provider API key is read from a build-time
  environment / `--dart-define`, never committed.
- Keep functions small; match the style of surrounding code; no dead code or commented-out
  blocks.

## Definition of done (every PR)

- [ ] `dart format .` produces no changes
- [ ] `flutter analyze` reports no errors or new warnings
- [ ] `flutter test` passes (add/adjust tests for the code you touched)
- [ ] The task's own acceptance criteria are all met
- [ ] No hard-coded user-facing strings; no Chinese outside `*.arb`
- [ ] Diff is scoped to the task; no drive-by refactors

## When in doubt

Stop and write your question in the PR description (or as a `// TODO(claude): ...` comment)
rather than inventing behavior. A small, correct, scoped PR beats a large speculative one.
