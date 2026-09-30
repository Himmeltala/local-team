---
name: svn-commit
description: 当用户要求提交代码到版本库、写提交说明、查看工作副本改动、解决更新冲突、回滚撤销改动时使用；触发词包括"提交"、"提交代码"、"svn commit"、"commit 一下"、"改了什么"、"svn status"、"svn diff"、"svn log"、"拉最新代码"、"更新一下代码"、"冲突了"、"回滚"、"撤销修改"、"看历史"。也用于用户误用 git（git diff/log/commit、分支、PR）需要纠正的场合。
argument-hint: "[要提交的路径] [本次改动的一句话说明]"
allowed-tools: [Bash, Read, Grep, Glob]
---

# SVN 提交工作流

用户调用时带了参数：`$ARGUMENTS`

- 参数是路径：只处理该路径范围，其余文件不纳入本次提交。
- 参数是改动说明：当作提交信息的草稿，按下方格式整理成一行。
- 无参数：走完整流程，从 `svn status` 开始，提交前把这一行给用户过目。

## 铁律：这是 SVN，不是 git

- 绝不用 `git diff` / `git log` / `git status` / `git commit` / `git blame`。
- 不创建分支，不建 PR，不写 git 的 `Co-Authored-By` 尾注。
- **工作副本是 git 仓库（目录下有 `.git`）时换 `git-commit` 技能**，不要拿这一套去套 git 仓库。两者提交信息格式相同，命令与前置检查不同。
- **先 `svn info` 定位工作副本。** 工作区根目录本身通常不是工作副本，只有含 `.svn` 的项目子目录才是。版本库可达性用 `svn info <URL>` 测，报错即不通。
- 不要凭记忆写路径。项目会越来越多，路径按当前 `svn info` 的输出为准。

## 提交流程

**闸门：先 `svn update`，冲突清零。** 这两件事没做完，不要执行 `svn commit`。插件装了
PreToolUse 钩子（`hooks/scripts/svn-commit-guard.sh`），会在提交前跑一次 `svn status -u`：
工作副本落后于服务器，或 `svn status` 里还有标 `C` 的文件，提交直接被拦下——钩子以退出码 2
结束，把原因和该做的事打回来。钩子只拦不改，工作副本始终由你按下面的步骤处理。

钩子还管提交信息的写法：`-m` / `--message` / `--message=` / `-F` 文件首行里出现
`feat(xxx):` 这种前缀带范围括号的，同样以退出码 2 拦下（详见下节）。这条只看命令行文本，
不碰工作副本，所以在非工作副本目录里也照样拦。

1. **确认位置**——`svn info` 看 URL 与版本，确认目录属于哪个工作副本。
2. **先更新**——`svn update`。这一步不能省，也不能等提交报错了再补。落后时提交必被钩子拦下。
3. **冲突清零**——`svn status` 里不允许还剩 `C`。有冲突就按本文末尾「失败与冲突」一节处理完再往下走。
4. **看改动**——`svn status` 取文件清单，`svn diff` 逐行读；只想看清单用 `svn diff --summarize`。
5. **处理未纳管文件**——新增文件必须 `svn add`，删除的文件用 `svn delete`。漏 add 会让提交缺文件，且不留痕迹。
6. **自检**——查调试残留（`System.out`、`console.log`、注释掉的旧代码）、误改的配置文件、混入的 `target/` 或 `node_modules/`。
7. **写提交信息**——单行，见下。
8. **提交**——`svn commit -m "<信息>" [路径...]`。显式列出本次相关文件，避免在工作副本根裸跑 `svn commit` 把无关改动一起送上。

## 提交信息：只有一行

```
<type>: <中文描述>
```

**只能有一行。** 没有第二行，不写正文，不加列表，不加空行。必须简短。

- **type** 用 Conventional Commits 前缀：feat / fix / refactor / perf / docs / style / test / chore / build / ci / revert。各自适用场景见 `references/commit-message-format.md`。
- **前缀后面不加范围括号。** 写 `feat: xxx`，不写 `feat(module): xxx`。这是硬规则，不是偏好，写错会被钩子直接拦下。描述内部的括号不受限制。
- **冒号必须半角** `: `（半角冒号加空格）。全角 `：` 是已知漂移，不要跟。
- **描述用中文**，一句话说清做了什么。整行尽量控制在 50 字以内。
- 要指明模块或接口，把名字写进中文描述里：`fix: 门禁记录统计接口补齐无数据的区域与操作类型`。
- 写不下的细节不要塞进提交信息。写进代码注释，或者当面讲。提交信息是索引，不是文档。

