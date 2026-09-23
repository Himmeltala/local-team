# svn-team-conventions

本团队（SVN 工作流 + Java/Vue 双栈）的提交与注释约定插件。全局生效，不绑定单个项目。

## 解决什么问题

- 助手的默认训练偏向 git：动辄 `git diff`、建分支、写 `Co-Authored-By`。本环境是 SVN，那些指令无法执行。
- 助手默认爱写注释：解释性、翻译式、装饰性注释堆一片，与团队存量风格冲突。
- 提交信息风格漂移：漏前缀、全角冒号、前缀带范围括号（`feat(api): xxx`）、描述空泛。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `svn-commit` | 技能 | 提交前检查流程、commit 信息格式、SVN 命令速查、编码踩坑修复 |
| `comment-style` | 技能 | 稀疏注释规则；编辑代码时顺手裁剪改动块内的乱注释 |
| `comment-trimmer` | 子代理 | 整目录 / 整模块的存量注释批量清理，先出清单再动手 |
| SessionStart 提醒 | 钩子 | 每次会话开始注入简短约定，保证不靠触发词也生效 |
| commit-guard | 钩子 | PreToolUse 拦 `svn commit`：工作副本落后于服务器、有未解决冲突、提交信息前缀带范围括号，三种情况直接拦下 |

## 安装

本插件通过市场 `local-team` 提供。市场源是GitHub 上的仓库（`http://localhost:3000/Himmeltala/claude-marketplace.git`，对应工作副本 `~/.claude/local-marketplace`）：

```bash
claude plugin marketplace add http://localhost:3000/Himmeltala/claude-marketplace.git
claude plugin install svn-team-conventions@local-team
```

`marketplace add` 只认 `http(s)://`、GitHub 的 `owner/repo` 和本地路径，`ssh://` 会被判成非法格式——尽管 仓库页面上给的是 SSH 地址。拉取走 HTTP，仓库是公开的；推送仍走 SSH（`ssh://git@localhost:2222/Himmeltala/claude-marketplace.git`，端口 2222）。

改完插件内容后需要重启会话生效（钩子在会话启动时加载）。

## 使用

技能多数会自动触发，也可以显式调用：

- `/svn-team-conventions:svn-commit` —— 走一遍提交流程并生成提交信息
- 说"注释太乱帮我清一下" —— 触发 `comment-style` 的裁剪规则
- 说"把 xxx 模块的乱注释批量清掉" —— 派 `comment-trimmer` 子代理

## 核心约定速览

**SVN**：用 `svn status` / `svn diff` / `svn log` / `svn update` / `svn commit`。不建分支、不建 PR。

**提交前先更新**：`svn update` 是硬前置，冲突清零才提交。这条有钩子兜底——落后于服务器或 `svn status` 还有标 `C` 的文件时，`svn commit` 会被拦下（退出码 2）。钩子只拦不改，`update` 和解决冲突仍由助手手工做完，每一步都留在会话里。

**提交信息**：**只有一行，必须简短**——`<type>: <中文描述>`，冒号半角加空格。前缀用 Conventional Commits 那套，但**前缀后面不加范围括号**：写 `feat: 新增作业点导入接口`，不写 `feat(import): ...`；要指明模块就把模块名写进中文描述。不写第二行、不写正文或列表。历史提交里的多行正文是旧做法，不要跟着学。**范围括号这条有钩子兜底**：`-m` / `--message` / `--message=` / `-F` 文件首行里出现 `feat(xxx):` 一律拦下（退出码 2）。钩子只判前缀，描述内部的括号随便写。

**注释**：稀疏优先，默认可不写。禁 emoji、禁 `====` / `****` 分割线、禁 `★✅🚀` 这类无义装饰、禁箭头（`→` 及箭头区 `←` 到 `⇿`，承义也不例外）。映射、换算、流转写成文字（`regionId 映射到 orgCode`、`(KB) 换算成 GB`、`在线转离线`）。不复述代码，只讲"为什么"。Java 字段用 `@ApiModelProperty`、控制层方法用 `@ApiOperation`，不要改成 Javadoc。前端文件头六字段注释块由 eslint 强制，必须保留。

**顺手裁剪**：改到某块代码时，清理该块内的乱注释，范围不出改动块。功能性指令（`eslint-disable`、`@SuppressWarnings`、`noinspection`）与 `TODO` / `FIXME` 永不删。

**适用范围**：约定对团队所有 Java / Vue 项目生效，不绑定某个仓库。新项目沿用同一套，不要另立风格。路径一律用 `svn info` 现场确认，不要照抄旧路径。

## 依据

注释与格式约定实测自团队存量项目（2026-09-23 扫描一个约 990 个 Java 文件规模的后端，加一个 Vue 3 前端），不是通用社区建议：

- Java 类头主流是 `<b>功能：</b>` / `<b>说明：</b>` + `@author` 模板；字段用 `@ApiModelProperty`、方法用 `@ApiOperation`，均非 Javadoc
- 前端在仓库内自带 `.eslint-plugin-local`，其中 `illegal-annotation` 强制禁注释特殊符号、`illegal-header-annotation` 强制六字段文件头
- mapper XML 的 `--` 注释承载数据库引擎的坑与口径
- 提交信息的前缀与半角冒号取自 `svn log` 实例；**单行、简短**是团队现行规定

上面这些是**格式事实**，对新项目同样成立。下面这些是**某个项目的测量值**，只在判断"该先扫什么"时有用，新项目数字会不同：装饰横幅 127 处、注释掉的代码 106 处、日期形式的变更履历 0 处。

