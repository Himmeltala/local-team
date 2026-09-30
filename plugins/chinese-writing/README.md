# chinese-writing

中文表达与理解规范插件：约束助手写中文的方式，以及读中文需求的方式。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `chinese-writing` | 技能 | 中文产出九条（介词、量词、关联词、语序、术语、符号代字、中英空格、禁翻译腔）；篇幅标准（回复、注释、提交信息、文档）；读中文需求的歧义确认 |
| SessionStart 提醒 | 钩子 | 会话开始时注入中文约定 |

技能内另有三份参考：`symbols-and-grammar.md` 管符号与语法，`translationese.md` 管翻译腔对照，`reading-chinese.md` 管读需求。

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install chinese-writing@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install chinese-writing@local-team -s project
```

插件内容是复制到缓存目录的，改源目录不会自动生效。更新内容走 `claude plugin marketplace update local-team` 加 `claude plugin update chinese-writing@local-team`，之后重启会话（钩子在会话启动时加载）。

## 使用

技能会在写注释、写文档、写提交信息时自动触发，也可以显式调用：

- 说"这句话中文不通""缺介词""符号别当代替""这是翻译腔" —— 触发规则
- `/chinese-writing:chinese-writing` —— 显式走一遍规则

篇幅数值（回复精简、注释一行最多两行、提交信息一行、文档不限长）只写在本插件的篇幅标准里，`comment-trimming` 与 `commit-guarding` 只指认。
