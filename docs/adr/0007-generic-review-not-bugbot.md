# ADR 0007 — Generic APO review is vendor-neutral

Status: **proposed; pending disposer acceptance**

## Decision proposal

No generic APO Phase, PR template or Skill requires posting the vendor-specific `bugbot run` command, waiting for Cursor Bugbot, or granting an exception to the methodology repository itself. The previous [Issue #44](https://github.com/Dylan5237/agent-project-ops/issues/44) discipline is retained as history but superseded for **new generic snapshots following acceptance**.

The disposer still receives an accurate CI/review summary, failed or missing checks, a reference to the version reviewed, and replayable evidence. Project-specific review policies remain enforceable where already approved. A passing reviewer or CI check is never `PHASE ACCEPT`.

## Compatibility

- Existing pinned business repositories are not silently updated.
- Any project that voluntarily requires Bugbot may retain its own review policy outside generic APO; this change does not disable Cursor subscriptions or user-installed tools.
- Acceptance must verify active Playbooks, Skills, PR templates and Getting Started content without relying on the vendor-specific command, preserving PR and evidence separation.

Implementation proposal: #80, PR #83.
