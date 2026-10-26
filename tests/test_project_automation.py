"""GitHub boundary fixtures; no real writes or credentials."""
import argparse
import contextlib
import copy
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/project-automation.py'
spec = importlib.util.spec_from_file_location('automation', SCRIPT)
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


def issue(number, kind, status, body='', state='open'):
    return dict(number=number, title='Fixture', state=state, body=body,
                labels=[{'name': 'type:' + kind}, {'name': 'status:' + status}],
                html_url=f'https://github.com/example/test/issues/{number}', created_at='2026-01-01')


def scope(*lines):
    return '<!-- apo-file-scope v1 -->\n' + '\n'.join(lines) + '\n<!-- /apo-file-scope -->'


class FakeGitHub:
    repo = 'example/test'

    def __init__(self):
        self.data = {'issues/10': issue(10, 'command-center', 'in-progress',
                     '# unchanged prefix\n\n## 1. 一眼状态\n\nold\n\n## 阶段索引\n\n| #20 | fixture |\n\n## Tail\nkeep | bytes\n'),
                     'issues/20': issue(20, 'phase', 'verification'),
                     'issues/10/comments?per_page=100': [], 'issues/20/comments?per_page=100': []}
        self.writes = []

    def api(self, path, *, data=None, pages=False):
        if data is not None:
            self.writes.append((path, data))
            self.data[path].update(data)
        return copy.deepcopy(self.data[path])


