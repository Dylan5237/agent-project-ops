# Examples / 示例（外链 only）

This directory **does not** vendor business code, SOP, or stage graphs.

Use public/external repositories as **pattern illustrations**: Command Center issue, Phase issues, split implementation vs evidence PRs. The methodology in the parent repo stays generic.

## Illustration: req-to-page

- Repository: [https://github.com/Dylan5237/req-to-page](https://github.com/Dylan5237/req-to-page)
- Look there for a **Project Command Center** issue (title along the lines of `Command Center` / `项目指挥中心`) and Phase issues that freeze a contract before implementation.

Treat that repo as **someone else’s product**. Do not copy its domain docs, runtime, or application tree into `agent-project-ops`. If the link is private or missing, ignore it — playbooks still apply to any business git repo.

## What to copy vs not

| Copy into a business repo | Never copy into this methodology repo |
| --- | --- |
| Issue/PR **habits** (index issue, freeze comments, evidence table) | Product SOP, domain models, vendor/runtime docs |
| Optional `.github` templates from `templates/` | Application source or `package.json` from examples |
