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
| `comment-style` | 技能 | 稀疏注释规则；编辑某个文件时顺手把该文件整文件清干净 |
| `chinese-writing` | 技能 | 中文表达与理解：介词、关联词、量词、语序、术语、中英混排空格，禁符号代字 |
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

**顺手裁剪**：本次编辑碰到的文件，把该文件里的乱注释整文件清干净；没编辑过的文件不碰。清理动到本次改动之外的注释时，提交信息那一行带上"顺带清理注释"。功能性指令（`eslint-disable`、`@SuppressWarnings`、`noinspection`）与 `TODO` / `FIXME` 永不删。

**适用范围**：约定对团队所有 Java / Vue 项目生效，不绑定某个仓库。新项目沿用同一套，不要另立风格。路径一律用 `svn info` 现场确认，不要照抄旧路径。

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

改动判据、测试命令、规则依据这类维护细节见 `docs/maintainer-notes.md`。
