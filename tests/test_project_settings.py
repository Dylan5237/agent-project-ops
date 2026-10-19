"""Local process and filesystem contracts; no accounts, network or real projects."""
import hashlib
import importlib.util
import itertools
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import io
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/project-settings.py"
spec = importlib.util.spec_from_file_location("settings_tested", SCRIPT)
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name).resolve()
        self.source = self.base / "source"
        self.put(self.source, "templates/project-options.json", (ROOT / "templates/project-options.json").read_text(encoding="utf-8"))
        self.put(self.source, "scripts/project-settings.py", SCRIPT.read_text(encoding="utf-8"))
        for file in ("PRINCIPLES.md", "templates/AGENTS.md"):
            self.put(self.source, file, "Generic project rules\n")
        self.put(self.source, "templates/CLAUDE.md", "@AGENTS.md\n")
        for guide in (ROOT / "integrations").glob("*.md"):
            self.put(self.source, "integrations/" + guide.name, guide.read_text(encoding="utf-8"))

    def put(self, root, name, text):
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
        return path

    def command_center(self, mode, agents, external):
        return ("## 项目设置\n\n"
                f"- 流程档位：process_mode={mode}（未记录时按 standard）\n"
                f"- Agent 工具：agent_tools={agents}\n"
                f"- 外部工具：external_tools={external}（none 表示不接入）\n")

    def directory_link(self, link, target):
        """Create a directory symlink on Unix and a real junction on Windows."""
        if os.name == "nt":
            powershell = shutil.which("powershell") or shutil.which("powershell.exe")
            if not powershell:
                self.skipTest("PowerShell is required to create a Windows directory junction")
            quote = lambda value: "'" + str(value).replace("'", "''") + "'"
            command = ("$ErrorActionPreference = 'Stop'; "
                       f"New-Item -ItemType Junction -Path {quote(link)} "
                       f"-Target {quote(target)} -ErrorAction Stop | Out-Null")
            result = subprocess.run([powershell, "-NoProfile", "-NonInteractive", "-Command", command],
                                    capture_output=True, text=True)
            if result.returncode:
                self.fail("could not create a temporary Windows junction: " + result.stderr.strip())
        else:
            try:
                link.symlink_to(target, target_is_directory=True)
            except OSError as exc:
                self.skipTest("directory symlinks are unavailable: " + str(exc))

    def cli(self, *args, ok=True):
        result = subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, encoding="utf-8")
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout)
        return result

    def fixture(self, name, mode="standard", agents="codex,claude,workbuddy", external="none"):
        root = self.base / name
        self.put(root, "AGENTS.md", "Project rule\n")
        self.put(root, "CLAUDE.md", "@AGENTS.md\n")
        self.put(root, ".agents/skills/fixture/SKILL.md", "---\nname: fixture\ndescription: Test\n---\nRead references/policy.md.\n")
        self.put(root, ".agents/skills/fixture/references/policy.md", "Preserve all Unicode rules.\n")
        self.put(root, ".agents/skills/fixture/scripts/probe.py", "print('fixture')\n")
        self.put(root, ".agent-project-ops/templates/project-options.json", (ROOT / "templates/project-options.json").read_text(encoding="utf-8"))
        self.put(root, ".agent-project-ops/scripts/project-settings.py", SCRIPT.read_text(encoding="utf-8"))
        self.put(root, ".github/ISSUE_TEMPLATE/command-center.md", self.command_center(mode, agents, external))
        return root

    def generate(self, root, mode="standard", agents="codex,claude,workbuddy", external="none", ok=True):
        return self.cli("generate", "--source", self.source, "--root", root,
                        "--process-mode", mode, "--agent-tools", agents,
                        "--external-tools", external, "--non-interactive", ok=ok)

    def test_all_56_choice_combinations(self):
        tools = ["codex", "claude", "workbuddy"]
        sets = [",".join(combo) for size in range(1, 4) for combo in itertools.combinations(tools, size)]
        external_sets = ["none", "arckeep", "grok-bot", "arckeep,grok-bot"]
        for i, (mode, agents, external) in enumerate(itertools.product(("light", "standard"), sets, external_sets)):
            with self.subTest(mode=mode, agents=agents, external=external):
                root = self.fixture(str(i), mode, agents, external)
                self.generate(root, mode, agents, external)
                self.cli("check", "--root", root)
                self.assertEqual((root / ".agent-project-ops/project-config").read_text(encoding="utf-8"),
                                 f"process_mode={mode}\nagent_tools={agents}\nexternal_tools={external}\n")
                for tool, folder in (("claude", ".claude"), ("workbuddy", ".codebuddy")):
                    self.assertEqual((root / folder / "skills").exists(), tool in agents.split(","))
                    if tool in agents.split(","):
                        self.assertEqual(s.tree(root / folder / "skills"), s.tree(root / ".agents/skills"))

    def test_missing_invalid_duplicate_or_empty_choices_rejected(self):
        for mode, agents, external in (("", "codex", "none"), ("fast", "codex", "none"),
                ("standard", "", "none"), ("standard", "codex,codex", "none"),
                ("standard", "codex,", "none"), ("standard", "unknown", "none"),
                ("standard", "codex", ""), ("standard", "codex", "none,arckeep"),
                ("standard", "codex", "arckeep,arckeep")):
            result = self.cli("select", "--source", self.source, "--process-mode", mode,
                              "--agent-tools", agents, "--external-tools", external, ok=False)
            self.assertEqual(result.stdout, "")

    def test_selection_canonical_order(self):
        result = self.cli("select", "--source", self.source, "--process-mode", "light",
                          "--agent-tools", "workbuddy,codex", "--external-tools", "grok-bot,arckeep")
        self.assertIn("agent_tools=codex,workbuddy", result.stdout)
        self.assertIn("external_tools=arckeep,grok-bot", result.stdout)

    def test_interactive_defaults_require_an_agent_selection(self):
        output = io.StringIO()
        argv = [str(SCRIPT), "select", "--source", str(self.source)]
        with mock.patch.object(sys, "argv", argv), mock.patch.object(sys.stdin, "isatty", return_value=True), \
                mock.patch("builtins.input", side_effect=["", "workbuddy", ""]), mock.patch.object(sys, "stdout", output):
            self.assertEqual(s.main(), 0)
        self.assertEqual(output.getvalue(), "process_mode=standard\nagent_tools=workbuddy\nexternal_tools=none\n")

    def test_drift_missing_extra_copy_and_cc_setting_fail(self):
        root = self.fixture("drift")
        self.generate(root)
        skill = root / ".codebuddy/skills/fixture/SKILL.md"
        original = skill.read_bytes()
        skill.write_bytes(original + b"drift")
        self.cli("check", "--root", root, ok=False)
        skill.write_bytes(original)
        skill.rename(skill.with_name("missing.md"))
        self.cli("check", "--root", root, ok=False)
        skill.with_name("missing.md").rename(skill)
        self.put(root, ".claude/skills/unowned.txt", "must not be removed")
        self.cli("check", "--root", root, ok=False)
        self.assertEqual((root / ".claude/skills/unowned.txt").read_text(), "must not be removed")
        other = self.fixture("cc")
        self.generate(other)
        self.put(other, ".github/ISSUE_TEMPLATE/command-center.md", "process_mode=light\n")
        self.cli("check", "--root", other, ok=False)

    def test_command_center_rejects_superset_duplicate_and_missing_settings(self):
        root = self.fixture("cc-exact", agents="codex", external="arckeep")
        self.generate(root, agents="codex", external="arckeep")

        invalid_documents = {
            "superset": self.command_center("standard", "codex,workbuddy", "arckeep,grok-bot"),
            "duplicate": self.command_center("standard", "codex", "arckeep")
                         + "- Agent 工具：agent_tools=codex\n",
            "missing": "## 项目设置\n\n"
                       "- 流程档位：process_mode=standard（未记录时按 standard）\n"
                       "- Agent 工具：agent_tools=codex\n",
        }
        for name, document in invalid_documents.items():
            with self.subTest(name=name):
                self.put(root, ".github/ISSUE_TEMPLATE/command-center.md", document)
                self.cli("check", "--root", root, ok=False)

    def test_project_root_principles_does_not_hide_snapshot_layout(self):
        root = self.fixture("root-principles", agents="codex")
        self.generate(root, agents="codex")
        self.put(root, "PRINCIPLES.md", "Business architecture principles\n")
        self.cli("check", "--root", root)

    def test_unselected_adapter_and_guide_fail(self):
        root = self.fixture("unselected", agents="codex")
        self.generate(root, agents="codex")
        self.put(root, ".claude/skills/custom/SKILL.md", "custom rule")
        self.cli("check", "--root", root, ok=False)
        other = self.fixture("guide", agents="codex")
        self.generate(other, agents="codex")
        self.put(other, ".agent-project-ops/integrations/arckeep.md", "custom guide")
        self.cli("check", "--root", other, ok=False)

    def test_generation_refuses_existing_custom_adapter_before_copying(self):
        root = self.fixture("owned")
        custom = self.put(root, ".codebuddy/skills/custom/SKILL.md", "must survive")
        self.generate(root, ok=False)
        self.assertEqual(custom.read_text(), "must survive")
        self.assertFalse((root / ".claude").exists())
        self.assertFalse((root / ".agent-project-ops/project-config").exists())

    def test_one_line_bridge_and_core_alias_negative(self):
        self.cli("check-core", "--root", self.source)
        for bridge in ("@AGENTS.md\n\n", "@AGENTS.md\nExtra rule\n", " @AGENTS.md\n"):
            self.put(self.source, "templates/CLAUDE.md", bridge)
            self.cli("check-core", "--root", self.source, ok=False)
        self.put(self.source, "templates/CLAUDE.md", "@AGENTS.md\n")
        for alias in ("ARCKEEP", "gRoKbOt", "GROK-BOT", "grok_bot"):
            self.put(self.source, "playbooks/test.md", alias)
            self.cli("check-core", "--root", self.source, ok=False)

    def test_migration_preview_apply_repeat_and_binary_refusal(self):
        root = self.fixture("migration")
        claude = self.put(root, "CLAUDE.md", "@AGENTS.md\n\nKeep this project rule.\n保留中文规则。\n")
        agents = root / "AGENTS.md"
        old = (agents.read_bytes(), claude.read_bytes())
        self.cli("migrate-claude", "--root", root)
        self.assertEqual(old, (agents.read_bytes(), claude.read_bytes()))
        self.cli("migrate-claude", "--root", root, "--apply")
        self.assertEqual(claude.read_text(), "@AGENTS.md\n")
        self.assertIn("保留中文规则。", agents.read_text(encoding="utf-8"))
        once = agents.read_bytes()
        self.cli("migrate-claude", "--root", root, "--apply")
        self.assertEqual(agents.read_bytes(), once)
        claude.write_bytes(b"bad\0rule")
        self.cli("migrate-claude", "--root", root, "--apply", ok=False)
        self.assertEqual(agents.read_bytes(), once)

    def test_migration_recovers_after_second_write_failure(self):
        root = self.fixture("retry")
        self.put(root, "CLAUDE.md", "@AGENTS.md\nPreserve this exactly.\n")
        original = s.replace_text
        def interrupt(path, text):
            if path.name == "CLAUDE.md":
                raise OSError("simulated second replace failure")
            original(path, text)
        with mock.patch.object(s, "replace_text", interrupt):
            with self.assertRaises(OSError):
                s.migrate(root, True)
        self.assertIn("Preserve this exactly.", (root / "AGENTS.md").read_text())
        self.assertIn("Preserve this exactly.", (root / "CLAUDE.md").read_text())
        self.cli("migrate-claude", "--root", root, "--apply")
        self.assertEqual((root / "AGENTS.md").read_text().count("Preserve this exactly."), 1)

    def test_migration_keeps_import_examples_in_custom_text(self):
        root = self.fixture("examples")
        self.put(root, "CLAUDE.md", "@AGENTS.md\nExample:\n```text\n@AGENTS.md\n```\n")
        self.cli("migrate-claude", "--root", root, "--apply")
        self.assertIn("```text\n@AGENTS.md\n```", (root / "AGENTS.md").read_text())

    @unittest.skipUnless(os.name == "posix", "POSIX ownership contract")
    def test_migration_preserves_owner_mode_and_stops_before_replace_on_chown_failure(self):
        root = self.fixture("metadata")
        agents = root / "AGENTS.md"
        agents.chmod(0o640)
        before = agents.stat()
        s.replace_text(agents, "Updated rule\n")
        after = agents.stat()
        self.assertEqual((after.st_uid, after.st_gid, after.st_mode),
                         (before.st_uid, before.st_gid, before.st_mode))
        with mock.patch.object(os, "chown", side_effect=PermissionError("cannot preserve ownership")):
            with self.assertRaises(PermissionError):
                s.replace_text(agents, "Must not replace\n")
        self.assertEqual(agents.read_text(), "Updated rule\n")
        self.assertEqual(list(root.glob(".apo-rule-*")), [])

    def test_generation_rejects_junction_parent_without_outside_writes(self):
        root = self.fixture("link-parent", agents="codex,workbuddy")
        outside = self.base / "outside-adapter"
        outside.mkdir()
        self.directory_link(root / ".codebuddy", outside)

        self.cli("generate", "--source", self.source, "--root", root,
                 "--process-mode", "standard", "--agent-tools", "codex,workbuddy",
                 "--external-tools", "none", "--non-interactive", ok=False)
        self.assertEqual(list(outside.iterdir()), [])

    def test_canonical_skills_rejects_nested_junction_without_copying_external_files(self):
        root = self.fixture("link-canonical", agents="codex,workbuddy")
        outside = self.base / "outside-skill"
        outside.mkdir()
        external_file = self.put(outside, "policy.md", "outside-only rule\n")
        link = root / ".agents/skills/fixture/references"
        shutil.rmtree(link)
        self.directory_link(link, outside)

        self.cli("generate", "--source", self.source, "--root", root,
                 "--process-mode", "standard", "--agent-tools", "codex,workbuddy",
                 "--external-tools", "none", "--non-interactive", ok=False)
        self.assertEqual(external_file.read_text(encoding="utf-8"), "outside-only rule\n")
        self.assertFalse((root / ".codebuddy/skills/fixture/references/policy.md").exists())
        self.assertFalse((root / ".agent-project-ops/project-config").exists())

    def test_core_scan_rejects_junction_before_descending(self):
        outside = self.base / "outside-core"
        outside.mkdir()
        self.put(outside, "external.md", "external-only text\n")
        self.directory_link(self.source / "playbooks", outside)
        self.cli("check-core", "--root", self.source, ok=False)


if __name__ == "__main__":
    unittest.main()
