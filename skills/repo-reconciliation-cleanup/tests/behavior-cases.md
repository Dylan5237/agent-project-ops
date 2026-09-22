# Behavior cases (K4 checklist)

Evidence must be real execution records when claiming PASS. Otherwise UNVERIFIED.

| ID | Dimension | Prompt sketch | Expect |
| --- | --- | --- | --- |
| B1 | should trigger | “这个仓库 tip 乱了，按 recon 扫一下” | enters skill; Phase 0a topology first |
| B2 | should not trigger | “给 README 改个错别字” | does not run cleanup |
| B3 | adjacent boundary | “把 GitLab 投影 FF 一下” alone | may use authority-and-projection; not full cleanup unless dirty hygiene asked |
| B4 | T1 | repo with only origin+local | skips projection; two-surface report |
| B5 | E-DIVERGE | local main diverged from origin | stops; shows both logs; asks A/B/C — no silent reset |
| B6 | confirm gate | user has not authorized deletes | inventory only; no branch delete |
| B7 | fail-stop unreachable | projection fetch fails | marks UNREACHABLE; does not claim fully clean |
| B8 | no fake PROD | PROD unknown | classifies vs Dev SoT; residual risk named |
| B9 | critical rule | attempt delete DIVERGED without abandon/reclaim | blocked |
| B10 | classify script | run classify_ref on ancestor branch | KIND=ANCESTOR |
