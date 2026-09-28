# local-team

本地团队插件市场。存放本单位自用约定，仓库托管在 GitHub 上，内容只服务本单位的使用场景。市场里四个插件互相独立，按项目情况挑着装。

| 插件 | 管什么 | 什么时候装 |
|---|---|---|
| `control-workflow` | 版本控制工作流：SVN 与 git 两套提交流程的检查与硬闸门、commit 信息格式、命令速查、冲突与撤销踩坑 | 用 SVN 或 git 管的项目都装，按工作副本类型分流 |
| `comment-style` | 注释规范：稀疏优先、禁装饰、编辑文件时整文件顺手清干净、整目录批量清理的子代理 | 所有 Java / Vue 项目 |
| `chinese-writing` | 中文表达与理解：介词、量词、关联词、语序、术语、禁符号代字、中英混排空格 | 所有项目 |
| `mock-testing` | 拿桩把功能链路跑通的套路：划端、抄契约、写桩、接管地址、三层验证、收尾还原，配四份可照抄模板 | 需要频繁在本地或测试环境复现链路问题的项目 |

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install control-workflow@local-team
claude plugin install comment-style@local-team
claude plugin install chinese-writing@local-team
claude plugin install mock-testing@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install control-workflow@local-team -s project
```

改完插件内容后需要重启会话生效（钩子在会话启动时加载）。

## 目录结构

```
local-team/
├── .claude-plugin/marketplace.json   市场清单，声明四个插件
└── plugins/
    ├── control-workflow/   版本控制工作流（技能、提交闸门钩子、验收测试）
    ├── comment-style/      注释规范（技能、comment-trimmer 子代理）
    ├── chinese-writing/    中文表达与理解（技能）
    └── mock-testing/       拿桩跑通链路（技能、四份模板脚本）
```

每个插件目录下都有自己的 README 与 `docs/maintainer-notes.md`。技能、子代理、钩子都按插件独立加载，互不引用对方的文件。

## 维护

市场工作副本在 `~/projs/自用项目/local-team`，整个市场是一个 git 仓库，远端在 GitHub：

```
git@github.com:Himmeltala/local-team.git
```

安装时文件是**复制**到 `~/.claude/plugins/cache/local-team/<插件名>/<版本>/` 的，改源目录不会自动生效。改完内容后：

1. 提高对应插件 `.claude-plugin/plugin.json` 里的 `version`。版本号不变时 `claude plugin update` 会判定"已是最新"而不重新复制，这一步不能省。
2. `git add -A && git commit -m "<type>: <说明>" && git push` —— 内容必须先到远端，本地文件不参与安装。
3. `claude plugin marketplace update local-team` —— 重新 clone 市场仓库，刷新目录清单。
4. `claude plugin update <插件名>@local-team`
5. 重启 Claude Code 会话（钩子只在会话启动时加载）。

拉取走 HTTPS（`https://github.com/Himmeltala/local-team.git`），推送走 SSH（`git@github.com:Himmeltala/local-team.git`）。`marketplace add` 对 GitHub 认 `owner/repo` 简写，直接写 `ssh://` 地址会被判成非法格式。

只改某个插件 `hooks/session-rules.txt` 的提示语时，也可以直接编辑缓存目录里那份并重启会话，跳过第 2 到第 4 步；但下次更新会被覆盖，源目录要同步改并推送。

旧名字装过的，先卸掉再装新的：

```bash
claude plugin uninstall svn-team-conventions@local-team
claude plugin uninstall svn-workflow@local-team
```