class AutomationTests(unittest.TestCase):
    def setUp(self):
        self.gh = FakeGitHub()
        self.args = argparse.Namespace(cc=10, phase=20, recent='PR #21 已合并',
                  blocker='无', next_action='等待最终验收', tidy='apo-tidy: failed=0',
                  apply=False, expect_plan='')
        self.output = io.StringIO()
        self.capture = contextlib.redirect_stdout(self.output)
        self.capture.__enter__()
        self.addCleanup(self.capture.__exit__, None, None, None)

    def test_preview_no_write_then_apply_preserves_other_sections(self):
        token, section, before, after = a.status_plan(self.gh, self.args)
        self.assertIn('待验收', section)
        self.assertNotIn('PASS', section)
        a.update_status(self.gh, self.args)
        self.assertEqual(self.gh.writes, [])
        self.args.apply, self.args.expect_plan = True, token
        a.update_status(self.gh, self.args)
        self.assertEqual(self.gh.writes, [('issues/10', {'body': after})])
        start, end = a.first_section(before)
        self.assertTrue(after.startswith(before[:start]))
        self.assertTrue(after.endswith(before[end:]))

    def test_stale_control_plane_and_no_confirmation_refuse_without_write(self):
        self.args.apply = True
        with self.assertRaisesRegex(a.Invalid, 'STALE_PLAN'):
            a.update_status(self.gh, self.args)
        self.args.expect_plan = a.status_plan(self.gh, self.args)[0]
        self.gh.data['issues/20']['body'] = 'concurrent contract change'
        with self.assertRaisesRegex(a.Invalid, 'STALE_PLAN'):
            a.update_status(self.gh, self.args)
        self.assertEqual(self.gh.writes, [])

    def test_change_between_confirmation_and_patch_refuses(self):
        self.args.apply = True
        self.args.expect_plan = a.status_plan(self.gh, self.args)[0]
        original = self.gh.api
        counts = []
        def changing(path, **kwargs):
            if path == 'issues/10':
                counts.append(path)
                if len(counts) == 2:
                    self.gh.data[path]['body'] += 'concurrent edit'
            return original(path, **kwargs)
        self.gh.api = changing
        with self.assertRaisesRegex(a.Invalid, 'STALE_PLAN'):
            a.update_status(self.gh, self.args)
        self.assertEqual(self.gh.writes, [])

    def test_bad_status_and_absent_index_refuse(self):
        self.gh.data['issues/20']['state'] = 'closed'
        with self.assertRaises(a.Invalid):
            a.status_plan(self.gh, self.args)
        self.gh.data['issues/20']['state'] = 'open'
        self.gh.data['issues/10']['body'] = '## 1. 一眼状态\n\n## 阶段索引\n#200\n'
        with self.assertRaises(a.Invalid):
            a.status_plan(self.gh, self.args)

    def test_latest_revision_only_and_first_line_markers(self):
        def request(rev):
            return {'body': f'<!-- apo-decision v1 | id: D-17 | rev: {rev} | type: 最终验收 | target: #20 | disposer: @human -->\n正文',
                    'html_url': 'https://example.test/request/' + str(rev), 'created_at': '2026-01-01', '_apo_issue': 20}
        result = {'body': '<!-- apo-decision-result v1 | id: D-17 | rev: 1 | result: 批准 A | reply: 对话 -->', 'created_at': '2026-01-02', '_apo_issue': 20}
        self.assertEqual(a.pending_decisions([request(1), result], 20), '无')
        pending = a.pending_decisions([request(1), result, request(2)], 20)
        self.assertIn('rev 2', pending)
        self.assertNotIn('rev 1', pending)
        quoted = request(3)
        quoted['body'] = '```markdown\n' + quoted['body'] + '\n```'
        self.assertEqual(a.pending_decisions([quoted], 20), '无')

    def test_result_in_other_discussion_cannot_settle_request(self):
        request = {'body': '<!-- apo-decision v1 | id: D-17 | rev: 1 | type: 最终验收 | target: #20 | disposer: @human -->',
                   'html_url': 'https://example.test/request', 'created_at': '2026-01-01'}
        result = {'body': '<!-- apo-decision-result v1 | id: D-17 | rev: 1 | result: 批准 A | reply: 对话 -->',
                  'created_at': '2026-01-02'}
        for request_thread, result_thread in ((10, 20), (20, 10)):
            request['_apo_issue'], result['_apo_issue'] = request_thread, result_thread
            self.assertIn('D-17 rev 1', a.pending_decisions([request, result], 20))
        result['_apo_issue'] = request['_apo_issue']
        self.assertEqual(a.pending_decisions([request, result], 20), '无')

    def test_latest_revision_retargets_before_phase_filter(self):
        def request(rev, target):
            return {'body': f'<!-- apo-decision v1 | id: D-17 | rev: {rev} | type: 最终验收 | target: #{target} | disposer: @human -->',
                    'html_url': f'https://example.test/request/{rev}', 'created_at': f'2026-01-0{rev}', '_apo_issue': 10}
        records = [request(1, 20), request(2, 21)]
        self.assertEqual(a.pending_decisions(records, 20), '无')
        self.assertIn('rev 2', a.pending_decisions(records, 21))
        records.append(request(3, 20))
        self.assertIn('rev 3', a.pending_decisions(records, 20))
        self.assertEqual(a.pending_decisions(records, 21), '无')

    def test_duplicate_revision_cannot_hide_a_request_in_another_discussion(self):
        request = {'body': '<!-- apo-decision v1 | id: D-17 | rev: 1 | type: 最终验收 | target: #20 | disposer: @human -->',
                   'html_url': 'https://example.test/request', 'created_at': '2026-01-01', '_apo_issue': 10}
        result = {'body': '<!-- apo-decision-result v1 | id: D-17 | rev: 1 | result: 批准 A | reply: 对话 -->',
                  'created_at': '2026-01-02', '_apo_issue': 10}
        for other in ({**request, '_apo_issue': 20}, {**request, 'body': request['body'].replace('#20', '#21')}, dict(request)):
            with self.assertRaisesRegex(a.Invalid, 'duplicate formal decision'):
                a.pending_decisions([request, other, result], 20)

    def test_dispatch_file_directory_case_and_segment_boundaries(self):
        self.gh.data['issues/30'] = issue(30, 'task', 'backlog', scope('file: src/auth/login.py'))
        task = issue(31, 'task', 'in-progress', scope('dir: SRC/auth/'))
        self.gh.data['issues?state=open&labels=type%3Atask&per_page=100'] = [task]
        self.assertEqual(a.dispatch_check(self.gh, 30), 3)
        self.assertIn('#31', self.output.getvalue())
        task['body'] = scope('dir: src/auth-old/')
        self.assertEqual(a.dispatch_check(self.gh, 30), 0)
        task['body'] = scope('file: src/auth/login.py')
        self.assertEqual(a.dispatch_check(self.gh, 30), 3)
        self.assertEqual(self.gh.writes, [])

    def test_dispatch_unknown_active_scope_is_not_no_conflict(self):
        self.gh.data['issues/30'] = issue(30, 'task', 'backlog', scope('dir: src/'))
        task = issue(31, 'task', 'in-progress')
        self.gh.data['issues?state=open&labels=type%3Atask&per_page=100'] = [task]
        self.assertEqual(a.dispatch_check(self.gh, 30), 2)
        task['labels'] = [{'name': 'type:task'}, {'name': 'status:backlog'}]
        self.assertEqual(a.dispatch_check(self.gh, 30), 0)

    def test_unsafe_empty_duplicate_scope_and_mentions(self):
        for line in ('file: ../outside', 'dir: /tmp', 'file: C:/temp', 'dir: src\\auth',
                     'file: src/*.py', 'dir: src//auth', 'file: ./safe', 'file: src/file/'):
            with self.subTest(line=line), self.assertRaises(a.Invalid):
                a.file_scope(scope(line))
        for body in (scope(), scope('file: x', 'file: x'), 'no block'):
            with self.assertRaises(a.Invalid):
                a.file_scope(body)
        for text in ('@codex', '引文 @some-review[bot]'):
            with self.assertRaises(a.Invalid):
                a.one_line(text, 'quote')
        self.assertEqual(a.one_line('at codex；@human', 'quote'), 'at codex；@human')

    def test_batch_candidates_and_invalid_open_task_status_fail_closed(self):
        self.gh.data['issues/30'] = issue(30, 'task', 'backlog', scope('dir: src/'))
        self.gh.data['issues/31'] = issue(31, 'task', 'backlog', scope('file: src/file.py'))
        listing = 'issues?state=open&labels=type%3Atask&per_page=100'
        self.gh.data[listing] = []
        self.assertEqual(a.dispatch_check(self.gh, [30, 31]), 3)
        other = issue(32, 'task', 'in-progress', scope('file: unrelated'))
        self.gh.data[listing] = [other]
        for labels in ([], [{'name': 'status:unknown'}], [{'name': 'status:backlog'}, {'name': 'status:verification'}]):
            other['labels'] = labels
            self.assertEqual(a.dispatch_check(self.gh, 30), 2)
        self.gh.data['issues/30']['labels'][1]['name'] = 'status:verification'
        with self.assertRaises(a.Invalid):
            a.dispatch_check(self.gh, 30)

    def test_malformed_formal_request_does_not_hide_pending(self):
        with self.assertRaisesRegex(a.Invalid, 'requires target'):
            a.pending_decisions([{'body': '<!-- apo-decision v1 | id: D-17 | rev: 1 | type: 最终验收 -->'}], 20)

    def test_cli_rejects_missing_parameters_and_api_error_no_write(self):
        result = subprocess.run([sys.executable, str(SCRIPT), 'status'], capture_output=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn(b'--cc', result.stderr)
        with mock.patch.object(a, 'run', side_effect=a.Invalid('API unavailable')):
            with self.assertRaises(a.Invalid):
                a.GitHub('example/test').api('issues/10')

    def test_cli_uses_worktree_authority_before_any_github_api(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            subprocess.run(['git', '-C', str(root), 'remote', 'add', 'origin',
                            'https://github.com/Example/Test.git'], check=True)
            registry = root / '.agent-project-ops' / 'remotes'
            registry.parent.mkdir()
            registry.write_text('# approved\nauthority=origin\n', encoding='utf-8')

            def cli():
                with mock.patch.object(sys, 'argv', [str(SCRIPT), '--root', str(root),
                                                     'dispatch-check', '--task', '30']):
                    return a.main()

            calls = []
            def api(_self, path, **_kwargs):
                calls.append(path)
                raise a.Invalid('fixture API boundary')

            with mock.patch.object(a.GitHub, 'api', api):
                self.assertEqual(cli(), 2)
                self.assertEqual(calls, ['issues/30'])
                calls.clear()

                cases = {
                    'extra remote': lambda: subprocess.run(['git', '-C', str(root), 'remote', 'add',
                        'backup', 'https://github.com/Example/Other.git'], check=True),
                    'export entry': lambda: registry.write_text('authority=origin\nexport=backup\n', encoding='utf-8'),
                    'missing registry': lambda: registry.unlink(),
                    'mirror': lambda: subprocess.run(['git', '-C', str(root), 'config',
                        'remote.origin.mirror', 'true'], check=True),
                }
                for label, setup in cases.items():
                    with self.subTest(label=label):
                        registry.write_text('authority=origin\n', encoding='utf-8')
                        subprocess.run(['git', '-C', str(root), 'remote', 'remove', 'backup'],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                        subprocess.run(['git', '-C', str(root), 'config', '--unset',
                                        'remote.origin.mirror'], stdout=subprocess.DEVNULL,
                                       stderr=subprocess.DEVNULL)
                        setup()
                        self.assertEqual(cli(), 2)
                        self.assertEqual(calls, [], label)
                if hasattr(os, 'symlink'):
                    registry.write_text('authority=origin\n', encoding='utf-8')
                    subprocess.run(['git', '-C', str(root), 'config', '--unset',
                                    'remote.origin.mirror'], stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL)
                    registry.unlink()
                    (root / 'outside-remotes').write_text('authority=origin\n', encoding='utf-8')
                    try:
                        registry.symlink_to(root / 'outside-remotes')
                    except (OSError, NotImplementedError):
                        pass
                    else:
                        with self.subTest(label='symlink registry'):
                            self.assertEqual(cli(), 2)
                            self.assertEqual(calls, [])


if __name__ == '__main__':
    unittest.main()
