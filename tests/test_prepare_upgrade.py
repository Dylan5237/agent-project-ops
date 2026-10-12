"""Isolated local Git fixtures; no network or user repositories are used."""
import importlib.util
import os
import sys
import subprocess
import tempfile
from pathlib import Path
import unittest

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / 'scripts' / 'prepare-upgrade.py'
spec = importlib.util.spec_from_file_location('prepare_upgrade', SCRIPT)
u = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = u
spec.loader.exec_module(u)


def cmd(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL)


class UpgradeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        # Match the public CLI's root.resolve(strict=True): macOS /var aliases
        # and Windows 8.3 temporary-directory paths are not canonical Git roots.
        self.base = Path(self.tmp.name).resolve(strict=True)
        self.src = self.base / 'method'
        self.src.mkdir()
        cmd(self.src, 'init', '-b', 'main')
        cmd(self.src, 'config', 'user.email', 'test@example.invalid')
        cmd(self.src, 'config', 'user.name', 'Test')
        cmd(self.src, 'remote', 'add', 'origin', 'https://github.com/example/method')
        self.put('PRINCIPLES.md', 'Old rules\n')
        self.put('LICENSE', 'MIT\n')
        self.put('scripts/bootstrap-project.sh', '#!/bin/bash\n# old bootstrap\n')
        self.put('scripts/new-worktree.sh', '#!/bin/bash\n# old worktree helper\n')
        self.put('templates/AGENTS.md', '# {{PROJECT_NAME}} — project operations binding\n\n- Disposer: {{DISPOSER}}\n- PIN: {{METHODOLOGY_SHA}}\n- Date: {{FETCHED_AT}}\n')
        self.put('templates/gitignore-agent-ops', '.worktrees/\n')
        self.put('templates/gitattributes-agent-ops', '*.sh text eol=lf\n')
        self.put('templates/ISSUE_TEMPLATE/command-center.md', 'Personal Fleet registration REQUIRED\n')
        self.put('skills/bootstrap-project/SKILL.md', '---\nname: bootstrap-project\ndescription: Test\n---\n\nOld Fleet rule\n')
        self.put('playbooks/start-project.md', 'Old Fleet requirement\n')
        self.commit()
        self.old = cmd(self.src, 'rev-parse', 'HEAD').decode().strip()
        self.proj = self.base / 'project'
        self.proj.mkdir()
        cmd(self.proj, 'init', '-b', 'main')
        cmd(self.proj, 'config', 'user.email', 'test@example.invalid')
        cmd(self.proj, 'config', 'user.name', 'Test')
        pin = {'url': 'https://github.com/example/method', 'sha': self.old,
               'ref': 'v0.1.2', 'fetched_at': '2026-01-01T00:00:00Z'}
        values = {'PROJECT_NAME': 'project', 'DISPOSER': '@Test',
                  'METHODOLOGY_URL': pin['url'], 'METHODOLOGY_SHA': pin['sha'],
                  'METHODOLOGY_REF': pin['ref'], 'FETCHED_AT': pin['fetched_at'],
                  'PROJECTION_REMOTE': '(none)'}
        for p, f in u.render(u.Source(self.src, self.old), values).items():
            target = self.proj / p
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(f.data)
            os.chmod(target, f.mode)
        self.pput('.agent-project-ops/PIN', ''.join(k + '=' + v + '\n' for k, v in pin.items()))
        self.pput('.agent-project-ops/remotes', 'authority=origin\nprojection=(none)\n')
        self.pput('.agent-project-ops/project-config', 'task_base=origin/develop\n')
        self.pput('business.py', 'x = 42\n')
        self.pcommit()
        cmd(self.proj, 'checkout', '-b', 'upgrade/apo')
        self.put('PRINCIPLES.md', 'New rules\n')
        self.put('playbooks/start-project.md', 'No personal dependencies\n')
        self.put('templates/ISSUE_TEMPLATE/command-center.md', 'Methodology {{METHODOLOGY_SHA}}\n')
        self.put('scripts/bootstrap-project.sh', '#!/bin/bash\nsubst "${METHODOLOGY_ROOT}/templates/ISSUE_TEMPLATE/command-center.md" x\n')
        self.put('skills/upgrade-project/helper.py', 'STAMP = "__APO_UPGRADE_TIME__"\n')
        self.put('skills/upgrade-project/SKILL.md', '---\nname: upgrade-project\ndescription: Test\n---\n\nNew upgrade rule\n')
        self.commit()
        self.new = u.Source(self.src, 'HEAD', clean=True)

    def put(self, p, text):
        f = self.src / p
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text, encoding='utf-8')

    def pput(self, p, text):
        f = self.proj / p
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text, encoding='utf-8')

    def commit(self):
        cmd(self.src, 'add', '.')
        cmd(self.src, 'commit', '-m', 'fixture')

    def pcommit(self):
        cmd(self.proj, 'add', '.')
        cmd(self.proj, 'commit', '-m', 'fixture')

    def preview(self):
        return u.plan(self.proj, self.new, self.src)

    def make_patch(self):
        info, changes = self.preview()
        patch = self.base / 'upgrade.patch'
        patch.write_bytes(u.emit_patch(info, changes))
        return info, patch

    def apply(self):
        info, patch = self.make_patch()
        cmd(self.proj, 'apply', '--check', str(patch))
        cmd(self.proj, 'apply', str(patch))
        return info, patch

    def snapshot(self):
        return {str(p.relative_to(self.proj)): p.read_bytes() for p in self.proj.rglob('*')
                if p.is_file() and '.git' not in p.relative_to(self.proj).parts}

    def test_preview_and_patch_do_not_modify_project(self):
        initial = self.snapshot()
        config = cmd(self.proj, 'config', '--list', '--local')
        self.make_patch()
        self.assertEqual(self.snapshot(), initial)
        self.assertEqual(config, cmd(self.proj, 'config', '--list', '--local'))
        self.assertEqual(cmd(self.proj, 'status', '--porcelain'), b'')

    def test_native_git_apply_and_reverse(self):
        initial = self.snapshot()
        _, patch = self.apply()
        self.assertIn(self.new.sha, (self.proj / '.agent-project-ops/PIN').read_text(encoding='utf-8'))
        self.assertEqual((self.proj / 'business.py').read_text(encoding='utf-8'), 'x = 42\n')
        self.assertEqual((self.proj / '.agent-project-ops/project-config').read_text(encoding='utf-8'), 'task_base=origin/develop\n')
        cmd(self.proj, 'apply', '--reverse', '--check', str(patch))
        cmd(self.proj, 'apply', '--reverse', str(patch))
        self.assertEqual(self.snapshot(), initial)

    def test_custom_suffix_preserved(self):
        f = self.proj / 'AGENTS.md'
        f.write_text(f.read_text(encoding='utf-8') + '\n# Project rules\nNever expose patient data.\n', encoding='utf-8')
        self.pcommit()
        self.apply()
        self.assertIn('Never expose patient data.', f.read_text(encoding='utf-8'))

    def test_custom_prefix_preserved(self):
        f = self.proj / 'AGENTS.md'
        f.write_text('# My project banner\n\n' + f.read_text(encoding='utf-8'), encoding='utf-8')
        self.pcommit()
        self.apply()
        self.assertTrue(f.read_text(encoding='utf-8').startswith('# My project banner'))

    def test_legacy_executable_mode_drift_on_nonfilemode_git(self):
        # Git for Windows commonly stores Bash-bootstrap scripts as 100644,
        # although the old methodology's render contract expects 100755.
        # Exact script contents still prove provenance; changed bytes must not.
        name = '.agent-project-ops/scripts/new-worktree.sh'
        expected = u.render(u.Source(self.src, self.old), {
            'PROJECT_NAME': 'project', 'DISPOSER': '@Test',
            'METHODOLOGY_URL': 'https://github.com/example/method',
            'METHODOLOGY_SHA': self.old, 'METHODOLOGY_REF': 'v0.1.2',
            'FETCHED_AT': '2026-01-01T00:00:00Z',
            'PROJECTION_REMOTE': '(none)',
        })[name]
        self.assertEqual(expected.mode, 0o755)
        cmd(self.proj, 'config', 'core.filemode', 'false')
        cmd(self.proj, 'update-index', '--chmod=-x', name)
        if cmd(self.proj, 'diff', '--cached', '--name-only'):
            cmd(self.proj, 'commit', '-m', 'simulate Windows old-mode metadata')
        self.assertIn(b'100644', cmd(self.proj, 'ls-files', '--stage', name))
        info, _ = self.preview()
        self.assertEqual(info['status'], 'PREVIEW')
        changed = self.proj / name
        changed.write_bytes(changed.read_bytes() + b'\n# unauthorized snapshot edit\n')
        cmd(self.proj, 'add', name)
        cmd(self.proj, 'commit', '-m', 'modify the vendor snapshot')
        with self.assertRaisesRegex(u.Stop, 'CUSTOM_SNAPSHOT'):
            self.preview()

    def test_custom_snapshot_conflicts(self):
        self.pput('.agent-project-ops/PRINCIPLES.md', 'Custom\n')
        self.pcommit()
        initial = self.snapshot()
        with self.assertRaisesRegex(u.Stop, 'CUSTOM_SNAPSHOT'):
            self.preview()
        self.assertEqual(initial, self.snapshot())

    def test_custom_root_conflicts(self):
        f = self.proj / 'AGENTS.md'
        f.write_text(f.read_text(encoding='utf-8').replace('- PIN: ' + self.old, '- PIN: untrusted'), encoding='utf-8')
        self.pcommit()
        with self.assertRaisesRegex(u.Stop, 'CUSTOM_RULE_CONFLICT'):
            self.preview()

    def test_dirty_project_refused(self):
        self.pput('business.py', 'x=43\n')
        with self.assertRaisesRegex(u.Stop, 'PROJECT_DIRTY'):
            self.preview()

    def test_plan_changes_with_project_head(self):
        a, _ = self.preview()
        self.pput('business.py', 'x=44\n')
        self.pcommit()
        b, _ = self.preview()
        self.assertNotEqual(a['plan_id'], b['plan_id'])

    def test_reverse_refuses_later_edit(self):
        _, patch = self.apply()
        self.pput('.agent-project-ops/PRINCIPLES.md', 'later editing\n')
        before = self.snapshot()
        proc = subprocess.run(['git', '-C', str(self.proj), 'apply', '--reverse', '--check', str(patch)], capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_idempotent_after_commit(self):
        self.apply()
        self.pcommit()
        p, changes = self.preview()
        self.assertEqual(p['status'], 'UP_TO_DATE')
        self.assertEqual(changes, {})

    def test_apply_precheck_is_all_or_nothing(self):
        _, patch = self.make_patch()
        self.pput('AGENTS.md', 'Conflicting whole file\n')
        before = self.snapshot()
        proc = subprocess.run(['git', '-C', str(self.proj), 'apply', '--check', str(patch)], capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_symlink_refused(self):
        p = self.proj / '.agent-project-ops/playbooks/start-project.md'
        p.unlink()
        try:
            p.symlink_to(self.proj / 'business.py')
        except OSError:
            self.skipTest('OS denies symlink creation')
        self.pcommit()
        with self.assertRaisesRegex(u.Stop, 'SYMLINK_REFUSED'):
            self.preview()

    def test_unknown_pin_refused(self):
        p = self.proj / '.agent-project-ops/PIN'
        p.write_text(p.read_text(encoding='utf-8').replace(self.old, 'a' * 40), encoding='utf-8')
        self.pcommit()
        with self.assertRaises(u.Stop):
            self.preview()

    def test_dirty_source_refused(self):
        self.put('extra.md', 'uncommitted')
        with self.assertRaisesRegex(u.Stop, 'SOURCE_DIRTY'):
            u.Source(self.src, 'HEAD', clean=True)

    def test_source_url_mismatch_refused(self):
        cmd(self.src, 'remote', 'set-url', 'origin', 'https://github.com/other/method')
        with self.assertRaisesRegex(u.Stop, 'SOURCE_URL_MISMATCH'):
            self.preview()

    def test_plan_id_stable(self):
        a, _ = self.preview()
        b, _ = self.preview()
        self.assertEqual(a['plan_id'], b['plan_id'])

    def test_crlf_owned_files_supported(self):
        cmd(self.proj, 'config', 'core.autocrlf', 'false')
        for p in self.proj.rglob('*'):
            if p.is_file() and '.git' not in p.relative_to(self.proj).parts:
                raw = p.read_bytes().replace(b'\r\n', b'\n')
                p.write_bytes(raw.replace(b'\n', b'\r\n'))
        self.pcommit()
        self.apply()
        self.assertIn(self.new.sha, (self.proj / '.agent-project-ops/PIN').read_text(encoding='utf-8'))

    def test_no_timestamp_replacement_in_snapshot_code(self):
        self.apply()
        self.assertIn('__APO_UPGRADE_TIME__', (self.proj / '.agent-project-ops/skills/upgrade-project/helper.py').read_text(encoding='utf-8'))

    def test_unowned_and_traversal_paths_refused(self):
        for path in ('../../escape', '.agent-project-ops/../escape', 'business.py', '/absolute/file'):
            with self.assertRaises(u.Stop):
                u.safe_rel(path)

    def test_corrupt_patch_not_applied(self):
        _, patch = self.make_patch()
        patch.write_text('invalid patch', encoding='utf-8')
        initial = self.snapshot()
        proc = subprocess.run(['git', '-C', str(self.proj), 'apply', '--check', str(patch)], capture_output=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertEqual(initial, self.snapshot())


if __name__ == '__main__':
    unittest.main()