## 顺带发现的上游规则缺陷

两个前端自定义 eslint 规则的问题，不是本插件的，但如果将来有人维护那份规则可以修：

- `illegal-annotation` 的 `SYMBOL_RE` 把 ASCII 加号 `+` 和乘号 `×` 也列为违规，但该规则自带的测试文件里写着「数学符号 `+ - * /` 不在禁止范围」，规则与测试互相矛盾。
- 同一个规则用 `/g` 正则加 `.test()` 在循环里遍历注释，`lastIndex` 会跨注释残留，违规可能被漏报。另外 `.eslint-plugin-local/README.md` 声称该规则还管「空格、AI 风格表述、JSDoc 格式」，实现里没有这些。

## 下一步可做

存量前端源码里有一批注释命中自定义 eslint 的符号规则，属存量违规。要清的话**指定文件**跑 `npx eslint --fix <文件>`，不要全仓跑（全仓会顺带重写所有文件头并删掉 `console.*`）。

## 已知缺陷

版本库里出现过提交信息编码损坏的情况——写入后存成 `æ–°å¢žèµ„äº§...` 这样的乱码（CP1252 误解码）。修复需 `svn propset --revprop -r <版本号> svn:log "<正确文本>"`，且服务端须开 `pre-revprop-change` 钩子。提交前用 `locale` 确认终端为 UTF-8，可避免再次写入乱码。

## 维护

插件源在 `~/.claude/local-marketplace/plugins/svn-team-conventions/`，整个市场目录是一个 git 仓库，远端在GitHub：

```bash
git remote -v      # origin  ssh://git@localhost:2222/Himmeltala/claude-marketplace.git
```

安装时文件是**复制**到 `~/.claude/plugins/cache/local-team/svn-team-conventions/<version>/` 的，改源目录不会自动生效。改完内容后：

1. 提高 `.claude-plugin/plugin.json` 里的 `version`（例如从 `0.5.0` 提到 `0.6.0`）。版本号不变时 `claude plugin update` 会判定"已是最新"而不重新复制，这一步不能省。
2. `git add -A && git commit -m "<type>: <说明>" && git push` —— 内容必须先到远端，本地文件不参与安装。
3. `claude plugin marketplace update local-team` —— 重新 clone 市场仓库，刷新目录清单。
4. `claude plugin update svn-team-conventions@local-team`
5. 重启 Claude Code 会话（钩子只在会话启动时加载）。

这套步骤 2026-09-23 实测通过：更新后缓存目录与源目录 `diff -rq` 一致。旧版本目录会留在缓存里，不影响加载，可以忽略。

只改 `hooks/session-rules.txt` 的提示语时，也可以直接编辑缓存目录里那份并重启会话，跳过上面三步；但下次更新会被覆盖，源目录要同步改并推送。

## 调整约定

- 会话常驻提醒的正文在 `hooks/session-rules.txt`，保持简短——每次会话都会占用上下文。当前 1046 字符。上限是 10000 字符，超了会被换成文件路径加预览，等于失效。
- 提交闸门在 `hooks/scripts/commit-guard.sh`，三条判据：落后与冲突靠 `svn status --xml -u` 的两个元素——`item="conflicted"`（含树冲突）和 `<repos-status>`（落后服务器），后者只在远端与本地真的有差异时才出现，本地 `add` / `delete` / 改内容都不会产生，所以不会误拦正常提交；范围括号只看命令行文本，不碰工作副本。误拦是比漏拦更坏的故障——写判据时先想清楚这点。信息格式的判据锚行首（`^(type)[[:space:]]*\(`），所以描述里的半角括号（`fix: 统计接口(含下级)补齐`）和全角括号不受影响。改这条判据时，把这几条放行用例一并跑一遍。
- 闸门解析钩子输入依赖 `python3`，退而求其次用 `jq`，两者都没有时**静默放行**。这是有意的取舍：钩子是加在提交路径上的，它自己出故障不能把人堵在提交外面。要确认闸门在不在，直接喂一条假输入试：`echo '{"tool_name":"Bash","cwd":"<工作副本>","tool_input":{"command":"svn commit -m x"}}' | bash hooks/scripts/commit-guard.sh; echo $?`，落后或有冲突时应当得到 2；把 `-m x` 换成 `-m "feat(a): x"`，在干净工作副本里也应当得到 2。
- 改闸门判定逻辑后跑一遍验收测试：`bash tests/commit-guard.test.sh hooks/scripts/commit-guard.sh`。它每次在 `/tmp/svnguard` 下重建临时版本库，造出「落后」「冲突」「已 resolve」等真实状态，不碰任何真实工作副本，31 个用例应当全绿。建库阶段任何一步失败会直接中止并报 `FIXTURE`，不会带着坏 fixture 跑出假绿。
- 钩子用纯文本 stdout 输出。Claude Code 对 SessionStart 事件会把 plain stdout 注入上下文（官方 hooks 文档 exit-code-0 一节）；输出以 `{` 开头会被当 JSON 解析，所以正文里不要让第一行以 `{` 开头。
- 团队做法变化时（例如前后端换了注释体系），改 `skills/comment-style/references/` 下对应的引用文件，而不是往 SKILL.md 里堆内容。
- 新增约定条目时先核对存量代码，确认是"团队实际这么干"再写进去。写进插件的规则会被当成事实执行。
