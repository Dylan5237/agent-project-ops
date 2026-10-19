#!/usr/bin/env python3
"""Select, generate and verify project bindings; preserve old rule text explicitly."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

KEYS = ("process_mode", "agent_tools", "external_tools")
OTHER_KEYS = {"task_base", "max_worktrees", "worktree_mode"}
BRIDGE = "@AGENTS.md\n"


class Invalid(ValueError):
    pass


def catalog(source: Path) -> dict:
    data = json.loads((source / "templates/project-options.json").read_text(encoding="utf-8"))
    if data.get("layout_version") != 1:
        raise Invalid("unsupported project options layout")
    for group in ("agent_tools", "external_tools"):
        if not isinstance(data.get(group), dict) or not data[group]:
            raise Invalid("invalid option group: " + group)
        for key, item in data[group].items():
            if not re.fullmatch(r"[a-z][a-z0-9-]*", key):
                raise Invalid("invalid option id")
            if group == "external_tools" and item["guide"] != key + ".md":
                raise Invalid("invalid guide path")
            if group == "agent_tools" and item["skills_dir"] not in (".agents/skills", ".claude/skills", ".codebuddy/skills"):
                raise Invalid("unsupported skills directory")
    return data


def subset(value: str, options: dict, *, none: bool = False) -> str:
    if none and value == "none":
        return value
    tokens = value.split(",")
    if not value or len(set(tokens)) != len(tokens) or any(t not in options for t in tokens):
        raise Invalid("expected a nonempty, unique comma-separated subset: " + ",".join(options))
    return ",".join(key for key in options if key in tokens)


def normalize(data: dict, mode: str, agents: str, external: str) -> dict[str, str]:
    if mode not in ("light", "standard"):
        raise Invalid("process_mode must be light or standard")
    return dict(process_mode=mode,
                agent_tools=subset(agents, data["agent_tools"]),
                external_tools=subset(external, data["external_tools"], none=True))


def config_values(text: str, *, strict: bool = True) -> dict[str, str]:
    result = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        key, sep, value = line.partition("=")
        if not sep or key in result or (strict and key not in set(KEYS) | OTHER_KEYS):
            raise Invalid("invalid, duplicate or unknown project-config entry: " + line)
        result[key] = value
    return result


def settings_text(settings: dict[str, str]) -> str:
    return "".join(key + "=" + settings[key] + "\n" for key in KEYS)


def methodology(root: Path) -> Path:
    return root if (root / "PRINCIPLES.md").is_file() else root / ".agent-project-ops"


def regular(path: Path) -> bytes:
    if path.is_symlink() or not path.is_file():
        raise Invalid("expected a regular file: " + str(path))
    return path.read_bytes()


def tree(path: Path) -> dict[str, bytes]:
    if path.parent.is_symlink() or path.is_symlink() or not path.is_dir():
        raise Invalid("expected a real skill directory: " + str(path))
    result = {}
    for entry in path.rglob("*"):
        if entry.is_symlink():
            raise Invalid("skill symlinks are unsupported: " + str(entry))
        if entry.is_file():
            result[entry.relative_to(path).as_posix()] = regular(entry)
        elif not entry.is_dir():
            raise Invalid("special skill entry: " + str(entry))
    if not result or not any(p.endswith("/SKILL.md") for p in result):
        raise Invalid("no skill manifests: " + str(path))
    return result


def verify_bridge(path: Path) -> None:
    if regular(path).decode("utf-8").replace("\r\n", "\n") not in (BRIDGE, BRIDGE.rstrip("\n")):
        raise Invalid("CLAUDE.md must contain only @AGENTS.md: " + str(path))


def checked_settings(root: Path, data: dict) -> dict[str, str]:
    values = config_values(regular(root / ".agent-project-ops/project-config").decode("utf-8"))
    try:
        return normalize(data, *(values[key] for key in KEYS))
    except KeyError as exc:
        raise Invalid("missing project setting: " + str(exc)) from exc


def generate(root: Path, source: Path, settings: dict[str, str]) -> None:
    data = catalog(source)
    verify_bridge(root / "CLAUDE.md")
    if (root / ".agent-project-ops").is_symlink():
        raise Invalid("methodology snapshot must not be a symlink")
    source_tree = tree(root / ".agents/skills")
    selected = settings["agent_tools"].split(",")
    destinations = []
    for key, item in data["agent_tools"].items():
        target = root / item["skills_dir"]
        if item["skills_dir"] == ".agents/skills":
            continue
        if target.parent.is_symlink():
            raise Invalid("skill parent must not be a symlink")
        if target.exists() or target.is_symlink():
            raise Invalid("refusing to replace existing skill directory: " + str(target))
        if key in selected:
            destinations.append(target)
    guides = []
    selected_external = settings["external_tools"].split(",")
    for key, item in data["external_tools"].items():
        if key in selected_external:
            raw = regular(source / "integrations" / item["guide"])
            dest = root / ".agent-project-ops/integrations" / item["guide"]
            if dest.parent.is_symlink() or dest.exists() or dest.is_symlink():
                raise Invalid("refusing to replace guide: " + str(dest))
            guides.append((dest, raw))
    config = root / ".agent-project-ops/project-config"
    if config.exists() or config.is_symlink():
        raise Invalid("refusing to replace project-config")
    for dest in destinations:
        dest.mkdir(parents=True)
        for name, raw in source_tree.items():
            file = dest / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_bytes(raw)
    for dest, raw in guides:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(raw)
    config.write_text(settings_text(settings), encoding="utf-8", newline="\n")


def check(root: Path) -> None:
    source = methodology(root)
    if source.is_symlink():
        raise Invalid("methodology snapshot must not be a symlink")
    data = catalog(source)
    settings = checked_settings(root, data)
    verify_bridge(root / "CLAUDE.md")
    original = tree(root / ".agents/skills")
    for key, item in data["agent_tools"].items():
        if item["skills_dir"] == ".agents/skills":
            continue
        dest = root / item["skills_dir"]
        if key in settings["agent_tools"].split(","):
            if tree(dest) != original:
                raise Invalid("skill copy drift: " + str(dest))
        elif dest.parent.is_symlink() or dest.exists() or dest.is_symlink():
            raise Invalid("unselected skill adapter exists: " + str(dest))
    selected = settings["external_tools"].split(",")
    expected = {item["guide"] for key, item in data["external_tools"].items() if key in selected}
    guide_dir = root / ".agent-project-ops/integrations"
    if guide_dir.is_symlink():
        raise Invalid("integration directory must not be a symlink")
    actual = {p.name for p in guide_dir.iterdir()} if guide_dir.exists() else set()
    if actual != expected:
        raise Invalid("selected integration guide set differs")
    for name in expected:
        if not regular(guide_dir / name).strip():
            raise Invalid("empty integration guide")
    cc = regular(root / ".github/ISSUE_TEMPLATE/command-center.md").decode("utf-8")
    for key in KEYS:
        if key + "=" + settings[key] not in cc:
            raise Invalid("Command Center setting differs: " + key)


def check_core(root: Path) -> None:
    source = methodology(root)
    data = catalog(source)
    files = {source / "PRINCIPLES.md", source / "templates/AGENTS.md", source / "templates/CLAUDE.md"}
    files.update(source.glob("playbooks/**/*.md"))
    files.update(source.glob("skills/**/SKILL.md"))
    files.update(p for p in source.glob("scripts/**/*") if p.suffix in (".sh", ".py"))
    for name in ("AGENTS.md", "CLAUDE.md"):
        if (root / name).exists():
            files.add(root / name)
    names = [name.casefold() for key, item in data["external_tools"].items()
             for name in [key, item["label"], *item["names"]]]
    for file in sorted(files):
        text = regular(file).decode("utf-8").casefold()
        if any(name in text for name in names):
            raise Invalid("external tool name in core: " + str(file))
    verify_bridge(source / "templates/CLAUDE.md")
    if (root / "CLAUDE.md").exists():
        verify_bridge(root / "CLAUDE.md")


def replace_text(path: Path, text: str) -> None:
    fd, name = tempfile.mkstemp(prefix=".apo-rule-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(text)
        os.chmod(name, stat.S_IMODE(path.stat().st_mode))
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.remove(name)


def migrate(root: Path, apply: bool) -> None:
    agents, claude = root / "AGENTS.md", root / "CLAUDE.md"
    old_agents, old_claude = regular(agents), regular(claude)
    a = old_agents.decode("utf-8")
    c = old_claude.decode("utf-8").replace("\r\n", "\n")
    if "\0" in a + c or not a.strip():
        raise Invalid("rule files must be nonempty UTF-8 text without NUL")
    if c in (BRIDGE, BRIDGE.rstrip("\n")):
        print("UNCHANGED: one-line CLAUDE.md")
        return
    lines = c.splitlines()
    if lines and lines[0] == "@AGENTS.md":
        lines = lines[1:]  # Only the leading bridge is owned; preserve examples below it.
    custom = "\n".join(lines).strip("\n")
    marker = "<!-- apo-claude-preserved: " + hashlib.sha256(custom.encode()).hexdigest() + " -->"
    addition = "\n\n## Preserved project instructions\n\n" + marker + "\n\n" + custom + "\n"
    if marker in a and custom not in a:
        raise Invalid("existing migration marker conflicts with preserved text")
    merged = a if not custom or marker in a else a.rstrip("\n") + addition
    print("APPLY" if apply else "PREVIEW", ": preserve CLAUDE.md text in AGENTS.md, then write one-line import")
    if apply:
        if regular(agents) != old_agents or regular(claude) != old_claude:
            raise Invalid("rule files changed during migration")
        # Write preserved content first. A failure cannot discard the old rules.
        replace_text(agents, merged)
        replace_text(claude, BRIDGE)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("select", "generate", "check", "check-core", "validate-config", "migrate-claude"))
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--source", type=Path)
    parser.add_argument("--process-mode", default="")
    parser.add_argument("--agent-tools", default="")
    parser.add_argument("--external-tools", default="")
    parser.add_argument("--non-interactive", action="store_true")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    try:
        root = args.root.resolve()
        source = args.source.resolve() if args.source else methodology(root)
        if args.command == "migrate-claude":
            migrate(root, args.apply)
        elif args.command in ("select", "generate"):
            data = catalog(source)
            values = [args.process_mode, args.agent_tools, args.external_tools]
            prompts = ["Process mode [standard]: ", "Agent tools (" + ",".join(data["agent_tools"]) + "): ",
                       "External tools (" + ",".join(data["external_tools"]) + ",none) [none]: "]
            for i, value in enumerate(values):
                if not value:
                    if args.non_interactive or not sys.stdin.isatty():
                        raise Invalid("explicit --" + KEYS[i].replace("_", "-") + " is required without interactive input")
                    print(prompts[i], file=sys.stderr, end="", flush=True)
                    values[i] = input().strip() or ("standard" if i == 0 else "none" if i == 2 else "")
            settings = normalize(data, *values)
            if args.command == "select":
                print(settings_text(settings), end="")
            else:
                generate(root, source, settings)
                check(root)
        elif args.command == "check":
            check(root)
        elif args.command == "check-core":
            check_core(root)
        elif args.command == "validate-config":
            checked_settings(root, catalog(source))
        return 0
    except (OSError, ValueError, KeyError, EOFError) as exc:
        print("project-settings: " + str(exc), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
