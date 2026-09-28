---
name: git-commit
description: 当用户要求把改动提交到 git 仓库、推送、写提交说明、查看改动、拉取远端、解决冲突、回滚撤销时使用；触发词包括"提交"、"提交代码"、"git commit"、"commit 一下"、"推送"、"push"、"改了什么"、"git status"、"git diff"、"git log"、"拉最新代码"、"git pull"、"冲突了"、"回滚"、"撤销修改"、"看历史"。也用于工作副本是 git 而不是 SVN、需要按 git 流程走的场合。
argument-hint: "[要提交的路径] [本次改动的一句话说明]"
allowed-tools: [Bash, Read, Grep, Glob]
---

# git 提交工作流

用户调用时带了参数：`$ARGUMENTS`

- 参数是路径：只处理该路径范围，其余文件不纳入本次提交。
- 参数是改动说明：当作提交信息的草稿，按下方格式整理成一行。
- 无参数：走完整流程，从 `git status` 开始，写好的信息在提交前给用户过目。用户不在场、没法追问时（子代理执行、无人值守），按仓库历史里的既有写法与本次改动内容自己定一行，提交后在报告里把这一行原样写出来，并说明是自行定的。

## 铁律：先认清这是哪个版本控制系统

- 目录下有 `.git` 就是 git，用 git 这套命令；有 `.svn` 就换 `svn-commit` 技能。两套不要混着用，也不要用 `svn status` 看 git 仓库。
- 动手前先 `git rev-parse --is-inside-work-tree` 与 `git status -sb` 确认工作副本与分支，不要凭记忆写路径。
- 自用项目的仓库直接在 `main` 上提交，**不建分支、不建 PR、不写 `Co-Authored-By` 尾注**。
- **推送由用户明确要求才做。** 默认只提交到本地。用户说"推送"时，先确认远端没有别人的新提交再推。

## 提交流程

**闸门：提交前先拉最新。** 本地落后于远端、或与远端分叉时，`git commit` 会被本插件的 PreToolUse 钩子直接拦下（退出码 2）。这是 Claude Code 的插件级钩子，不是仓库里的 `.git/hooks`——`ls .git/hooks` 里看不到它，别拿它判断闸门在不在；没装本插件的环境里没有这道兜底，全靠自己按流程走。钩子只拦不改，`fetch` 与 `pull --rebase` 仍由你手工做完，每一步都留在会话里。

1. **确认位置**——`git rev-parse --is-inside-work-tree`，`git status -sb` 看当前分支与上下游差多少。
2. **先对远端**——`git fetch`，再看 `git status -sb`。
   - 落后或分叉，且工作区干净（没有未提交改动）：`git pull --rebase`，冲突在提交前解决掉。
   - 落后或分叉，且**有未提交改动**：变基会被 git 拒绝（`不能变基式拉取：您的索引中包含未提交的变更`）。先 `git stash push -u` 把改动收起来，`git pull --rebase` 拉完再 `git stash pop` 把改动放回来，然后继续往下走。**不要**为了绕过这一步先提交再拉——闸门拦的正是落后状态下的提交，而且先提交再变基同样要解冲突。
3. **冲突清零**——`git status` 里不允许还有未解决冲突。处理见文末「失败与冲突」。
4. **看改动**——`git status --short` 取清单，`git diff` 与 `git diff --cached` 逐行读；只想看清单用 `git diff --stat`。
5. **处理未纳管文件**——新文件要 `git add <路径>` 才会进本次提交。**逐个 add，不要 `git add -A` 或 `git add .` 一把梭**，那会把临时文件、产物目录一起带上。
   - 判据：只 add 本次改动明确涉及、且能说出用途的文件。
   - 来历不明的未跟踪文件（临时便签、随手存的片段）默认不动，也不删，在报告里列出来问用户要不要入库。带着未跟踪文件提交这件事没有闸门兜底，只能靠人定。
6. **自检**——查调试残留（`console.log`、`debugger`、注释掉的旧代码）、误改的配置文件、混入的 `node_modules/` 或 `dist/` 或 `out/`。
7. **写提交信息**——单行，见下节。
8. **提交**——`git commit -m "<信息>"`，需要限定范围时显式列路径。
9. **核对结果**——`git log --oneline -1` 与 `git status -sb`，确认提交落在预期分支上、工作区状态符合预期。
10. **推送**——用户明确要求时才 `git push`。推完 `git status -sb` 应当显示与远端一致。

## 提交信息：只有一行

```
<type>: <中文描述>
```

**只能有一行。** 没有第二行，不写正文，不加空行，不加 `-` 或编号列表。前缀用 Conventional Commits 那套（feat / fix / refactor / perf / docs / style / test / chore / build / ci / revert），**前缀后面不加范围括号**：写 `feat: 新增作业点导入接口`，不写 `feat(import): ...`；要指明模块就把模块名写进中文描述。冒号用半角 `: `。整行尽量 50 字以内。

**实测教训：** 没有这条约束时，模型会写成"一行标题，加一个空行，再加两条 `-` 列表"的样式，理由是"这次改动包含两件事"。正确做法是**拆成多次提交，每次一行**。一行说不清，说明这次提交装的事太多。

