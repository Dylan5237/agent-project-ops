"""Isolated local Git fixtures; no network or user repositories are used."""
import importlib.util
import os
import sys
import subprocess
import tempfile
from pathlib import Path
import unittest
from unittest import mock

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
        # The production helper strips GIT_* variables; temporary user paths
        # also isolate its children from global URL rewrites and includeIf.
        git_home = self.base / 'git-home'
        git_xdg = self.base / 'git-xdg'
        git_home.mkdir()
        git_xdg.mkdir()
        git_env = mock.patch.dict(os.environ, {
            'HOME': str(git_home), 'USERPROFILE': str(git_home),
            'XDG_CONFIG_HOME': str(git_xdg),
            'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_NOSYSTEM': '1',
        })
        git_env.start()
        self.addCleanup(git_env.stop)
        self.src = self.base / 'method'
        self.src.mkdir()
        cmd(self.src, 'init', '-b', 'main')
        cmd(self.src, 'config', 'core.autocrlf', 'false')
        cmd(self.src, 'config', 'user.email', 'test@example.invalid')
        cmd(self.src, 'config', 'user.name', 'Test')
        cmd(self.src, 'remote', 'add', 'origin', 'https://github.com/example/method')
        self.put('PRINCIPLES.md', 'Old rules\n')
        self.put('LICENSE', 'MIT\n')
        self.put('scripts/bootstrap-project.sh', '#!/bin/bash\n# old bootstrap\n')
        self.put('scripts/new-worktree.sh', '#!/bin/bash\n# old worktree helper\n')
        self.put('templates/AGENTS.md', '# {{PROJECT_NAME}} — project operations binding\n\n- Disposer: {{DISPOSER}}\n- PIN: {{METHODOLOGY_SHA}}\n- Date: {{FETCHED_AT}}\n')
        self.put('templates/CLAUDE.md', '@AGENTS.md\n')
        self.put('templates/cursor-rules/agent-project-ops.mdc', 'Old Cursor adapter reads AGENTS.md\n')
        self.put('templates/github/copilot-instructions.md', 'Old Copilot adapter reads AGENTS.md\n')
        self.put('templates/aider.conf.yml', 'read: AGENTS.md\n')
        self.put('templates/continue-rules/agent-project-ops.md', 'Old Continue adapter reads AGENTS.md\n')
        self.put('templates/gitignore-agent-ops', '.worktrees/\n')
        self.put('templates/gitattributes-agent-ops', '*.sh text eol=lf\n')
        self.put('templates/ISSUE_TEMPLATE/command-center.md', 'Personal Fleet registration REQUIRED\n')
        self.put('skills/bootstrap-project/SKILL.md', '---\nname: bootstrap-project\ndescription: Test\n---\n\nOld Fleet rule\n')
        self.put('playbooks/start-project.md', 'Old Fleet requirement\n')
        for name in ('share-export.sh', 'export-sync.sh', 'lib/share-export-denylist.sh', 'lib/export-strip-list.sh'):
            self.put('scripts/' + name, '#!/bin/bash\n# old helper\n')
        self.commit()
        self.old = cmd(self.src, 'rev-parse', 'HEAD').decode().strip()
        self.proj = self.base / 'project'
        self.proj.mkdir()
        cmd(self.proj, 'init', '-b', 'main')
        cmd(self.proj, 'config', 'core.autocrlf', 'false')
        cmd(self.proj, 'config', 'user.email', 'test@example.invalid')
        cmd(self.proj, 'config', 'user.name', 'Test')
        cmd(self.proj, 'remote', 'add', 'origin', 'https://github.com/example/project')
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
        for name in (
            'templates/cursor-rules/agent-project-ops.mdc',
            'templates/github/copilot-instructions.md',
            'templates/aider.conf.yml',
            'templates/continue-rules/agent-project-ops.md',
            'scripts/share-export.sh', 'scripts/export-sync.sh',
            'scripts/lib/share-export-denylist.sh', 'scripts/lib/export-strip-list.sh',
        ):
            (self.src / name).unlink()
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

    def assert_origin_refusal_preserves_state(self, reason):
        config = (self.proj / '.git/config').read_bytes()
        files = self.snapshot()
        status = cmd(self.proj, 'status', '--porcelain')
        head = cmd(self.proj, 'rev-parse', 'HEAD')
        index = cmd(self.proj, 'ls-files', '--stage', '-z')
        with self.assertRaisesRegex(u.Stop, reason):
            self.preview()
        self.assertEqual((self.proj / '.git/config').read_bytes(), config)
        self.assertEqual(self.snapshot(), files)
        self.assertEqual(cmd(self.proj, 'status', '--porcelain'), status)
        self.assertEqual(cmd(self.proj, 'rev-parse', 'HEAD'), head)
        self.assertEqual(cmd(self.proj, 'ls-files', '--stage', '-z'), index)

    def test_origin_missing_refused_without_modifying_config(self):
        cmd(self.proj, 'remote', 'remove', 'origin')
        self.assert_origin_refusal_preserves_state('ORIGIN_REMOTE_MISSING')

    def test_non_github_pushurl_refused_without_modifying_config(self):
        cmd(self.proj, 'remote', 'set-url', '--push', 'origin',
            'https://gitlab.example/team/project.git')
        self.assert_origin_refusal_preserves_state('ORIGIN_URL_UNSAFE')

    def test_different_github_pushurl_refused_without_modifying_config(self):
        cmd(self.proj, 'remote', 'set-url', '--push', 'origin',
            'git@github.com:example/other-project.git')
        self.assert_origin_refusal_preserves_state('ORIGIN_URL_MISMATCH')

    def test_multiple_fetch_urls_must_name_same_repository(self):
        cmd(self.proj, 'config', '--add', 'remote.origin.url',
            'ssh://git@github.com/example/other-project.git')
        self.assert_origin_refusal_preserves_state('ORIGIN_URL_MISMATCH')

    def test_non_github_fetch_url_refused_without_modifying_config(self):
        cmd(self.proj, 'config', '--add', 'remote.origin.url',
            'https://gitlab.example/team/project.git')
        self.assert_origin_refusal_preserves_state('ORIGIN_URL_UNSAFE')

    def test_unsafe_origin_url_forms_refused_without_modifying_config(self):
        unsafe_urls = (
            'https://github.com:443/example/project',
            'https://user:secret@github.com/example/project',
            'https://github.com/example/project?token=secret',
            'https://github.com/example/project/extra',
            'ssh://user:secret@github.com/example/project',
            'git@github.com:../project',
            'git@github.com:example/..',
            'https://github.com/example/project\nhttps://github.com/example/project',
        )
        for url in unsafe_urls:
            with self.subTest(url=url):
                cmd(self.proj, 'remote', 'set-url', '--push', 'origin', url)
                self.assert_origin_refusal_preserves_state('ORIGIN_URL_UNSAFE')

    def test_instead_of_rewrite_is_validated_after_expansion(self):
        cmd(self.proj, 'config', 'url.https://evil.example/.insteadOf',
            'https://github.com/')
        self.assertEqual(
            cmd(self.proj, 'remote', 'get-url', '--all', 'origin').decode().strip(),
            'https://evil.example/example/project')
        self.assert_origin_refusal_preserves_state('ORIGIN_URL_UNSAFE')

    def test_equivalent_github_protocols_and_multiple_urls_are_allowed(self):
        cmd(self.proj, 'remote', 'set-url', 'origin',
            'https://GitHub.com/Example/Project.git/')
        cmd(self.proj, 'config', '--add', 'remote.origin.url',
            'ssh://git@github.com/example/project/')
        cmd(self.proj, 'config', '--add', 'remote.origin.pushurl',
            'git@github.com:EXAMPLE/PROJECT.GIT')
        cmd(self.proj, 'config', '--add', 'remote.origin.pushurl',
            'https://github.com/example/project/')
        self.assertEqual(u.validate_origin_urls(self.proj), ('example', 'project'))
        info, _ = self.preview()
        self.assertEqual(info['status'], 'PREVIEW')

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
        for retired in (
            '.cursor/rules/agent-project-ops.mdc', '.github/copilot-instructions.md',
            '.aider.conf.yml', '.continue/rules/agent-project-ops.md',
            '.agent-project-ops/scripts/share-export.sh', '.agent-project-ops/scripts/export-sync.sh',
            '.agent-project-ops/scripts/lib/share-export-denylist.sh',
            '.agent-project-ops/scripts/lib/export-strip-list.sh',
        ):
            self.assertFalse((self.proj / retired).exists(), retired)
        self.assertTrue((self.proj / '.agents/skills/upgrade-project/SKILL.md').is_file())
        self.assertTrue((self.proj / '.claude/skills/upgrade-project/SKILL.md').is_file())
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

    def test_custom_retired_adapter_conflicts_with_deletion(self):
        adapter = self.proj / '.aider.conf.yml'
        adapter.write_text(adapter.read_text(encoding='utf-8') + 'read: LOCAL_POLICY.md\n', encoding='utf-8')
        self.pcommit()
        initial = self.snapshot()
        with self.assertRaisesRegex(u.Stop, r'OWNERSHIP_CONFLICT: \.aider\.conf\.yml'):
            self.preview()
        self.assertEqual(initial, self.snapshot())

    def test_active_legacy_remote_role_blocks_upgrade(self):
        self.pput('.agent-project-ops/remotes',
                  'authority=origin\nprojection=projection\nprojection_url=https://gitlab.example/team/project.git\n')
        cmd(self.proj, 'remote', 'add', 'projection', 'https://gitlab.example/team/project.git')
        self.pcommit()
        with self.assertRaisesRegex(u.Stop, 'LEGACY_REMOTE_ROLE_ACTIVE'):
            self.preview()

    def test_extra_remote_blocks_upgrade_even_without_legacy_role(self):
        cmd(self.proj, 'remote', 'add', 'extra', 'https://example.invalid/team/project.git')
        with self.assertRaisesRegex(u.Stop, 'EXTRA_REMOTE_UNSUPPORTED'):
            self.preview()

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

    def test_up_to_date_still_refuses_extra_remote(self):
        self.apply()
        self.pcommit()
        cmd(self.proj, 'remote', 'add', 'legacy', 'https://gitlab.example/team/project.git')
        self.assert_origin_refusal_preserves_state('EXTRA_REMOTE_UNSUPPORTED')

    def test_up_to_date_still_refuses_active_legacy_role(self):
        self.apply()
        self.pput('.agent-project-ops/remotes', 'authority=origin\nprojection=legacy\n')
        self.pcommit()
        self.assert_origin_refusal_preserves_state('LEGACY_REMOTE_ROLE_ACTIVE')

    def test_up_to_date_still_refuses_non_origin_authority(self):
        self.apply()
        self.pput('.agent-project-ops/remotes', 'authority=legacy\n')
        self.pcommit()
        self.assert_origin_refusal_preserves_state('AUTHORITY_UNSUPPORTED')

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
