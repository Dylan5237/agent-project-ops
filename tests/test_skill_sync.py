"""Real CLI/file swaps plus injected filesystem failure recovery; temporary projects only."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/project-settings.py'
spec = importlib.util.spec_from_file_location('sync_settings', SCRIPT)
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.put('.agent-project-ops/templates/project-options.json', (ROOT/'templates/project-options.json').read_text(encoding='utf-8'))
        self.put('.agent-project-ops/project-config', 'process_mode=standard\nagent_tools=codex,claude,workbuddy\nexternal_tools=none\n')
        for folder in ('.agents', '.claude', '.codebuddy'):
            self.put(folder + '/skills/demo/SKILL.md', '---\nname: demo\ndescription: Test\n---\n旧规则\n')
        self.put('AGENTS.md', 'untouched\n')
        self.put('CLAUDE.md', '@AGENTS.md\n')

    def put(self, name, text):
        path = self.root/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding='utf-8', newline='\n')
        return path

    def cli(self, *args, ok=True, env=None):
        result = subprocess.run([sys.executable, str(SCRIPT), 'sync-skills', '--root', str(self.root), *args],
                  capture_output=True, text=True, encoding='utf-8', env=env)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return result

    def snapshot(self):
        return {str(p.relative_to(self.root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.root.rglob('*') if p.is_file()}

    def plan(self):
        return re.search(r'plan_id=([0-9a-f]{64})', self.cli().stdout)[1]

    def test_preview_zero_write_apply_both_copies_and_recover_extra(self):
        self.put('.agents/skills/demo/SKILL.md', '---\nname: demo\ndescription: Test\n---\n新规则\n')
        self.put('.claude/skills/personal/SKILL.md', 'precious personal bytes\n')
        before = self.snapshot()
        preview = self.cli()
        self.assertEqual(before, self.snapshot())
        self.assertIn('-旧规则', preview.stdout)
        self.assertIn('+新规则', preview.stdout)
        self.assertIn('QUARANTINE_EXTRA', preview.stdout)
        token = re.search(r'plan_id=([0-9a-f]{64})', preview.stdout)[1]
        self.cli('--apply', '--expect-plan', token)
        source = s.tree(self.root/'.agents/skills')
        for host in ('.claude', '.codebuddy'):
            self.assertEqual(source, s.tree(self.root/host/'skills'))
        self.assertIn('UNCHANGED', self.cli().stdout)
        backup = next((self.root/'.git/apo-skill-sync').iterdir())
        manifest = json.loads((backup/'manifest.json').read_text())
        self.assertEqual(manifest['state'], 'applied')
        self.assertEqual((backup/'0/personal/SKILL.md').read_text(), 'precious personal bytes\n')
        # Exercise the documented reversible move on an isolated project.
        target = self.root/'.claude/skills'
        target.rename(backup/'held-new')
        (backup/'0').rename(target)
        self.assertTrue((target/'personal/SKILL.md').exists())
        self.assertEqual((self.root/'AGENTS.md').read_text(), 'untouched\n')
        self.assertEqual((self.root/'CLAUDE.md').read_text(), '@AGENTS.md\n')

    def test_stale_source_target_settings_and_missing_confirmation_zero_write(self):
        for path in ('.agents/skills/demo/SKILL.md', '.claude/skills/demo/SKILL.md', '.agent-project-ops/project-config'):
            token = self.plan()
            with (self.root/path).open('a', encoding='utf-8') as stream:
                stream.write('\n# changed\n')
            before = self.snapshot()
            result = self.cli('--apply', '--expect-plan', token, ok=False)
            self.assertIn('STALE_PLAN', result.stderr)
            self.assertEqual(before, self.snapshot())
        before = self.snapshot()
        self.cli('--apply', ok=False)
        self.assertEqual(before, self.snapshot())

    def test_second_target_install_failure_rolls_back_and_retains_new_data(self):
        self.put('.agents/skills/demo/new.txt', 'new bytes\n')
        token = self.plan()
        original = Path.rename
        def fail_second(path, target):
            if path.name.startswith('.apo-sync-') and Path(target) == self.root/'.codebuddy/skills':
                raise OSError('injected second swap failure')
            return original(path, target)
        out = io.StringIO()
        with mock.patch.object(Path, 'rename', fail_second), contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            with self.assertRaisesRegex(OSError, 'injected'):
                s.sync_skills(self.root, True, token)
        for host in ('.claude', '.codebuddy'):
            self.assertNotIn('demo/new.txt', s.tree(self.root/host/'skills'))
        backup = next((self.root/'.git/apo-skill-sync').iterdir())
        manifest = json.loads((backup/'manifest.json').read_text())
        self.assertEqual(manifest['state'], 'failed')
        self.assertTrue((backup/'failed-new-0/demo/new.txt').is_file())
        self.assertIn(str(backup), out.getvalue())

    def test_unselected_directory_not_created_and_git_env_cannot_redirect_backup(self):
        # Both selected copies exist; a hostile Git environment must not relocate recovery.
        elsewhere = self.root/'other.git'
        elsewhere.mkdir()
        self.put('.agents/skills/demo/new.txt', 'new\n')
        env = os.environ.copy()
        env['GIT_DIR'] = str(elsewhere)
        self.cli('--apply', '--expect-plan', self.plan(), env=env)
        self.assertTrue((self.root/'.git/apo-skill-sync').is_dir())
        self.assertEqual(list(elsewhere.iterdir()), [])
        # Quarantine selected fixtures, then switch to codex only.
        (self.root/'.claude/skills').rename(self.root/'.git/claude-held')
        (self.root/'.codebuddy/skills').rename(self.root/'.git/codebuddy-held')
        self.put('.agent-project-ops/project-config', 'process_mode=standard\nagent_tools=codex\nexternal_tools=none\n')
        self.cli('--apply', '--expect-plan', self.plan())
        self.assertFalse((self.root/'.claude/skills').exists())
        self.assertFalse((self.root/'.codebuddy/skills').exists())

    def test_empty_directories_are_previewed_bound_and_recovered(self):
        (self.root/'.agents/skills/demo/empty-source').mkdir()
        extra = self.root/'.claude/skills/empty-target'
        extra.mkdir()
        preview = self.cli()
        self.assertIn('empty-source', preview.stdout)
        self.assertIn('empty-target', preview.stdout)
        token = re.search(r'plan_id=([0-9a-f]{64})', preview.stdout)[1]
        (extra/'new-empty').mkdir()
        self.cli('--apply', '--expect-plan', token, ok=False)
        self.cli('--apply', '--expect-plan', self.plan())
        for host in ('.claude', '.codebuddy'):
            self.assertTrue((self.root/host/'skills/demo/empty-source').is_dir())
        backup = next((self.root/'.git/apo-skill-sync').iterdir())
        self.assertTrue((backup/'0/empty-target/new-empty').is_dir())

    @unittest.skipUnless(os.name == 'posix', 'POSIX permission contract')
    def test_executable_mode_preserved_and_mode_only_change_invalidates_preview(self):
        script = self.put('.agents/skills/demo/run.sh', '#!/bin/sh\necho working\n')
        script.chmod(0o755)
        token = self.plan()
        script.chmod(0o700)
        self.cli('--apply', '--expect-plan', token, ok=False)
        self.cli('--apply', '--expect-plan', self.plan())
        for host in ('.claude', '.codebuddy'):
            target = self.root/host/'skills/demo/run.sh'
            self.assertEqual(target.stat().st_mode & 0o777, 0o700)
            result = subprocess.run([str(target)], capture_output=True, text=True)
            self.assertEqual(result.stdout.strip(), 'working')


if __name__ == '__main__':
    unittest.main()
