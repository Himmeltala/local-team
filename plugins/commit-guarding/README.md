# control-workflow

版本控制工作流插件：管提交前的检查与拦截。注释规范在 `comment-style` 插件，中文规范在 `chinese-writing` 插件，三者互不依赖，装哪个用哪个。

**SVN 与 git 两种工作副本都管**，按目录下有没有 `.svn` 或 `.git` 分流：同一个会话里既有 SVN 项目又有 git 项目也能用，各自走各自那套。工作副本不在版本控制之下的不需要它。

## 组件

| 组件 | 类型 | 作用 |
|---|---|---|
| `svn-commit` | 技能 | 提交前检查流程、commit 信息格式、SVN 命令速查、冲突与编码踩坑处理 |
| `git-commit` | 技能 | 提交前拉最新、提交信息格式、git 命令速查、变基冲突与撤销处理。提交信息格式与 `svn-commit` 共用一份细则 |
| SessionStart 提醒 | 钩子 | 会话开始时注入版本控制约定（两种工作副本都在内） |
| svn-commit-guard | 钩子 | PreToolUse 拦 `svn commit`：工作副本落后于服务器、有未解决冲突、提交信息前缀带范围括号 |
| git-commit-guard | 钩子 | PreToolUse 拦 `git commit`：前缀带范围括号、信息不是单行、没给信息、处于 detached HEAD、落后或分叉于远端 |

## 安装

市场源是 GitHub 上的 `Himmeltala/local-team` 仓库，对应工作副本 `~/projs/自用项目/local-team`：

```bash
claude plugin marketplace add Himmeltala/local-team
claude plugin install control-workflow@local-team
```

只想在部分项目里启用、其它项目不启用时，加 `-s project` 装到项目级（在项目目录下执行）：

```bash
claude plugin install control-workflow@local-team -s project
```

改完插件内容后需要重启会话生效（钩子在会话启动时加载）。

## 使用

技能多数会自动触发，也可以显式调用：

- `/control-workflow:svn-commit` —— 走一遍 SVN 提交流程并生成提交信息
- `/control-workflow:git-commit` —— 走一遍 git 提交流程并生成提交信息

## 核心约定速览

**先认清工作副本**：目录下有 `.svn` 用 SVN，有 `.git` 用 git。不建分支、不建 PR、不写 `Co-Authored-By` 尾注。**推送要用户明确要求才做。**

**提交前先拉最新**：SVN 走 `svn update`；git 走 `git fetch` 再看是否落后，落后或分叉就先 `git pull --rebase`；此时若工作区有未提交改动，得先 `git stash push -u`，拉完再 `git stash pop`，否则变基会被 git 拒绝。这条有钩子兜底——SVN 落后于服务器或 `svn status` 还有标 `C` 的文件时，`svn commit` 被拦下；git 落后或分叉于远端、处于 detached HEAD 时，`git commit` 被拦下（钩子是插件级钩子，不是仓库里的 `.git/hooks`，`ls .git/hooks` 判断不出来）。钩子只拦不改，`update`、`pull --rebase`、暂存与解决冲突仍由助手手工做完，每一步都留在会话里。

**提交信息**：只有一行，必须简短，格式是 `<type>: <中文描述>`，冒号用半角加空格。前缀用 Conventional Commits 那套，但前缀后面不加范围括号：写 `feat: 新增作业点导入接口`，不写 `feat(import): ...`；要指明模块就把模块名写进中文描述。不写第二行、不写正文或列表，一行说不清就拆成多次提交。这条两种提交都有钩子兜底：`-m` / `--message` / `--message=` / `-F` 文件里出现 `feat(xxx):`，或信息不是单行（两处 `-m`、引号跨行、`-F` 文件多行、`-F -`），一律拦下（退出码 2）。git 侧另外还拦没给信息（裸 `git commit` 会打开编辑器卡住）。

## 维护

插件源在 `~/projs/自用项目/local-team/plugins/control-workflow/`，与市场里另外两个插件同处一个 git 仓库，整体的安装与更新流程见仓库根目录的 README。

改闸门判据、跑验收测试、确认常驻提醒长度这类维护细节见 `docs/maintainer-notes.md`。