单行好例（取自真实 `svn log`）：

```
feat: 新增资产分布分区域设备统计接口（含本级及下级），金额单位统一为万元
```

```
fix: 门禁记录统计接口补齐无数据的区域与操作类型
```

反例：

- `feat(api): 新增门禁记录统计接口`——加了范围括号。改成 `feat: 新增门禁记录统计接口`，需要点明模块就写进描述。
- `feat： 修改运行数据统计逻辑`——全角冒号，描述空泛。
- `告警查询`——漏前缀，看不出改了什么。
- 任何带第二行的提交信息——包括"原逻辑是…现改为…"、编号列表、空行分段的正文。历史提交里这类写法不少，**不要跟着学**。

## 命令速查

| 目的 | 命令 |
|---|---|
| 确认工作副本 | `svn info` |
| 改动清单 | `svn status` |
| 是否落后服务器 / 有无冲突 | `svn status -u`（提交闸门跑的就是它） |
| 逐行差异 | `svn diff` |
| 只看文件清单 | `svn diff --summarize` |
| 近期历史 | `svn log -l 10` |
| 某行是谁改的 | `svn blame <file>` |
| 拉最新 | `svn update` |
| 纳入新文件 | `svn add <path>` |
| 标记删除 | `svn delete <path>` |
| 撤销本地改动 | `svn revert <path>`（不可恢复，先确认） |
| 提交 | `svn commit -m "<信息>" [路径...]` |

## 失败与冲突

**更新产生冲突。** `svn status` 会显示 `C` 状态，工作目录里多出 `xxx.mine`、`xxx.r<旧版本>`、`xxx.r<新版本>` 几个文件。冲突没解决前钩子会一直拦着 `svn commit`，这是预期行为，不要去绕。

1. 打开目标文件手工解决，把 `<<<<<<<`、`=======`、`>>>>>>>` 三种标记清干净。
2. `svn resolve --accept=working <path>` 告诉 svn 已解决。
3. `svn status` 确认不再有 `C`，再 `svn commit`。

`--accept=working` **不会自动清掉冲突标记**——标记留在文件里，可能还能编译，但结果是错的。resolve 之后必须打开文件确认标记已删干净。

放弃自己的改动：`svn revert <path>` 然后 `svn update`。`revert` 不可恢复，执行前先确认改动是否已备份或已提交。

整体取一边（不理解冲突内容，只在读过 diff 之后用）：

- `svn resolve --accept=theirs-full <path>`——整体用服务器版本，丢弃本地改动
- `svn resolve --accept=mine-full <path>`——整体用本地版本，丢弃服务器改动

**常见报错：**

| 报错 | 原因与处理 |
|---|---|
| `E155004` working copy locked | 中断的 update 留下锁，`svn cleanup` 后重试 |
| `E160028` out-of-date | 提交前没 update，`svn update` 后重新提交 |
| `E155010` 已存在同名未纳管文件 | 先确认是否要 `svn add`，不要直接覆盖 |

提交是整体事务：中途失败则全部回滚，不会一半入库，修好问题重新提交即可。

## 已知坑

**全角冒号**——`feat： xxx` 会被工具链与检索当成脏数据。

**前缀带范围括号**——`feat(api): xxx` 会被钩子拦下（退出码 2），改成 `feat: xxx`，要指明模块就写进中文描述。

**编码损坏**——历史上出现过提交信息写入版本库后变成 `æ–°å¢žèµ„äº§...` 这类乱码的情况（CP1252 误解码）。修复需
`svn propset --revprop -r <版本号> svn:log "<正确文本>"`，且服务端须开 `pre-revprop-change` 钩子。提交前用 `locale` 确认终端为 UTF-8，避免再次写入乱码。

**漏 add**——`svn status` 里标 `?` 的文件不会被提交。

**裸提交**——在工作副本根裸跑 `svn commit` 会带上全部改动，先看清 `svn status`。

## 附加资源

- `references/commit-message-format.md`——前缀含义、单行写法、更多正反例。

改代码时同时遵守注释规范，见 `comment-style` 插件。
