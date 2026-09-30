# Vue / JS 注释做法

团队前端项目靠自定义 eslint 插件强制，不用自觉。插件放在仓库内的 `.eslint-plugin-local/`，规则包括 `illegal-header-annotation`（文件头）与 `illegal-annotation`（注释符号）。

**下面写的是规则的实际行为**，来自逐行读规则源码 + 实跑正则验证。不要照抄插件自带 README 的描述——那份说明与实现不一致，已核对出两处。新项目若带了同名的本地规则，先读它的源码确认行为再照做。

## 文件头注释块：src/ 下的 .vue / .js / .ts 必须有

```html
<!--
 * @Author: wangqiang
 * @Date: 2022-12-27 09:40:29
 * @LastEditors: zhengrenfu
 * @LastEditTime: 2026-09-08 11:35:00
 * @FilePath: /src/App.vue
 * @Description:
-->
```

- 适用范围是 `src/` 下的 `.vue` / `.js` / `.ts`，且跳过 `src/components/index.js`。仓库根的 `vite.config.js`、mock、`.eslint-plugin-local/*` 不在此列。
- 六个字段 `Author` / `Date` / `LastEditors` / `LastEditTime` / `FilePath` / `Description` 缺一不可，顺序不能乱。缺失或乱序会被判 error，`--fix` 会**整块重建**。
- 重建时 `FilePath` 按文件真实路径生成、作者默认 `runnet`、历史作者会保留。所以不要手改或删除这一块，交给 `--fix`。
- 日期必须是完整 `YYYY-MM-DD HH:MM:SS`。只写日期会被判 error，`--fix` 用文件时间补上时分秒。
- **裁剪注释时不要动这一块**，两行长度上限也不适用它——`Description` 栏留空即可，不要顺手写一段说明。

## 注释里的特殊符号：禁的是这些

规则 `illegal-annotation` 扫所有注释，命中报 error 并可自动修复。它的 `SYMBOL_RE` 实际覆盖：

- ASCII 加号 `+`
- 乘号 `×`
- 箭头区 `←` 到 `⇿`（含 `→`）
- 制表与线条 `─` 到 `╿`
- 几何图形 `■` 到 `◿`
- 装饰符号 `☀` 到 `➿`（含 `★` `✓` `✗`）
- emoji（各 surrogate 区段）

**不在禁止范围**：`=` 和 `>`，所以 `=>` 不会被拦；`-` `*` `/` 也不禁。

两个真实的坑，别被规则自己的说明带偏：

- 加号 `+` 被禁，但规则自带测试文件里写着"数学符号 `+ - * /` 不在禁止范围"，与实现矛盾。以 `SYMBOL_RE` 为准——写 `// 宽×高`、`// CRUD + 标记已读` 会被 `--fix` 静默删掉符号。
- 规则里用了 `/g` 正则加 `.test()` 遍历注释，`lastIndex` 会跨注释残留，导致违规可能被漏报。别指望它兜住全部，写完注释自己看一眼。

要清理某文件的违规符号，**指定文件**跑：

```bash
npx eslint --fix <目标文件>
```

不要用 `npm run lint`（等价于 `eslint --fix --ext .js,.vue src`）做这件事。它会顺带重写全仓文件头、并且删掉 `console.*`——`local/no-console-debug` 是 warn 级但可自动修复，全仓 `--fix` 会把调试语句一并清掉，超出你的改动范围。

## 代码注释：保持轻

- 只在非显然处写一行 `//`。组件文件里注释稍多就显得突兀，存量实测组件注释率远低于入口文件。
- **一行为限，最多两行**，`//` 与 `<!-- -->` 都一样。写不完就别写，先想能不能靠变量名或组件拆分说清楚。
- 讲"为什么"，不讲"做什么"。
- 模板里用 `<!-- -->`，只在结构不直观时才写，例如说明插槽用途、某个条件渲染的业务原因。不给每个 `div` 加中文说明；一句话讲完，不写"这里负责…同时还会…"这种成段的交代。
- 该删的：

```js
// ==================== 接口列表 ====================

// 定义响应式变量
const list = ref([])

// 遍历数组
data.forEach((item) => { ... })
```

- 保留的：

```js
// 后端返回 0 表示本级，前端下钻时要区分"无下级"和"本级"
```

## 提交前自检

- 没有遗留 `console.log` / `console.debug`
- 没有为了对齐 Java 风格给 Vue 组件补 Javadoc 式注释——前端不做这个
- 改动过的文件跑一遍 `npx eslint --fix <改动文件>`，别跑全仓

## 其它相关规则

不是注释规则，但改 Vue 文件时容易撞上：`local/illegal-component-using`、`local/illegal-modal-using`、`local/illegal-url-consistency`（warn）、`local/required-script-setup`、`local/no-image-in-src`、`local/no-image-in-views`。
