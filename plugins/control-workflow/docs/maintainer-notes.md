# 维护笔记

README 只讲插件是什么、怎么装、怎么用。这份文件放维护者的东西：内部判据、改动时要跑什么。

## 提交信息格式的依据

前缀与半角冒号取自 `svn log` 实例；**单行、简短**是团队现行规定，历史提交里的多行正文是旧做法。

## 调整约定

- 会话常驻提醒的正文在 `hooks/session-rules.txt`，保持简短——每次会话都会占用上下文。当前 592 字符。上限是 10000 字符，超了会被换成文件路径加预览，等于失效。
- 提交闸门在 `hooks/scripts/commit-guard.sh`，三条判据：落后与冲突靠 `svn status --xml -u` 的两个元素——`item="conflicted"`（含树冲突）和 `<repos-status>`（落后服务器），后者只在远端与本地真的有差异时才出现，本地 `add` / `delete` / 改内容都不会产生，所以不会误拦正常提交；范围括号只看命令行文本，不碰工作副本。误拦是比漏拦更坏的故障——写判据时先想清楚这点。信息格式的判据锚行首（`^(type)[[:space:]]*\(`），所以描述里的半角括号（`fix: 统计接口(含下级)补齐`）和全角括号不受影响。改这条判据时，把这几条放行用例一并跑一遍。
- 闸门解析钩子输入依赖 `python3`，退而求其次用 `jq`，两者都没有时**静默放行**。这是有意的取舍：钩子是加在提交路径上的，它自己出故障不能把人堵在提交外面。要确认闸门在不在，直接喂一条假输入试：`echo '{"tool_name":"Bash","cwd":"<工作副本>","tool_input":{"command":"svn commit -m x"}}' | bash hooks/scripts/commit-guard.sh; echo $?`，落后或有冲突时应当得到 2；把 `-m x` 换成 `-m "feat(a): x"`，在干净工作副本里也应当得到 2。
- 改闸门判定逻辑后跑一遍验收测试：`bash tests/commit-guard.test.sh hooks/scripts/commit-guard.sh`。它每次在 `/tmp/svnguard` 下重建临时版本库，造出「落后」「冲突」「已 resolve」等真实状态，不碰任何真实工作副本，31 个用例应当全绿。建库阶段任何一步失败会直接中止并报 `FIXTURE`，不会带着坏 fixture 跑出假绿。
- 钩子用纯文本 stdout 输出。Claude Code 对 SessionStart 事件会把 plain stdout 注入上下文（官方 hooks 文档 exit-code-0 一节）；输出以 `{` 开头会被当 JSON 解析，所以正文里不要让第一行以 `{` 开头。
- 将来加 git 提交流程时，写在 `skills/git-commit/` 下，与 `svn-commit` 并列；闸门判据另写一份，不要往 `commit-guard.sh` 里塞 git 的分支。
- 新增约定条目时先核对存量代码，确认是"团队实际这么干"再写进去。写进插件的规则会被当成事实执行。
