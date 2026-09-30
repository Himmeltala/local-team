---
name: comment-style
description: 编写、修改或审查 Java、Vue、JavaScript 代码时使用，保证注释符合团队稀疏且简短的规范；也用于用户说"注释太乱"、"注释太多"、"注释太长"、"注释写了一大串"、"注释密密麻麻"、"清理注释"、"裁剪注释"、"压缩注释"、"去掉 emoji"、"注释规范"的场合。
argument-hint: "[要处理的文件或目录]"
allowed-tools: [Read, Edit, Write, Grep, Glob, Bash]
---

# 团队注释规范：稀疏且简短

用户调用时带了参数：`$ARGUMENTS`

- 参数是文件：清该文件的注释，整文件范围。
- 参数是目录：这是存量批量清理，交给 `comment-trimmer` 子代理，先出清单再动手。
- 无参数：当前任务里正常遵守规范；本次编辑碰到的文件，按整文件范围顺手清干净。

## 四条硬规矩

1. **默认不写注释。** 代码能自解释的就不加。只有"为什么"非显然时才写。
2. **注释要短。** 一律压到一行，最多两行，**所有注释类型都一样**：行内 `//`、字段与方法注解、类头 Javadoc 的 `功能：` 与 `说明：`、Mapper XML 的 `--`、模板里的 `<!-- -->`。一行说不完，就说明这段信息不该待在注释里——挪进命名、常量或文档，不要写成一段。
3. **不用符号装饰。** 禁 emoji，禁 `=====` / `*****` / `-----` 分割线，禁 ASCII 艺术，禁 `★ ✅ ❌ 🚀` 这类无义装饰。
4. **注释不许复述代码。** 写在 `setName()` 上方的 `// 设置 name` 是噪音，删。

**怎么压。** 删掉解释链条、举例与语气词，只留结论和关键字；一句话能说完的不拆两句，括号里补的解释挪进命名或文档。承载业务口径的长注释也照压，不许因为"信息重要"就留成一段——真压不下去又丢不得，在回复里列出来让用户定，不要自行删掉。

**不受两行限制的三种。** Vue / JS 文件头六字段块（eslint 强制，整块不可动）、功能性指令（`eslint-disable`、`@SuppressWarnings`、`//noinspection` 按语法原样保留，压缩只碰里面的人话）、注解值（`@ApiModelProperty`、`@ApiOperation` 的 value / notes 属接口文档，不是注释，但同样不该写成长文）。

**符号与箭头的通用规则以 `chinese-writing` 插件为准**（通用层只写一份，避免两处口径漂移）。落到注释上的要点：注释里禁 `→`，禁整个箭头区 `←` 到 `⇿`，承义也不例外——符号不承义，句子才承义。原来靠箭头省的字，改写成文字：

- `regionId → orgCode` 写成 `regionId 映射到 orgCode` 或 `regionId 对应 orgCode`
- `(KB) → GB` 写成 `(KB) 换算成 GB`
- `在线→离线` 写成 `在线转离线`、`由在线变为离线`

其余符号（`★` `✓` `✗`、`➜` 之类）一律删，含义用文字说出来——目标是说清，不是借机多写几行。

**例外：字符串字面量与注解值里的箭头是数据，一个字不动**，详见 `references/trim-rules.md`。

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

**本次编辑碰到哪个文件，就把那个文件里的密集乱注释一并清干净。** 裁剪范围是**整文件**，不再限定在改动的函数 / 方法 / 模板块内。

边界只有一条：**没编辑过的文件一律不碰**。触发条件是"我正在改这个文件"，不是"这个模块看着乱"。

这样定的理由是文件级一致性：清一半的文件比不清更麻烦——下一个改它的人得重新判断哪些注释该留，判断标准还会漂。整文件一次清完，从此是干净的基线。

代价是 diff 变大。只要清理动到了本次改动之外的注释，就在那唯一一行提交信息里带上"顺带清理注释"，别让清理变成隐形改动。提交信息不能另起一行说明（见 `control-workflow` 插件的 `svn-commit` 技能）。

删什么、留什么、判断边界，以 `references/trim-rules.md` 为准——`comment-trimmer` 子代理也以同一份为准。三条永远不删：

- 功能性指令：`//noinspection`、`eslint-disable`、`@SuppressWarnings`、`@SuppressFBWarnings`
- `TODO` / `FIXME`——保留，仅去装饰
- 既有类级元信息：许可证头、`@author`、`@date`、Java 类 Javadoc 的 `<b>功能：</b>` 模板、Vue 文件头六字段块

存量类头的旧写法（`@title` / `@description` / `@date`）是历史风格，改到该类时保持原样，不要整体重写成新模板——那是无意义的大 diff。新类用新模板。

裁剪后自查：该文件里是否还留着乱注释、是否还有超过两行的长注释、是否动了本次没编辑的文件、是否误删功能性指令、是否把存量 Javadoc 改成注解或反过来。

## 存量批量清理

整目录、整模块的注释清理交给 `comment-trimmer` 子代理。它先出清单再动手，并跳过 `node_modules/`、`target/`、`dist/`。

## 附加资源

- `references/java-conventions.md`
- `references/vue-js-conventions.md`
- `references/xml-sql-conventions.md`
- `references/trim-rules.md`——删什么、留什么、边界判断（裁剪的权威文件）

提交代码时同时遵守提交格式，见 `control-workflow` 插件的 `svn-commit` 技能。
