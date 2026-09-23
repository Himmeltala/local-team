---
name: comment-style
description: 编写、修改或审查 Java、Vue、JavaScript 代码时使用，保证注释符合团队稀疏规范；也用于用户说"注释太乱"、"注释太多"、"注释密密麻麻"、"清理注释"、"裁剪注释"、"去掉 emoji"、"注释规范"的场合。
argument-hint: [要处理的文件或目录]
allowed-tools: [Read, Edit, Write, Grep, Glob, Bash]
---

# 团队注释规范：稀疏优先

用户调用时带了参数：`$ARGUMENTS`

- 参数是文件：按下方规则处理该文件的注释；涉及整文件清理时遵守"编辑文件时顺手裁剪"的范围限制，超范围先问。
- 参数是目录：这是存量批量清理，交给 `comment-trimmer` 子代理，先出清单再动手。
- 无参数：当前任务里正常遵守规范，改动块内顺手裁剪。

## 三条硬规矩

1. **默认不写注释。** 代码能自解释的就不加。只有"为什么"非显然时才写，且尽量一行。
2. **不用符号装饰。** 禁 emoji，禁 `=====` / `*****` / `-----` 分割线，禁 ASCII 艺术，禁 `★ ✅ ❌ 🚀` 这类无义装饰。
3. **注释不许复述代码。** 写在 `setName()` 上方的 `// 设置 name` 是噪音，删。

**箭头一律不写。** 注释里禁 `→`，禁整个箭头区 `←` 到 `⇿`，承义也不例外——符号不承义，句子才承义。原来靠箭头省的字，改写成文字：

- `regionId → orgCode` 写成 `regionId 映射到 orgCode` 或 `regionId 对应 orgCode`
- `(KB) → GB` 写成 `(KB) 换算成 GB`
- `在线→离线` 写成 `在线转离线`、`由在线变为离线`

其余符号（`★` `✓` `✗`、`➜` 之类）一律删，含义用文字说出来。宁可多写两个字，不要用符号替代句子。

前端另有更严的自定义 eslint 规则会拦符号，细则与两个真实的规则缺陷见 `references/vue-js-conventions.md`。

## 可用的注释形式

- Java：`//`、`/* */`、`/** */`
- Vue / JS：同上，模板与文件头用 `<!-- -->`（文件头由 eslint 强制，不可删）
- Mapper XML：SQL 用 `-- `，结构层用 `<!-- -->`

## 按层的团队做法

各语言的具体模板、正反例、实测统计见引用文件，**不要凭印象发挥**：

- `references/java-conventions.md`——类 Javadoc 模板、字段 `@ApiModelProperty`、方法 `@ApiOperation`、行内注释取舍
- `references/vue-js-conventions.md`——文件头六字段块、eslint 符号规则的真实边界、轻注释做法
- `references/xml-sql-conventions.md`——mapper XML 与 SQL 注释，这里的口径注释尤其不能删

**关键**：Java 字段用 `@ApiModelProperty`，**控制层**方法用 `@ApiOperation`。Service 内部方法与私有方法不加注解、也不补 Javadoc。不要把这些统一改成 Javadoc——团队存量代码统一是 Swagger 注解那套，新代码必须一致。

**新项目照此执行。** 这套约定不绑定某个项目：新起的前后端仓库一律沿用，不要另立风格。若新项目已有既有写法且与本节冲突，先按项目存量对齐，再把冲突报给用户。

## 编辑文件时顺手裁剪

改动某块代码时，同时清理**该块内**的密集乱注释。范围严格限定在改动的函数 / 方法 / 模板块内，文件其它区域不动——diff 要小，不把无关区域搅进来。

清理量大时，在那唯一一行提交信息里带一句"顺带清理注释"，别让清理变成隐形改动。提交信息不能另起一行说明（见 `svn-commit`）。

删什么、留什么、判断边界，以 `references/trim-rules.md` 为准——`comment-trimmer` 子代理也以同一份为准。三条永远不删：

- 功能性指令：`//noinspection`、`eslint-disable`、`@SuppressWarnings`、`@SuppressFBWarnings`
- `TODO` / `FIXME`——保留，仅去装饰
- 既有类级元信息：许可证头、`@author`、`@date`、Java 类 Javadoc 的 `<b>功能：</b>` 模板、Vue 文件头六字段块

存量类头的旧写法（`@title` / `@description` / `@date`）是历史风格，改到该类时保持原样，不要整体重写成新模板——那是无意义的大 diff。新类用新模板。

裁剪后自查：删除是否超出改动块、是否误删功能性指令、是否把存量 Javadoc 改成注解或反过来。

## 存量批量清理

整目录、整模块的注释清理交给 `comment-trimmer` 子代理。它先出清单再动手，并跳过 `node_modules/`、`target/`、`dist/`。

## 附加资源

- `references/java-conventions.md`
- `references/vue-js-conventions.md`
- `references/xml-sql-conventions.md`
- `references/trim-rules.md`——删什么、留什么、边界判断（裁剪的权威文件）

提交代码时同时遵守提交格式，见 `svn-commit` 技能。
