# control-workflow

版本控制工作流插件：管提交前的检查与拦截。注释规范在 `comment-style` 插件，中文规范在 `chinese-writing` 插件，三者互不依赖，装哪个用哪个。

**只在 SVN 项目里启用。** 工作副本不在版本控制之下、或者项目用 git 的，不需要它。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `svn-commit` | 技能 | 提交前检查流程、commit 信息格式、SVN 命令速查、冲突与编码踩坑处理 |
| SessionStart 提醒 | 钩子 | 会话开始时注入版本控制约定 |
| commit-guard | 钩子 | PreToolUse 拦 `svn commit`：工作副本落后于服务器、有未解决冲突、提交信息前缀带范围括号，三种情况直接拦下 |

## 安装

市场源是GitHub 上的仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add https://github.com/Himmeltala/local-team.git
claude plugin install control-workflow@local-team
```

只想在 SVN 项目里启用、其它项目不启用时，加 `-s project` 装到项目级（在项目目录下执行）：

```bash
claude plugin install control-workflow@local-team -s project
```

改完插件内容后需要重启会话生效（钩子在会话启动时加载）。

## 使用

技能多数会自动触发，也可以显式调用：

- `/control-workflow:svn-commit` —— 走一遍提交流程并生成提交信息

## 核心约定速览

**SVN**：用 `svn status` / `svn diff` / `svn log` / `svn update` / `svn commit`。不建分支、不建 PR、不写 `Co-Authored-By` 尾注。

**提交前先更新**：`svn update` 是硬前置，冲突清零才提交。这条有钩子兜底——落后于服务器或 `svn status` 还有标 `C` 的文件时，`svn commit` 会被拦下（退出码 2）。钩子只拦不改，`update` 与解决冲突仍由助手手工做完，每一步都留在会话里。

**提交信息**：只有一行，必须简短，格式是 `<type>: <中文描述>`，冒号用半角加空格。前缀用 Conventional Commits 那套，但前缀后面不加范围括号：写 `feat: 新增作业点导入接口`，不写 `feat(import): ...`；要指明模块就把模块名写进中文描述。不写第二行、不写正文或列表。范围括号这条有钩子兜底，`-m` / `--message` / `--message=` / `-F` 文件首行里出现 `feat(xxx):` 一律拦下（退出码 2）。

## 维护

插件源在 `~/projs/自用项目/local-team/plugins/control-workflow/`，与市场里另外两个插件同处一个 git 仓库，整体的安装与更新流程见仓库根目录的 README。

改闸门判据、跑验收测试、确认常驻提醒长度这类维护细节见 `docs/maintainer-notes.md`。
