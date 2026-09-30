# bug-tracing

问题排查插件：现象不对、结果不符预期、数据没生效时，按"先代码后数据"的顺序，定位到第一处不符合预期的地方。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `bug-tracing` | 技能 | 排查六步：定界、读调用链、查数据源、连库取证、证据对齐、给结论 |
| `references/tracing.md` | 参考 | 定界三问、调用链怎么读、代码看着没问题的常见假象 |
| `references/data-source.md` | 参考 | 数据源疑点清单、连库取证流程、写 SQL 前要确认的库类型 |

技能按需触发，不注入会话，没有钩子与子代理。

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install bug-tracing@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install bug-tracing@local-team -s project
```

## 使用

说"排查一下"、"这个接口不对"、"数据不对"、"为什么没生效"、"查一下问题"、"定位一下"时自动触发，也可以显式调用：

- `/bug-tracing:bug-tracing` —— 走一遍排查六步

两条边界写在技能里：数据库只跑 `SELECT`，连库前先问清环境、库名与库类型；排查结论只在会话里给，不自动落盘，要留档时另行说明。
