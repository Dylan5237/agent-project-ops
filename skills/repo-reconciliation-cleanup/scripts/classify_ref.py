#!/usr/bin/env python3
"""Classify REF vs TIP using git rev-list --left-right --count.

Exit 0 always when git works; prints one line:
  KIND ahead=<n> behind=<n> tip=<sha> ref=<sha>

KIND in {SAME, ANCESTOR, AHEAD, DIVERGED}.
Does not decide delete/keep — that remains a disposer/AI decision.
"""
from __future__ import annotations

import argparse
import subprocess
import sys


def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip() or f"fail: {cmd}")
    return p.stdout.strip()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tip", required=True, help="Authority tip ref (e.g. origin/main)")
    ap.add_argument("--ref", required=True, help="Branch/worktree/commit to classify")
    ap.add_argument("--cwd", default=".", help="Git repo working directory")
    args = ap.parse_args()
    tip_sha = run(["git", "-C", args.cwd, "rev-parse", args.tip])
    ref_sha = run(["git", "-C", args.cwd, "rev-parse", args.ref])
    counts = run(
        ["git", "-C", args.cwd, "rev-list", "--left-right", "--count", f"{tip_sha}...{ref_sha}"]
    )
    # left = tip-only (= behind from ref's view), right = ref-only (= ahead)
    left_s, right_s = counts.split()
    behind, ahead = int(left_s), int(right_s)
    if ahead == 0 and behind == 0:
        kind = "SAME"
    elif ahead == 0 and behind > 0:
        kind = "ANCESTOR"
    elif ahead > 0 and behind == 0:
        kind = "AHEAD"
    else:
        kind = "DIVERGED"
    print(f"KIND={kind} ahead={ahead} behind={behind} tip={tip_sha[:12]} ref={ref_sha[:12]}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"ERROR {e}", file=sys.stderr)
        raise SystemExit(2)
