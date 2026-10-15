# Playbook: Staff and dispatch / 编制与分派

## Goal

Make it obvious **who proposes**, **who disposes**, and **which Agent owns which working directory** (the primary checkout or a worktree), without a second product or a shop-floor bot.

## When

- Starting a project (after Command Center exists).
- Adding a second local Agent or a human reviewer.
- A task is ready to leave `backlog`.

## Preconditions

- Command Center issue exists.
- Labels from `templates/labels.md` exist.
- A single task runs on the idle primary checkout; each additional concurrent task gets its own worktree, at most `max_worktrees` folders (default 3) (Principle 8).

## Steps

1. **Name the disposer** on Command Center (human GitHub handle, or a single explicit control-plane owner). This person/role Freeze-ACKs and PHASE ACCEPTs.
2. **Name the project-ops Agent** (often the local coding Agent). It keeps Issues honest, proposes transitions, and refuses illegal shortcuts. It still **proposes**. **Mandatory duty:** on every gate flip / phase status / Freeze / blocked / verification, update Command Center **section 1** in the same turn. Update the Phase status label only when the Phase status actually changes (Freeze ACK is not a label change). Chat only pings humans to look at GitHub. If CC cannot be updated → `BLOCKED:` on GitHub, not chat-only. [ ] **CC §1 updated**
3. **Roster table** on Command Center:

   | Role | Handle / Agent id | May merge? | May Accept phase? |
   | --- | --- | --- | --- |
   | Disposer | | policy | yes |
   | Implementer Agent | | no (unless named) | no |
   | Reviewer | | optional | no |

4. **Dispatch a task:**
   - Pick one Issue (Phase or child). One core problem.
   - Run `new-worktree.sh` per git playbooks. It retires finished work first, then puts the task on the idle primary checkout or a new worktree. **Exit 3** = folder cap reached, nothing created: leave the Issue `status:backlog`, comment `QUEUED: folder cap (n/max)`, and dispatch it when a running task merges or is parked.
   - Comment `@owner START` with: issue number, branch name, working directory (the `workdir:` / `worktree:` line), Freeze status.
   - Set `status:in-progress`. Assign the GitHub issue if the host is used.
   - Update Command Center §1 (current phase, status word, **single Next Action**). [ ] **CC §1 updated**
5. **Handoff:** if another Agent continues, commit and push first (never stash; never leave mystery dirty trees), then comment `HANDOFF to <id>` with branch, working directory and head SHA. If the next Agent works in a different place, `tidy-worktrees.sh --park <branch>` releases the folder and it resumes with `new-worktree.sh` (same issue, slug and kind; the owner may change).
6. **Recall:** if scope drifts, disposer comments `STOP` or `RETURN TO BACKLOG`. Agent commits and pushes, parks with `tidy-worktrees.sh --park <branch>` (branch kept, folder released), sets `status:backlog` or `blocked`, and updates CC §1. If the disposer abandons the task instead, close its PR and run `tidy-worktrees.sh --abandon <branch>` (archive tag first, then delete). [ ] **CC §1 updated**
7. **Parallelism:** the first task may use the idle primary checkout; every further concurrent task gets its own worktree, at most `max_worktrees` folders. Never stack two tasks in one directory. More tasks than slots ⇒ queue (step 4), never bypass the cap.
8. **After merge or close:** run `tidy-worktrees.sh --apply` and put its `apo-tidy:` line in the status report. Anything it keeps is listed with a reason; resolve `stale` entries or name their owner.

## Done when

- [ ] Command Center roster is complete.
- [ ] Every `in-progress` issue names an owner in the last dispatch comment.
- [ ] **CC §1 updated** after dispatch, handoff, recall, or status change (or `BLOCKED:` on GitHub if CC cannot be edited).
- [ ] No two in-progress tasks share a working directory, and worktree folders ≤ `max_worktrees`.
- [ ] The latest status report carries an `apo-tidy:` line with `failed=0`.
- [ ] Agents can answer “who Accepts?” from the Command Center body alone.

## Anti-patterns

- “Everyone owns it” (nobody disposes).
- One worktree, two Agents, two features.
- Getting past the folder cap by deleting another task's folder or raising `max_worktrees` mid-dispatch.
- Dispatch via chat only; Issue stays `backlog`.
- Treating CC §1 refresh as the human’s habit instead of the project-ops Agent’s duty.
- Implementer Agent self-Accepting because “I am the project owner.”
- Staffing a Notion workflow or Grok bot as part of this methodology (out of scope).
