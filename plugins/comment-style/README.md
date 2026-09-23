# comment-style

团队注释规范插件：注释怎么留、怎么清。与版本控制、中文表达无关的部分都收敛在这里。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `comment-style` | 技能 | 稀疏注释规则；编辑某个文件时顺手把该文件整文件清干净 |
| `comment-trimmer` | 子代理 | 整目录、整模块的存量注释批量清理，先出清单再动手 |
| SessionStart 提醒 | 钩子 | 会话开始时注入注释约定 |

## 安装

市场源是GitHub 上的仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add https://github.com/Himmeltala/local-team.git
claude plugin install comment-style@local-team
```

改完插件内容后需要重启会话生效（钩子在会话启动时加载）。

## 使用

技能多数会自动触发，也可以显式调用：

- 说"注释太乱帮我清一下" —— 触发 `comment-style` 技能的裁剪规则
- 说"把 xxx 模块的乱注释批量清掉" —— 派 `comment-trimmer` 子代理，先出清单再动手
- `/comment-style:comment-style` —— 显式走一遍规则

## 核心约定速览

**稀疏优先**：默认可不写。代码能自解释的就不加，只有"为什么"非显然时才写，且尽量一行。

**禁符号装饰**：禁 emoji，禁 `====` / `****` 分割线，禁 ★✅🚀 这类无义装饰。符号不承义，句子才承义——映射、换算、流转一律写成文字（`regionId 映射到 orgCode`、`(KB) 换算成 GB`、`在线转离线`）。横幅注释只剥装饰、留住句子。

**不复述代码**：写在 `setName()` 上方的"设置名称"是噪音，删。

**顺手裁剪**：本次编辑碰到的文件，把该文件里的乱注释整文件清干净；没编辑过的文件不碰。清理动到本次改动之外的注释时，提交信息那一行带上"顺带清理注释"。

**永远不删**：功能性指令（`eslint-disable`、`@SuppressWarnings`、`//noinspection`）、`TODO` / `FIXME`（只去装饰）、类级元信息与 Vue 文件头六字段块。

**按层的写法**：Java 字段用 `@ApiModelProperty`、控制层方法用 `@ApiOperation`，不要改成 Javadoc；Service 方法与私有方法不加注解。前端文件头注释块由 eslint 强制，必须保留。

## 维护

插件源在 `~/projs/自用项目/local-team/plugins/comment-style/`，与市场里另外两个插件同处一个 git 仓库，整体的安装与更新流程见仓库根目录的 README。

规则从哪来、实测数字、裁剪范围的沿革见 `docs/maintainer-notes.md`。
