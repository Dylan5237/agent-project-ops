#!/usr/bin/env python3
"""Prepare a three-way APO rules upgrade patch. Never modifies the target project.

Run from a trusted, clean methodology clone (history must contain the old PIN).
Only known bootstrap-owned files may change. Project GitHub state is reconciled
separately by the user/Agent after reviewing the resulting task-branch diff.
"""
from __future__ import annotations

import argparse
import dataclasses
import difflib
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from typing import Optional
from urllib.parse import urlsplit

STAMP = "__APO_UPGRADE_TIME__"
# Legacy descriptors are intentionally retained: render(old PIN) needs them to
# remove unmodified retired bindings and restore them with the reverse patch.
# render(new) emits only files actually present in the selected source tree.
ROOT_FILES = {"AGENTS.md", "CLAUDE.md", ".gitignore", ".gitattributes", ".aider.conf.yml",
              ".github/CODEOWNERS", ".github/copilot-instructions.md",
              ".cursor/rules/agent-project-ops.mdc", ".continue/rules/agent-project-ops.md",
              ".githooks/pre-push"}
PREFIXES = (".agent-project-ops/", ".agents/skills/", ".claude/skills/", ".codebuddy/skills/",
            ".github/ISSUE_TEMPLATE/", ".github/PULL_REQUEST_TEMPLATE/")
SCRIPT_FILES = ("new-worktree.sh", "tidy-worktrees.sh", "install-hooks.sh", "share-export.sh", "export-sync.sh",
                "scan-inverted-sot.py", "project-settings.py", "lib/url-guard.sh",
                "lib/share-export-denylist.sh", "lib/export-strip-list.sh")

INDEX_MODES: dict[str, int] = {}

_settings_spec = importlib.util.spec_from_file_location("apo_project_settings", Path(__file__).with_name("project-settings.py"))
settings_helper = importlib.util.module_from_spec(_settings_spec)
_settings_spec.loader.exec_module(settings_helper)

class Stop(Exception):
    pass

@dataclasses.dataclass(frozen=True)
class File:
    data: bytes
    mode: int = 0o644

    def digest(self) -> str:
        return hashlib.sha256(self.data).hexdigest()