格式细则、前缀含义与正反例见 `../svn-commit/references/commit-message-format.md`——SVN 与 git 共用同一套提交信息格式，只有提交命令不同。

## 闸门拦哪四类

| 拦下的情况 | 提示里给的出路 |
|---|---|
| 前缀带范围括号（`feat(api):` 等） | 把模块名写进中文描述 |
| 信息不是单行（两处 `-m`、引号跨行、`-F` 文件多行、`-F -`） | 拆成多次提交，每次一行 |
| 没给信息（裸 `git commit`、`git commit --amend`） | 用 `-m`；沿用上一条用 `--amend --no-edit` |
| 处于 detached HEAD，或本地落后或分叉于远端 | 落后先 `git pull --rebase`；游离 HEAD 先 `git switch -c <新分支名>` |

变基、摘樱桃、合并过程中的游离 HEAD 不算异常，闸门放行。远端不可达时跳过落后判定，不误拦。

## 命令速查

| 目的 | 命令 |
|---|---|
| 确认仓库与分支 | `git rev-parse --is-inside-work-tree`、`git status -sb` |
| 改动清单 | `git status --short` |
| 逐行差异 | `git diff`（工作区）、`git diff --cached`（已暂存） |
| 只看文件清单 | `git diff --stat` |
| 近期历史 | `git log --oneline -10` |
| 某行是谁改的 | `git blame <file>` |
| 拉远端引用 | `git fetch` |
| 拉取并变基 | `git pull --rebase` |
| 纳入新文件 | `git add <path>` |
| 标记删除 | `git rm <path>` |
| 撤销工作区改动 | `git restore <path>`（不可恢复，先确认） |
| 撤销暂存 | `git restore --staged <path>` |
| 提交 | `git commit -m "<信息>"` |
| 推送 | `git push`（用户明确要求时） |
| 已推送的错误提交 | `git revert <sha>`，再推一次 |

## 失败与冲突

**变基冲突。** `git pull --rebase` 或 `git rebase` 报冲突后：`git status` 里标 `both modified` 的就是冲突文件。

1. 打开文件手工解决，把 `<<<<<<<`、`=======`、`>>>>>>>` 三种标记清干净。
2. `git add <冲突文件>`。
3. `git rebase --continue`。
4. `git status` 确认没有冲突文件，再继续提交。

**先判冲突能不能自己解。** 冲突分两种，处置不同：

| 冲突形态 | 处置 |
|---|---|
| 两边改的是不同位置、不同逻辑，合起来本来就该都在 | 自己合并，两边内容都保留 |
| 同一行两边改成不同取值，或同一段逻辑被改出两种互斥的写法 | 停下问用户留哪一边 |

第二种的「解决」本身就是取舍，等于替用户在两个人的改动之间挑一个，不要自己拍。判断办法：看冲突块里 `<<<<<<<` 与 `>>>>>>>` 两侧的内容能不能共存——不能共存就是取舍题。停下来时把两侧内容、各自的提交信息、涉及的文件列清楚，让用户一句话就能定。

放弃这次变基、回到变基前：`git rebase --abort`。**这一步会丢掉变基过程中已解决的改动**，执行前先跟用户确认。

**分叉。** 本地与远端各有对方没有的提交。不要直接 `git push`（会被拒），也不要默认 force push。先 `git pull --rebase`，把本地提交挪到远端最新之上。冲突按上面那张表判能不能自己解。

**detached HEAD。** 在上面提交的改动不属于任何分支，切走就找不回来。先 `git switch -c <新分支名>` 把改动落到分支上。

**撤销改动。**

| 情况 | 做法 |
|---|---|
| 未提交的工作区改动 | `git restore <path>`（不可恢复） |
| 已提交、**未推送** | `git reset --soft HEAD^` 退回暂存，或 `git commit --amend` 改信息与内容 |
| 已提交、**已推送** | `git revert <sha>` 生成一条反向提交再推。已推送的历史不改写 |
| 远端有别人的提交 | 绝不 force push，用 revert |

**force push。** 只有在自己独占、确认远端没有别人提交的仓库里，且用户明确要求时才做，并且用 `git push --force-with-lease` 而不是 `--force`：前者在远端有新提交时会拒绝。

**index.lock 残留。** 中断的 git 命令留下 `.git/index.lock` 时会报 `Unable to create ... index.lock`。先确认没有仍在运行的 git 进程，再删这个文件。

**中文编码。** 提交信息写入乱码时，`git config --local i18n.commitEncoding utf-8` 确认编码，终端用 `locale` 看是否为 UTF-8。

## 已知坑

**漏 add。** 未 `git add` 的新文件不会进提交，且不留痕迹。提交前用 `git status --short` 核对待提交清单。

**裸 git commit。** 不带 `-m` 会打开编辑器，非交互环境下命令一直卡住。这条有钩子兜底。

**`git add -A` 带进产物。** 一把梭会把 `node_modules/`、`dist/`、`out/` 之类的产物一起提交。这些目录该写进 `.gitignore`。

**改动已推送还 `--amend`。** 改写了已发布的历史，别人再拉会分叉。已推送的用 `git revert`。

**全角冒号与多行正文。** `feat： xxx` 是脏数据；第二行正文是旧做法，历史提交里有，不要跟着学。
