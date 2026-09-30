# local-team

本地团队插件市场。存放本单位自用约定，仓库托管在 GitHub 上，内容只服务本单位的使用场景。市场里四个插件互相独立，按项目情况挑着装。

| 插件 | 管什么 | 什么时候装 |
|---|---|---|
| `commit-guarding` | 版本控制工作流：SVN 与 git 两套提交流程的检查与硬闸门、commit 信息格式、命令速查、冲突与撤销踩坑 | 用 SVN 或 git 管的项目都装，按工作副本类型分流 |
| `comment-trimming` | 注释规范：稀疏优先、只讲本段代码、禁装饰、编辑文件时整文件顺手清干净、整目录批量清理的子代理 | 所有 Java / Vue 项目 |
| `chinese-writing` | 中文表达与理解：介词、量词、关联词、语序、术语、篇幅、禁符号代字与翻译腔 | 所有项目 |
| `mock-testing` | 拿桩把功能链路跑通的套路：划边界、抄契约、写桩、接管地址、三层验证、收尾还原，配四份可照抄模板 | 需要频繁在本地或测试环境复现链路问题的项目 |

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install commit-guarding@local-team
claude plugin install comment-trimming@local-team
claude plugin install chinese-writing@local-team
claude plugin install mock-testing@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install commit-guarding@local-team -s project
```

插件内容是复制到 `~/.claude/plugins/cache/local-team/<插件名>/<版本>/` 的，改源目录不会自动生效。更新内容走 `claude plugin marketplace update local-team` 加 `claude plugin update <插件名>@local-team`，之后重启会话（钩子在会话启动时加载）。

旧名字装过的，先卸掉再装新的——缓存目录按插件名分，改名的插件不会被自动接管：

```bash
claude plugin uninstall control-workflow@local-team
claude plugin uninstall comment-style@local-team
claude plugin install commit-guarding@local-team
claude plugin install comment-trimming@local-team
```

更早的两个旧名（`svn-team-conventions`、`svn-workflow`）同样先卸后装。

## 使用

技能多数会自动触发，也可以显式调用：

```
/commit-guarding:svn-commit          走一遍 SVN 提交流程
/commit-guarding:git-commit          走一遍 git 提交流程
/comment-trimming:comment-trimming   走一遍注释规范
/chinese-writing:chinese-writing     走一遍中文表达规范
/mock-testing:mock-testing           走一遍拿桩跑通链路的流程
```

各插件目录下另有自己的 README，讲该插件的用法。