def run(args: list[str], cwd: Optional[Path] = None, data: Optional[bytes] = None,
        check: bool = True) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    for key in list(env):
        if key.startswith("GIT_"):
            env.pop(key)
    env.update(GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0", LC_ALL="C")
    result = subprocess.run(args, cwd=cwd, input=data, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env=env, timeout=120)
    if check and result.returncode:
        raise Stop("COMMAND_FAILED: " + " ".join(args[:3]) + ": " +
                   result.stderr.decode("utf-8", "replace").strip())
    return result


def git(root: Path, *args: str, check: bool = True) -> bytes:
    return run(["git", "-c", "core.fsmonitor=false", "-C", str(root), *args], check=check).stdout


def canonical_url(value: str) -> str:
    value = value.strip().removesuffix(".git")
    scp = re.fullmatch(r"(?:[^/@]+@)?([^/:]+):(.+)", value)
    if scp and "://" not in value and not re.match(r"^[A-Za-z]:", value):
        return scp[1].lower() + "/" + scp[2].lstrip("/")
    parsed = urlsplit(value)
    if parsed.scheme in ("https", "http", "ssh") and parsed.hostname:
        if parsed.query or parsed.fragment:
            raise Stop("SOURCE_URL_UNSAFE")
        return parsed.hostname.lower() + "/" + parsed.path.lstrip("/")
    return value


def github_repository(value: str) -> tuple[str, str]:
    """Parse one effective GitHub origin URL without accepting transport options."""
    patterns = (
        r"https://github\.com/([^/]+)/([^/]+)/?",
        r"ssh://git@github\.com/([^/]+)/([^/]+)/?",
        r"git@github\.com:([^/]+)/([^/]+)/?",
    )
    owner = repo = ""
    for pattern in patterns:
        match = re.fullmatch(pattern, value, re.IGNORECASE | re.ASCII)
        if match:
            owner, repo = match.groups()
            break
    else:
        raise Stop("ORIGIN_URL_UNSAFE")
    if repo.lower().endswith(".git"):
        repo = repo[:-4]
    component = r"[A-Za-z0-9_.-]+"
    if (not re.fullmatch(component, owner) or owner in (".", "..") or
            not re.fullmatch(component, repo) or repo in (".", "..")):
        raise Stop("ORIGIN_URL_UNSAFE")
    return owner.lower(), repo.lower()


def validate_origin_urls(root: Path) -> tuple[str, str]:
    """Require every expanded origin fetch/push URL to name the same GitHub repo."""
    fetch = run(["git", "-c", "core.fsmonitor=false", "-C", str(root),
                 "remote", "get-url", "--all", "origin"], check=False)
    if fetch.returncode:
        raise Stop("ORIGIN_REMOTE_MISSING")
    push = run(["git", "-c", "core.fsmonitor=false", "-C", str(root),
                "remote", "get-url", "--push", "--all", "origin"], check=False)
    if push.returncode:
        raise Stop("ORIGIN_URL_UNSAFE")
    try:
        fetch_urls = fetch.stdout.decode("utf-8", "strict").splitlines()
        push_urls = push.stdout.decode("utf-8", "strict").splitlines()
        urls = fetch_urls + push_urls
        if (not fetch_urls or not push_urls or
                any(not value for value in urls)):
            raise Stop("ORIGIN_URL_UNSAFE")
        # get-url prints one expanded URL per line. Cross-check raw config
        # entry counts so an embedded newline cannot masquerade as multiple
        # otherwise valid URLs.
        def config_count(key: str) -> int:
            result = run(["git", "-c", "core.fsmonitor=false", "-C", str(root),
                          "config", "--null", "--get-all", key], check=False)
            if result.returncode:
                return 0
            values = result.stdout.split(b"\0")
            if values and values[-1] == b"":
                values.pop()
            return len(values)

        fetch_count = config_count("remote.origin.url")
        push_count = config_count("remote.origin.pushurl")
        if (not fetch_count or len(fetch_urls) != fetch_count or
                len(push_urls) != (push_count or fetch_count)):
            raise Stop("ORIGIN_URL_UNSAFE")
        repositories = {github_repository(value) for value in urls}
    except (UnicodeError, Stop):
        raise Stop("ORIGIN_URL_UNSAFE") from None
    if len(repositories) != 1:
        raise Stop("ORIGIN_URL_MISMATCH")
    return next(iter(repositories))


def sha_ok(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", value))


def safe_rel(value: str) -> str:
    p = PurePosixPath(value)
    if not value or p.is_absolute() or "\\" in value or ":" in value or any(
            part in ("", ".", "..") for part in value.split("/")):
        raise Stop("UNSAFE_PATH: " + value)
    if value not in ROOT_FILES and not value.startswith(PREFIXES):
        raise Stop("UNOWNED_PATH: " + value)
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", value):
        raise Stop("PATCH_PATH_UNSUPPORTED: " + value)
    return value


def target_path(root: Path, name: str) -> Path:
    safe_rel(name)
    p = root
    for part in name.split("/"):
        p = p / part
        if p.is_symlink():
            raise Stop("SYMLINK_REFUSED: " + name)
    if p.exists() and not p.is_file():
        raise Stop("NON_FILE_REFUSED: " + name)
    return p


def read_target(root: Path, name: str) -> Optional[File]:
    p = target_path(root, name)
    if not p.exists():
        return None
    if p.stat().st_size > 8 * 1024 * 1024:
        raise Stop("FILE_TOO_LARGE: " + name)
    return File(p.read_bytes(), INDEX_MODES.get(str(p), 0o755 if p.stat().st_mode & 0o111 else 0o644))


def kv(raw: bytes) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in raw.decode("utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            raise Stop("INVALID_BINDING_LINE")
        k, v = line.split("=", 1)
        if k in result:
            raise Stop("DUPLICATE_BINDING_KEY: " + k)
        result[k] = v
    return result


class Source:
    def __init__(self, root: Path, ref: str, clean: bool = False):
        self.root = root.resolve()
        actual = Path(git(self.root, "rev-parse", "--show-toplevel").decode().strip()).resolve()
        if actual != self.root:
            raise Stop("SOURCE_NOT_METHODOLOGY_ROOT: use a separate methodology Git clone")
        if clean and git(self.root, "status", "--porcelain", "--untracked-files=all").strip():
            raise Stop("SOURCE_DIRTY: commit/stash source changes yourself before upgrading")
        self.sha = git(self.root, "rev-parse", "--verify", ref + "^{commit}").decode().strip()
        if not sha_ok(self.sha):
            raise Stop("SOURCE_SHA_INVALID")
        rows = git(self.root, "ls-tree", "-rz", "--full-tree", self.sha)
        self.files: dict[str, tuple[str, str]] = {}
        self.cache: dict[str, File] = {}
        for row in rows.split(b"\0"):
            if not row:
                continue
            meta, path = row.split(b"\t", 1)
            mode, kind, obj = meta.decode().split()
            if kind == "blob":
                self.files[path.decode("utf-8")] = (mode, obj)
        for required in ("PRINCIPLES.md", "scripts/bootstrap-project.sh", "templates/AGENTS.md"):
            if required not in self.files:
                raise Stop("SOURCE_LAYOUT_UNSUPPORTED: " + required)

    def get(self, name: str) -> File:
        if name not in self.cache:
            mode, obj = self.files[name]
            if mode not in ("100644", "100755"):
                raise Stop("SOURCE_SPECIAL_FILE: " + name)
            raw = git(self.root, "cat-file", "blob", obj)
            self.cache[name] = File(raw, 0o755 if mode == "100755" else 0o644)
        return self.cache[name]


def render_legacy(source: Source, values: dict[str, str]) -> dict[str, File]:
    """Known v0.1.x/v0.2 bootstrap layout, reconstructed without executing it."""
    out: dict[str, File] = {}
    def put(src: str, dest: str, subst: bool = False, executable: bool = False):
        f = source.get(src)
        raw = f.data
        if subst:
            text = raw.decode("utf-8")
            for key, value in values.items():
                text = text.replace("{{" + key + "}}", value)
            raw = text.encode("utf-8")
        out[dest] = File(raw, 0o755 if executable else f.mode)

    for path in source.files:
        if path in ("PRINCIPLES.md", "LICENSE") or path.startswith(("playbooks/", "skills/", "templates/")):
            put(path, ".agent-project-ops/" + path)
    for name in SCRIPT_FILES:
        path = "scripts/" + name
        if path in source.files:
            put(path, ".agent-project-ops/" + path, executable="/" not in name)
    bridges = {
        "templates/AGENTS.md": "AGENTS.md", "templates/CLAUDE.md": "CLAUDE.md",
        "templates/cursor-rules/agent-project-ops.mdc": ".cursor/rules/agent-project-ops.mdc",
        "templates/github/copilot-instructions.md": ".github/copilot-instructions.md",
        "templates/github/CODEOWNERS": ".github/CODEOWNERS",
        "templates/gitignore-agent-ops": ".gitignore",
        "templates/gitattributes-agent-ops": ".gitattributes",
        "templates/aider.conf.yml": ".aider.conf.yml",
        "templates/continue-rules/agent-project-ops.md": ".continue/rules/agent-project-ops.md",
        "scripts/hooks/pre-push-authority.sh": ".githooks/pre-push",
    }
    for src, dest in bridges.items():
        if src in source.files:
            put(src, dest, subst=dest in ("AGENTS.md", ".github/CODEOWNERS"), executable=dest==".githooks/pre-push")
    script = source.get("scripts/bootstrap-project.sh").data.decode("utf-8")
    cc_rendered = 'subst "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/command-center.md"' in script
    for path in source.files:
        if path.startswith(("templates/ISSUE_TEMPLATE/", "templates/PULL_REQUEST_TEMPLATE/")) and path.endswith(".md"):
            put(path, ".github/" + path[len("templates/"):], subst=cc_rendered and path.endswith("/command-center.md"))
        if re.fullmatch(r"skills/[^/]+/SKILL\.md", path):
            name = path.split("/")[1]
            text = source.get(path).data.decode("utf-8")
            fm = re.match(r"\A---[^\n]*\n.*?^---\s*$", text, re.M | re.S)
            if not fm:
                raise Stop("INVALID_SKILL_FRONTMATTER: " + path)
            frontmatter = fm.group(0).rstrip("\n")
            wrapper = (frontmatter + "\n\n# " + name + " (pinned wrapper)\n\n"
                       "Follow the full pinned skill at [../../../.agent-project-ops/skills/" + name +
                       "/SKILL.md](../../../.agent-project-ops/skills/" + name + "/SKILL.md).\n\n"
                       "Do not invent a parallel process. `.agent-project-ops/PRINCIPLES.md` wins.\n")
            for prefix in (".agents/skills/", ".claude/skills/"):
                out[prefix + name + "/SKILL.md"] = File(wrapper.encode())
    return out


def render(source: Source, values: dict[str, str]) -> dict[str, File]:
    """Versioned layout dispatch; never change the historical reconstruction."""
    out = render_legacy(source, values)
    descriptor = "templates/project-options.json"
    if descriptor not in source.files:
        return out
    data = json.loads(source.get(descriptor).data)
    if data.get("layout_version") != 1:
        raise Stop("SOURCE_LAYOUT_UNSUPPORTED: project options")
    try:
        selected = settings_helper.normalize(data, *(values[k.upper()] for k in settings_helper.KEYS))
    except KeyError as exc:
        raise Stop("PROJECT_SETTINGS_REQUIRED: explicitly select all three project settings") from exc
    for key, item in data["agent_tools"].items():
        prefix = item["skills_dir"] + "/"
        if prefix == ".agents/skills/":
            continue
        for path in list(out):
            if path.startswith(prefix):
                del out[path]
        if key in selected["agent_tools"].split(","):
            for path, file in list(out.items()):
                if path.startswith(".agents/skills/"):
                    out[prefix + path[len(".agents/skills/"):]] = file
    for key, item in data["external_tools"].items():
        if key in selected["external_tools"].split(","):
            out[".agent-project-ops/integrations/" + item["guide"]] = source.get("integrations/" + item["guide"])
    out[".agent-project-ops/project-config"] = File(values.get("PROJECT_CONFIG", settings_helper.settings_text(selected)).encode())
    return out


def project_choices(root: Path, source: Source, explicit: dict[str, str]) -> tuple[dict[str, str], bytes, bytes]:
    descriptor = "templates/project-options.json"
    if descriptor not in source.files:
        if explicit:
            raise Stop("SOURCE_LAYOUT_UNSUPPORTED: project choices")
        return {}, b"", b""
    data = json.loads(source.get(descriptor).data)
    if data.get("layout_version") != 1:
        raise Stop("SOURCE_LAYOUT_UNSUPPORTED: project options")
    config = read_target(root, ".agent-project-ops/project-config")
    before = config.data if config else b""
    values = settings_helper.config_values(before.decode("utf-8"), strict=False)
    present = [key in values for key in settings_helper.KEYS]
    if any(present) and not all(present):
        raise Stop("PROJECT_SETTINGS_PARTIAL: review all three choices together")
    if all(present):
        selected = settings_helper.normalize(data, *(values[k] for k in settings_helper.KEYS))
        if explicit and settings_helper.normalize(data, *(explicit.get(k, "") for k in settings_helper.KEYS)) != selected:
            raise Stop("PROJECT_SETTINGS_CONFLICT: review settings on a project task first")
        return selected, before, before
    if set(explicit) != set(settings_helper.KEYS):
        raise Stop("PROJECT_SETTINGS_REQUIRED: provide --process-mode, --agent-tools and --external-tools")
    selected = settings_helper.normalize(data, *(explicit[k] for k in settings_helper.KEYS))
    after = before + (b"\n" if before and not before.endswith(b"\n") else b"") + settings_helper.settings_text(selected).encode()
    return selected, before, after


def same(a: Optional[File], b: Optional[File], *, legacy_filemode: bool = False) -> bool:
    if a is None or b is None:
        return a is b
    # Windows Git with core.filemode=false cannot reliably preserve the
    # executable bit written by the old Bash bootstrap. Accept *only* this
    # known 0644/0755 mode drift for owned snapshot files; content must still
    # match byte-for-byte apart from CRLF normalization.
    mode_matches = a.mode == b.mode or (
        legacy_filemode and {a.mode, b.mode} == {0o644, 0o755}
    )
    return mode_matches and a.data.replace(b"\r\n", b"\n") == b.data.replace(b"\r\n", b"\n")


def merge_text(local: File, old: File, new: File, name: str) -> File:
    if b"\0" in local.data + old.data + new.data:
        raise Stop("BINARY_CONFLICT: " + name)
    # Preserve clearly appended/prepended project sections even when Git's
    # line-level merge would conflate them with changed template end lines.
    left = local.data.replace(b"\r\n", b"\n")
    base = old.data.replace(b"\r\n", b"\n")
    right = new.data.replace(b"\r\n", b"\n")
    if base and left.startswith(base):
        return File(right + left[len(base):], local.mode)
    if base and left.endswith(base):
        return File(left[:-len(base)] + right, local.mode)
    with tempfile.TemporaryDirectory(prefix="apo-merge-") as d:
        paths = [Path(d) / n for n in ("local", "old", "new")]
        for p, raw in zip(paths, (left, base, right)):
            p.write_bytes(raw)
        result = run(["git", "merge-file", "-p", *map(str, paths)], check=False)
        if result.returncode:
            raise Stop("CUSTOM_RULE_CONFLICT: " + name)
        return File(result.stdout, local.mode)


def describe(f: Optional[File]) -> Optional[dict]:
    return None if f is None else {"sha256": f.digest(), "mode": f.mode, "bytes": len(f.data)}


def clean_target(root: Path) -> tuple[str, str]:
    INDEX_MODES.clear()
    actual = Path(git(root, "rev-parse", "--show-toplevel").decode().strip()).resolve()
    if actual != root:
        raise Stop("PROJECT_NOT_ROOT")
    if git(root, "status", "--porcelain", "--untracked-files=all").strip():
        raise Stop("PROJECT_DIRTY: preserve current work; commit/stash it yourself before upgrade")
    for row in git(root, "ls-files", "--stage", "-z").split(b"\0"):
        if row:
            meta, path = row.split(b"\t", 1)
            mode, _, stage = meta.decode().split()
            if stage != "0" or mode not in ("100644", "100755", "120000"):
                raise Stop("INDEX_STATE_UNSUPPORTED")
            INDEX_MODES[str(root / path.decode())] = 0o755 if mode == "100755" else 0o644
    branch = git(root, "symbolic-ref", "--quiet", "--short", "HEAD", check=False).decode().strip()
    head = git(root, "rev-parse", "--verify", "HEAD").decode().strip()
    if not branch:
        raise Stop("DETACHED_HEAD: create an upgrade task branch")
    return branch, head


def plan(root: Path, new: Source, old_root: Path, explicit_choices: Optional[dict[str, str]] = None) -> tuple[dict, dict[str, tuple[Optional[File], Optional[File]]]]:
    validate_origin_urls(root)
    branch, head = clean_target(root)
    pin_file = read_target(root, ".agent-project-ops/PIN")
    if pin_file is None:
        raise Stop("PIN_MISSING: this command upgrades existing bound projects, not adoption")
    pin = kv(pin_file.data)
    if set(pin) != {"url", "sha", "ref", "fetched_at"} or not sha_ok(pin["sha"]):
        raise Stop("PIN_UNSUPPORTED: expected v0.1.x PIN fields url/sha/ref/fetched_at")
    if not pin["url"] or re.search(r"https?://[^/]*@|[?#]", pin["url"]):
        raise Stop("PIN_URL_UNSAFE")
    # A matching PIN does not make unsupported remote configuration valid.
    reg = read_target(root, ".agent-project-ops/remotes")
    if reg is None or kv(reg.data).get("authority") != "origin":
        raise Stop("AUTHORITY_UNSUPPORTED: preserve and reconcile project authority before upgrade")
    registry = kv(reg.data)
    for role in ("projection", "export", "share_export"):
        value = registry.get(role, "")
        if value and value != "(none)":
            raise Stop("LEGACY_REMOTE_ROLE_ACTIVE: reconcile " + role + " before upgrade")
        if registry.get(role + "_url", ""):
            raise Stop("LEGACY_REMOTE_ROLE_ACTIVE: reconcile " + role + "_url before upgrade")
    extra_remotes = [name for name in git(root, "remote").decode().splitlines() if name != "origin"]
    if extra_remotes:
        raise Stop("EXTRA_REMOTE_UNSUPPORTED: reconcile additional remotes before upgrade: " + ", ".join(extra_remotes))
    if pin["sha"] == new.sha:
        choices, before_config, after_config = project_choices(root, new, explicit_choices or {})
        if choices:
            if before_config != after_config:
                raise Stop("PROJECT_SETTINGS_REQUIRED: matching PIN has no recorded initialization choices")
            settings_helper.verify_bridge(root / "CLAUDE.md")
        return {"status": "UP_TO_DATE", "source_sha": new.sha, "project": str(root), "changes": []}, {}
    source_url = git(new.root, "remote", "get-url", "origin", check=False).decode().strip()
    if not source_url or canonical_url(source_url) != canonical_url(pin["url"]):
        raise Stop("SOURCE_URL_MISMATCH: use a trusted methodology clone matching the existing PIN URL; no silent fork migration")
    old = Source(old_root, pin["sha"])
    if old.sha != pin["sha"]:
        raise Stop("OLD_PIN_NOT_FOUND")
    binding = read_target(root, "AGENTS.md")
    if binding is None:
        raise Stop("AGENTS_MISSING")
    agents = binding.data.decode("utf-8").replace("\r\n", "\n")
    title = re.search(r"^# (.+) — project operations binding$", agents, re.M)
    disposer = re.search(r"^- Disposer: `?(@[A-Za-z0-9-]+)`?\s*$", agents, re.M)
    if not title or not disposer:
        raise Stop("CUSTOM_BINDING_NEEDS_REVIEW: cannot safely reconstruct original project name/disposer")
    values = {"PROJECT_NAME": title[1], "DISPOSER": disposer[1], "METHODOLOGY_URL": pin["url"],
              "METHODOLOGY_SHA": pin["sha"], "METHODOLOGY_REF": pin["ref"],
              "FETCHED_AT": pin["fetched_at"], "PROJECTION_REMOTE": registry.get("projection", "(none)")}
    fresh = dict(values, METHODOLOGY_SHA=new.sha, METHODOLOGY_REF=new.sha, FETCHED_AT=STAMP)
    choices, config_before, config_after = project_choices(root, new, explicit_choices or {})
    if choices:
        values.update({k.upper(): v for k, v in choices.items()})
        fresh.update({k.upper(): v for k, v in choices.items()})
        values["PROJECT_CONFIG"] = config_before.decode("utf-8")
        fresh["PROJECT_CONFIG"] = config_after.decode("utf-8")
    # A source clone is supplied explicitly; do not silently change a fork's canonical URL.
    old_files, new_files = render(old, values), render(new, fresh)
    if choices:
        current_claude = read_target(root, "CLAUDE.md")
        old_claude = old_files.get("CLAUDE.md")
        if (current_claude is not None and not same(current_claude, old_claude) and
                current_claude.data.replace(b"\r\n", b"\n") not in (b"@AGENTS.md", b"@AGENTS.md\n")):
            raise Stop("CLAUDE_RULE_MIGRATION_REQUIRED: review and preserve CLAUDE.md in AGENTS.md using migrate-claude first")
    changes: dict[str, tuple[Optional[File], Optional[File]]] = {}
    conflicts = []
    # core.filemode=false is an explicit Git guarantee that executable bits
    # cannot be trusted from the filesystem/index. This exception applies only
    # to APO-owned snapshot paths, never arbitrary user-owned bridge files.
    no_filemode = git(root, "config", "--bool", "--get", "core.filemode", check=False).strip() == b"false"
    for name in sorted(set(old_files) | set(new_files)):
        if choices and name == ".agent-project-ops/project-config":
            continue  # Explicit reviewed choices append to existing project settings below.
        current, before, after = read_target(root, name), old_files.get(name), new_files.get(name)
        mode_drift = no_filemode and name.startswith(".agent-project-ops/")
        if name.startswith(".agent-project-ops/") and not same(current, before, legacy_filemode=mode_drift):
            conflicts.append("CUSTOM_SNAPSHOT: " + name)
            continue
        if same(current, after, legacy_filemode=mode_drift):
            continue
        if same(current, before, legacy_filemode=mode_drift):
            resolved = after
        elif same(before, after, legacy_filemode=mode_drift):
            continue  # Preserve unrelated user edits in generated bridge files.
        elif current is not None and before is not None and after is not None:
            try:
                resolved = merge_text(current, before, after, name)
            except Stop as e:
                conflicts.append(str(e))
                continue
        else:
            conflicts.append("OWNERSHIP_CONFLICT: " + name)
            continue
        if current != resolved:
            changes[name] = (current, resolved)
    if conflicts:
        raise Stop("UPGRADE_CONFLICTS:\n" + "\n".join(conflicts))
    if choices and config_before != config_after:
        current_config = read_target(root, ".agent-project-ops/project-config")
        changes[".agent-project-ops/project-config"] = (current_config, File(config_after))
    new_pin = (f"url={pin['url']}\nsha={new.sha}\nref={new.sha}\nfetched_at={STAMP}\n").encode()
    changes[".agent-project-ops/PIN"] = (pin_file, File(new_pin))
    # Hash before/after states of EVERY owned path, including unchanged bridges.
    inputs = {p: describe(read_target(root, p)) for p in sorted(set(old_files) | set(new_files))}
    # Project-specific settings are not copied/replaced; bind them into the preview.
    for p in (".agent-project-ops/remotes", ".agent-project-ops/project-config", ".agent-project-ops/export-strip-extra"):
        inputs[p] = describe(read_target(root, p))
    rows = [{"path": p, "before": describe(a), "after": describe(b)} for p, (a, b) in sorted(changes.items())]
    payload = {"project": str(root), "branch": branch, "head": head, "old_sha": old.sha,
               "source_sha": new.sha, "inputs": inputs, "changes": rows}
    if choices:
        payload["project_settings"] = choices
    ident = hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()
    summary = {k: v for k, v in payload.items() if k != "inputs"}
    summary.update(status="PREVIEW", plan_id=ident,
                   preserved=["business files", "project custom bridge text", "remotes", "existing project-config entries", "Git config", "GitHub Issues"],
                   policy_change="Retired generic rules and adapters removed; explicit project policies are NOT implicitly revoked.",
                   control_plane="PENDING_RECONCILIATION: review active GitHub CC/Phase/project-specific rules separately; no API calls performed.")
    return summary, changes


def emit_patch(info: dict, changes: dict[str, tuple[Optional[File], Optional[File]]]) -> bytes:
    """Use Git's standard patch/apply/reverse format, never a custom file writer."""
    result: list[str] = []
    timestamp = datetime.now(timezone.utc).isoformat()
    timestamp_paths = {".agent-project-ops/PIN", "AGENTS.md", ".github/ISSUE_TEMPLATE/command-center.md"}
    for name, (before, after) in sorted(changes.items()):
        safe_rel(name)
        old = before.data if before else b""
        new = after.data if after else b""
        if name in timestamp_paths:
            new = new.replace(STAMP.encode(), timestamp.encode())
        if b"\0" in old + new:
            raise Stop("BINARY_PATCH_UNSUPPORTED: " + name)
        a, b = old.decode("utf-8"), new.decode("utf-8")
        result.append(f"diff --git a/{name} b/{name}\n")
        if before is None:
            result.append(f"new file mode {0o100000 | after.mode:o}\n")
        elif after is None:
            result.append(f"deleted file mode {0o100000 | before.mode:o}\n")
        elif before.mode != after.mode:
            result.extend([f"old mode {0o100000 | before.mode:o}\n", f"new mode {0o100000 | after.mode:o}\n"])
        # Git checks all hunks before applying (no --reject / --unsafe-paths).
        for line in difflib.unified_diff(a.splitlines(True), b.splitlines(True),
                fromfile=f"a/{name}" if before else "/dev/null",
                tofile=f"b/{name}" if after else "/dev/null", n=3):
            if not line.endswith("\n"):
                line += "\n\\ No newline at end of file\n"
            result.append(line)
    return "".join(result).encode("utf-8")


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--old-source", type=Path, help="Trusted Git clone containing the old PIN commit; default: --source")
    parser.add_argument("--patch", action="store_true", help="Emit a Git patch to stdout; does not apply it")
    parser.add_argument("--expect-plan", help="Preview plan_id; required for --patch")
    parser.add_argument("--process-mode")
    parser.add_argument("--agent-tools")
    parser.add_argument("--external-tools")
    args = parser.parse_args(argv)
    try:
        root = args.project.resolve(strict=True)
        source = Source(args.source, "HEAD", clean=True)
        if root == source.root or root in source.root.parents or source.root in root.parents:
            raise Stop("SOURCE_PROJECT_OVERLAP: keep the methodology clone separate")
        explicit = {key: getattr(args, key) for key in settings_helper.KEYS if getattr(args, key) is not None}
        info, changes = plan(root, source, args.old_source or args.source, explicit)
        if args.patch:
            if not args.expect_plan or info.get("plan_id") != args.expect_plan:
                raise Stop("PLAN_CHANGED: preview and review its exact plan_id before exporting")
            default = git(root, "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD", check=False).decode().strip()
            if info.get("branch") in {"main", "master", default.removeprefix("origin/")}:
                raise Stop("DEFAULT_BRANCH_REFUSED: use an isolated upgrade worktree and preview again")
            patch = emit_patch(info, changes)
            sys.stdout.buffer.write(patch)
            print(json.dumps({"status": "PATCH_EXPORTED_NOT_APPLIED", "patch_sha256": hashlib.sha256(patch).hexdigest(),
                "baseline_commit": info["head"], "source_sha": source.sha, "control_plane": info["control_plane"]}), file=sys.stderr)
        else:
            print(json.dumps(info, ensure_ascii=False, indent=2))
        return 0
    except (Stop, OSError, ValueError, UnicodeError, KeyError, subprocess.SubprocessError) as e:
        # Never mix a JSON error with a patch stream that might be blindly applied.
        print(json.dumps({"status": "BLOCKED", "reason": str(e)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
