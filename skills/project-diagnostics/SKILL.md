---
name: project-diagnostics
description: >
  Inspect an APO project's pinned binding, origin remote classification,
  local Git hook and unknown protection guarantees without mutating anything.
  Use before unsafe writes, after a fresh clone, or when project status appears inconsistent.
---

# APO project diagnostics (read-only)

Load root `AGENTS.md` and pinned `PRINCIPLES.md`, then run:

```bash
bash .agent-project-ops/skills/project-diagnostics/scripts/doctor.sh --dir .
```

When operating in the methodology repository itself, use
`bash skills/project-diagnostics/scripts/doctor.sh --dir .`.

The script **only reads local state**. It does not fetch, push, commit, install
hooks, repair configuration, or infer that a green result means release/Accept.
Its tab-separated results have `PASS`, `FAIL`, `WARN`, or `UNKNOWN`,
a stable reason code and a human-readable explanation.

- `FAIL`: do not perform the affected write; show the cause and safest next step.
- `WARN`: observed weakness (e.g., fresh-clone hook inactive). Explain the
  impact and recommend the repository's existing installer; do not run it
  without appropriate user authorization.
- `UNKNOWN`: no local evidence for a live GitHub control, CI state or actual
  user approval. Use read-only GitHub calls or ask the disposer; **never** mark
  it PASS merely because another check passed.
- `PASS`: only the named local condition was observed, not overall safety.

A tool that reports A/B/C or independent reviewer guarantees must inspect
the server's actual policy and identity context. This local doctor does not.
A task base/PR status is not inferred from `origin/main` by default.

For a creator-facing "continue" or "check the result" request, pair this
diagnostic with `apo-project-assistant` and the Command Center/Phase evidence;
do not create a second database or substitute the report for `PHASE ACCEPT`.
