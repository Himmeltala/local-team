# comment-trimming

团队注释规范插件：注释怎么留、怎么清。与版本控制、中文表达无关的部分都收敛在这里。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `comment-trimming` | 技能 | 稀疏注释规则、只讲本段代码、篇幅按中文规范；编辑某个文件时顺手把该文件整文件清干净 |
| `comment-trimmer` | 子代理 | 整目录、整模块的存量注释批量清理，先出清单再动手 |

规范正文只在技能触发时加载，会话开始不再注入摘要。

## 安装

```bash
claude plugin install comment-trimming@local-team
```

只想在部分项目里启用、其它项目不启用时，加 `-s project` 装到项目级（在项目目录下执行）：

```bash
claude plugin install comment-trimming@local-team -s project
```

市场源地址、缓存机制与更新方式见仓库根目录的 `README.md`。

## 使用

技能多数会自动触发，也可以显式调用：

- 说"注释太乱帮我清一下" —— 触发 `comment-trimming` 技能的裁剪规则
- 说"把 xxx 模块的乱注释批量清掉" —— 派 `comment-trimmer` 子代理，先出清单再动手
- `/comment-trimming:comment-trimming` —— 显式走一遍规则

触发词还包括"注释太多"、"注释太长"、"注释写了一大串"、"清理注释"、"裁剪注释"、"压缩注释"、"去掉 emoji"、"注释规范"。注释的篇幅数值以 `chinese-writing` 插件的篇幅标准为准，本插件只执行。
