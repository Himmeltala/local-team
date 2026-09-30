# code-shaping

编码思维插件：写代码、改代码之前先想复用与拆分，写完不留重复与过长函数，同时不许过度抽象。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `code-shaping` | 技能 | 判断清单：复用优先、一个函数一件事、过长就拆、胶水代码泛化、模式用得其所、不许过度抽象 |
| `references/splitting.md` | 参考 | 该拆的信号、怎么拆、拆到什么程度、设计模式的位置 |
| `references/reuse-first.md` | 参考 | 动手前搜什么、该不该复用的判断表、通用工具的落点 |
| `references/thinking.md` | 参考 | 命名、一层抽象、状态、副作用、错误、边界、依赖方向等条目 |
| SessionStart 提醒 | 钩子 | 会话开始时注入编码思维约定 |

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install code-shaping@local-team
```

只想在部分项目里启用时，在该项目目录下加 `-s project` 装到项目级：

```bash
claude plugin install code-shaping@local-team -s project
```

插件内容是复制到缓存目录的，改源目录不会自动生效。更新内容走 `claude plugin marketplace update local-team` 加 `claude plugin update code-shaping@local-team`，之后重启会话（钩子在会话启动时加载）。

## 使用

写代码时自动遵守，也可以显式调用：

- 说"这段代码怎么拆"、"写得太长了"、"能不能复用"、"这里要不要上设计模式" —— 触发规则
- `/code-shaping:code-shaping` —— 显式走一遍判断清单

条目都是判断角度，不是硬性规定；按条款硬写代码反而别脚。
