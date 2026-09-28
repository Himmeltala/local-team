#!/usr/bin/env bash
# PreToolUse 闸门：拦下四类 git 提交。
#   1. 提交信息前缀带了范围括号（feat(api): xxx）
#   2. 提交信息不是单行（多个 -m、-m 引号跨行、-F 文件不止一行、信息走标准输入）
#   3. 没给提交信息，非交互环境下会打开编辑器卡在提交上
#   4. 处于 detached HEAD，或本地落后或分叉于远端
#
# 为什么用钩子而不是只写进技能文档：单行信息、前缀不带范围、提交前先拉最新，
# 都是硬要求，靠模型自觉会漏。钩子只做判定和拦截，绝不改动工作副本——fetch、
# pull、切分支仍由模型按提示手工完成，每一步都留在会话里可查。
#
# 与 svn 闸门分成两份文件，判据互不干扰：svn 的落后与冲突读 `svn status --xml -u`，
# git 的落后读 `git ls-remote`，没有可复用的判定。钩子输入解析那段两边是重复的，
# 有意不抽公共库：抽了要动已经在跑、且有验收测试覆盖的 svn 闸门。
#
# 落后判定用 `git ls-remote` 而不是 `git fetch`：ls-remote 只读远端引用，不改本地
# 任何状态，钩子不动工作副本这条底线不破。远端不可达（离线、无凭据）时跳过这一条。
#
# 落后与分叉的提示按工作区是否干净给步骤：有未提交改动时先让 `git stash push -u`，
# 否则 `git pull --rebase` 会被 git 以「索引中包含未提交的变更」直接拒绝。
#
# 任何异常一律放行：不是 Bash 调用、JSON 解析失败、目标不是 git 仓库、git 报错。
# 闸门只拦确定坏的情况，自身出故障时绝不能堵住提交。误拦比漏拦更坏，以下几类
# 有意不拦：自己仓库里 `git commit --amend` 后再强推、提交时带着未跟踪文件、
# `git commit -a` 把已跟踪的改动一并提交。
#
# 依赖 python3 或 jq 任一个来解析钩子输入；两者都没有时静默放行。

set -uo pipefail

# 输出 tool_name、cwd、command，用 NUL 分隔。bash 变量存不了 NUL，所以走 mapfile。
parse_input() {
  local raw="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
ti = d.get("tool_input") or {}
sys.stdout.write("%s\0%s\0%s" % (
    d.get("tool_name") or "", d.get("cwd") or "", ti.get("command") or ""))
' <<<"$raw" 2>/dev/null
  elif command -v jq >/dev/null 2>&1; then
    jq -j '[.tool_name // "", .cwd // "", .tool_input.command // ""] | join("\u0000")' \
      <<<"$raw" 2>/dev/null
  else
    return 1
  fi
}

# 这一段是不是 git commit 调用。跳过全局选项与它们的取值（-C 目录、-c 配置、
# --git-dir 等），再看剩下的第一个非选项词是不是 commit。
is_git_commit() {
  local -a toks=()
  read -r -a toks <<<"$1"
  [ "${#toks[@]}" -gt 0 ] || return 1
  case "${toks[0]}" in
    git | */git) ;;
    *) return 1 ;;
  esac

  local i=1 skip=0 t
  while [ "$i" -lt "${#toks[@]}" ]; do
    t="${toks[$i]}"
    if [ "$skip" = 1 ]; then
      skip=0
      i=$((i + 1))
      continue
    fi
    case "$t" in
      -c | -C | --git-dir | --work-tree | --namespace | --exec-path | --config-env | --attr-source)
        skip=1
        ;;
      -*) ;;
      commit) return 0 ;;
      *) return 1 ;;
    esac
    i=$((i + 1))
  done
  return 1
}

# 按 ; && || | 把命令行切成几段，用 NUL 分隔输出。引号里的分隔符不算，
# 换行同理：引号没闭合时换行属于信息本身，要留在同一段里，否则
# `git commit -m "第一行<换行>第二行"` 会被切成两段，多行信息就漏判了。
# 用 NUL 而不是换行分隔，是因为调用方按行读会把这种跨行段重新切开。
split_segments() {
  printf '%s\n' "$1" | awk '
    {
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "\"" && !sq) { dq = !dq; seg = seg c; continue }
        if (c == "'"'"'" && !dq) { sq = !sq; seg = seg c; continue }
        if (!dq && !sq) {
          if (substr($0, i, 2) == "&&" || substr($0, i, 2) == "||") {
            printf "%s%c", seg, 0; seg = ""; i++; continue
          }
          if (c == ";" || c == "|") { printf "%s%c", seg, 0; seg = ""; continue }
        }
        seg = seg c
      }
      if (dq || sq) { seg = seg "\n" } else { printf "%s%c", seg, 0; seg = "" }
    }
    END { if (seg != "") printf "%s%c", seg, 0 }
  '
}

# 找出命令行里真正执行 git 提交的那一段，找到就打印出来。
# 逐段判——这样 `echo "git commit"`、日志里搜 commit、`git commit-tree` 都不会误判。
find_commit_segment() {
  local -a segs=()
  local seg trimmed
  mapfile -d '' -t segs < <(split_segments "$1")
  for seg in "${segs[@]}"; do
    trimmed="${seg#"${seg%%[![:space:]]*}"}"
    if is_git_commit "$trimmed"; then
      printf '%s' "$trimmed"
      return 0
    fi
  done
  return 1
}

# ---------- 提交信息 ----------
# 团队格式是 `<type>: <中文描述>`，只有一行。下面三条判定都只看命令行文本，
# 不碰工作副本，所以在非仓库目录里也照样拦。

# 匹配 -m / --message 的值：带引号的整段，或单个非空白词（-mMSG 粘写）。
# 短选项组里的 m 也能命中，所以 `-am "x"` 一样取得到信息。
MESSAGE_RE='(--message=|-m|--message)[[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:]]*)'

# 剥掉选项名与成对的引号，只留信息正文。
strip_message_flag() {
  local hit="$1" v
  case "$hit" in
    --message=*) v="${hit#--message=}" ;;
    --message*) v="${hit#--message}" ;;
    -m*) v="${hit#-m}" ;;
    *) v="$hit" ;;
  esac
  v="${v#"${v%%[![:space:]]*}"}"
  case "$v" in
    \"*\") v="${v#\"}"; v="${v%\"}" ;;
    \'*\') v="${v#\'}"; v="${v%\'}" ;;
  esac
  printf '%s\n' "$v"
}

# 收齐这一段里每处 -m / --message 的值，一条一行。
message_values() {
  local tok v
  while IFS= read -r tok; do
    [ -n "$tok" ] && strip_message_flag "$tok"
  done < <(printf '%s\n' "$1" | grep -oE "$MESSAGE_RE" || true)

  # 短选项组里的 m：-am "x"、-am"x"，m 后面剩的就是信息
  while IFS= read -r tok; do
    v="${tok#*m}"
    [ -n "$v" ] && strip_message_flag "$v"
  done < <(printf '%s\n' "$1" | tr ' ' '\n' | grep -E '^-[a-zA-Z]*m' || true)
}

# 去掉引号包裹的内容，剩下的才用来数选项：否则信息正文里出现 "-m" 会被当成第二处标志。
strip_quoted() {
  printf '%s\n' "$1" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g"
}

# -m / --message 出现的次数。两处以上就是多段正文。
message_flag_count() {
  strip_quoted "$1" | tr ' ' '\n' | grep -cE '^(-[a-zA-Z]*m|--message)' || true
}

# 有没有给信息的能力：-m / --message / -F / --file / -C / --reuse-message /
# --no-edit / --fixup= / --squash= / --template。都没给时 git 会打开编辑器。
has_message_source() {
  local -a toks=()
  read -r -a toks <<<"$1"
  local t
  for t in "${toks[@]}"; do
    case "$t" in
      -m | -m* | --message | --message=*) return 0 ;;
      -F | -F* | --file | --file=*) return 0 ;;
      -C | -C* | --reuse-message | --reuse-message=*) return 0 ;;
      --no-edit | --fixup=* | --squash=* | --template | --template=*) return 0 ;;
      -[a-zA-Z]*m) return 0 ;;
    esac
  done
  return 1
}

# 引号跨行：某一行结束时双引号或单引号还没闭合，说明信息里带了换行。
has_cross_line_quote() {
  printf '%s\n' "$1" | awk '
    {
      dq = 0; sq = 0
      n = length($0)
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (c == "\"" && !sq) dq = !dq
        else if (c == "'"'"'" && !dq) sq = !sq
      }
      open[NR] = (dq || sq)
    }
    END {
      for (i = 1; i < NR; i++) if (open[i]) exit 0
      exit 1
    }
  '
}

# -F 文件的行数，一条一行。粘写形式（-Fmsg.txt、--file=msg.txt）在这里取；
# 值单独成一个参数的形式由 file_line_count_split 取。
# 输出 - 表示信息走标准输入，读不到内容。
file_line_count() {
  local tok path
  for tok in $1; do
    case "$tok" in
      --file=* | -F?*)
        path="${tok#--file=}"
        path="${path#-F}"
        if [ -f "$path" ] && [ -r "$path" ]; then
          wc -l <"$path"
        fi
        ;;
    esac
  done
}

file_line_count_split() {
  local prev="" tok
  for tok in $1; do
    case "$prev" in
      -F | --file)
        if [ "$tok" = "-" ]; then
          printf '%s\n' "-"
        elif [ -f "$tok" ] && [ -r "$tok" ]; then
          wc -l <"$tok"
        fi
        ;;
    esac
    prev="$tok"
  done
}

# -F 文件的首行。文件本身就是提交信息，首行就是信息全文——真有多行的话
# 上面那条已经拦下了，这里只判格式。
file_first_line() {
  local tok path prev=""
  for tok in $1; do
    case "$tok" in
      --file=* | -F?*)
        path="${tok#--file=}"
        path="${path#-F}"
        if [ -f "$path" ] && [ -r "$path" ]; then head -n 1 -- "$path"; fi
        ;;
    esac
  done
  for tok in $1; do
    case "$prev" in
      -F | --file)
        if [ "$tok" != "-" ] && [ -f "$tok" ] && [ -r "$tok" ]; then head -n 1 -- "$tok"; fi
        ;;
    esac
    prev="$tok"
  done
}

# 行首是 `<type>(` 就算带范围括号。前后空白与大小写都不影响判定。
has_scope_prefix() {
  local probe="${1,,}"
  [[ "$probe" =~ ^(feat|fix|refactor|perf|docs|style|test|chore|build|ci|revert)[[:space:]]*\( ]]
}

report_message_block() {
  local kind="$1" msg="$2"
  {
    case "$kind" in
      scope)
        echo "提交被拦下：提交信息前缀带了范围括号"
        echo
        echo "收到的提交信息：$msg"
        ;;
      multiline)
        echo "提交被拦下：提交信息不是单行"
        echo
        echo "问题：$msg"
        ;;
      missing)
        echo "提交被拦下：没有给提交信息"
        ;;
    esac
    echo
    echo "本团队格式是 <type>: <中文描述>，只有一行，前缀后面直接跟半角冒号加空格。"
    echo "要指明模块或接口，把名字写进中文描述里："
    echo
    echo "  写成   git commit -m \"fix: 门禁记录统计接口补齐无数据的区域与操作类型\""
    echo "  不写   git commit -m \"fix(doorRecord): 统计接口补齐无数据的区域与操作类型\""
    echo
    case "$kind" in
      multiline)
        echo "多个 -m、引号跨行、-F 文件多行，git 会把它们拼成第二段正文，本团队不写正文。"
        echo "一行说不清说明这次提交装的事太多，拆成多次提交。"
        ;;
      missing)
        echo "非交互环境里不带 -m 的 git commit 会打开编辑器，命令一直卡住。"
        echo "要沿用上一条信息就写 git commit --amend --no-edit。"
        ;;
    esac
    echo
    echo "改好命令后重新执行刚才的提交。"
  } >&2
  exit 2
}

check_commit_message() {
  local seg="$1" msg count=0

  # 先看有没有信息可用：编辑器卡住比格式错更耗时间
  if ! has_message_source "$seg"; then
    report_message_block missing ""
  fi

  count=$(message_flag_count "$seg")
  if [ "${count:-0}" -gt 1 ]; then
    report_message_block multiline "一次提交给了 ${count} 处 -m / --message"
  fi

  if has_cross_line_quote "$seg"; then
    report_message_block multiline "提交信息的引号跨了行：$(printf '%s' "$seg" | head -n 1) ..."
  fi

  while IFS= read -r msg; do
    case "$msg" in
      "") continue ;;
      "-") report_message_block multiline "-F - 从标准输入读信息，读不到内容，无法保证单行" ;;
    esac
    [ "$msg" -gt 1 ] 2>/dev/null &&
      report_message_block multiline "-F 指向的文件有 $msg 行，git 会把整份文件当提交信息"
  done < <(file_line_count "$seg"; file_line_count_split "$seg")

  while IFS= read -r msg; do
    [ -n "$msg" ] || continue
    has_scope_prefix "$msg" || continue
    report_message_block scope "$msg"
  done < <(message_values "$seg"; file_first_line "$seg")
}

# ---------- 工作副本状态 ----------

# 提交目标目录：`git -C <目录>` 里最后一个取值，没有就用当前目录。
resolve_repo_dir() {
  local seg="$1" cwd="$2" prev="" tok dir=""
  for tok in $seg; do
    [ "$prev" = "-C" ] && dir="$tok"
    prev="$tok"
  done
  printf '%s' "${dir:-$cwd}"
}

# 变基、摘樱桃、合并进行中时 HEAD 本来就是游离的，那不算异常。
in_progress_op() {
  local gitdir="$1"
  [ -e "$gitdir/MERGE_HEAD" ] && return 0
  [ -e "$gitdir/CHERRY_PICK_HEAD" ] && return 0
  [ -e "$gitdir/REVERT_HEAD" ] && return 0
  [ -d "$gitdir/rebase-merge" ] && return 0
  [ -d "$gitdir/rebase-apply" ] && return 0
  return 1
}

report_state_block() {
  local repo="$1" kind="$2" detail="$3" dirty="$4"
  {
    case "$kind" in
      detached)
        echo "提交被拦下：处于 detached HEAD。在那上面提交的改动不属于任何分支，切走就找不回来。"
        ;;
      behind)
        echo "提交被拦下：本地落后于远端，先拉最新再提交。"
        ;;
      diverged)
        echo "提交被拦下：本地与远端分叉，两边各有一批对方没有的提交。"
        ;;
    esac
    echo
    echo "仓库：$repo"
    if [ -n "$detail" ]; then
      echo "$detail"
    fi
    echo
    if [ "$kind" = "detached" ]; then
      echo "按顺序做："
      echo "  1. git switch -c <新分支名>，把当前改动落到分支上"
      echo "  2. 重新执行刚才的提交"
      exit 2
    fi
    echo "按顺序做："
    if [ "$dirty" = 1 ]; then
      echo "  1. git stash push -u —— 工作区有未提交改动，不先收起来，变基会被 git 拒绝"
      echo "  2. git fetch origin"
      echo "  3. git pull --rebase"
      echo "  4. 有冲突就打开文件清干净 <<<<<<< / ======= / >>>>>>> 三种标记，git add 之后 git rebase --continue"
      echo "  5. git stash pop —— 把改动放回来"
      echo "  6. 重新执行刚才的提交"
    else
      echo "  1. git fetch origin"
      echo "  2. git pull --rebase"
      echo "  3. 有冲突就打开文件清干净 <<<<<<< / ======= / >>>>>>> 三种标记，git add 之后 git rebase --continue"
      echo "  4. 重新执行刚才的提交"
    fi
  } >&2
  exit 2
}

check_repo_state() {
  local repo="$1" gitdir branch local_sha remote_sha up remote rbranch dirty=""

  # --absolute-git-dir 在旧版 git 上没有，退回相对路径再自己补全
  gitdir=$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null) ||
    gitdir=$(git -C "$repo" rev-parse --git-dir 2>/dev/null) || return 0
  [ -n "$gitdir" ] || return 0
  case "$gitdir" in
    /*) ;;
    *) gitdir="$repo/$gitdir" ;;
  esac

  branch=$(git -C "$repo" symbolic-ref --short -q HEAD 2>/dev/null) || branch=""
  if [ -z "$branch" ]; then
    in_progress_op "$gitdir" && return 0
    report_state_block "$repo" detached "" ""
  fi

  # 上游没配（新分支第一次提交）时无从比较，放行
  up=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || return 0
  [ -n "$up" ] || return 0
  remote="${up%%/*}"
  rbranch="${up#*/}"
  [ "$remote" != "$up" ] || return 0

  local_sha=$(git -C "$repo" rev-parse HEAD 2>/dev/null) || return 0
  [ -n "$local_sha" ] || return 0

  # ls-remote 只读远端引用，不动本地状态；网络慢时给它设个上限
  if command -v timeout >/dev/null 2>&1; then
    remote_sha=$(timeout 10 git -C "$repo" ls-remote --heads "$remote" "refs/heads/$rbranch" 2>/dev/null | awk 'NR==1{print $1}')
  else
    remote_sha=$(git -C "$repo" ls-remote --heads "$remote" "refs/heads/$rbranch" 2>/dev/null | awk 'NR==1{print $1}')
  fi
  # 远端不可达或分支在远端还不存在：判定不了，放行
  [ -n "$remote_sha" ] || return 0
  [ "$remote_sha" = "$local_sha" ] && return 0

  # 工作区有未提交改动时，变基会被 git 拒绝，提示里要先给暂存这一步
  [ -n "$(git -C "$repo" status --porcelain 2>/dev/null | head -n 1)" ] && dirty=1

  if git -C "$repo" merge-base --is-ancestor "$local_sha" "$remote_sha" 2>/dev/null; then
    report_state_block "$repo" behind "远端 $remote/$rbranch 上有本地还没有的提交" "$dirty"
  fi
  # 本地领先：这些提交本来就等着推上去，放行
  git -C "$repo" merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null && return 0
  report_state_block "$repo" diverged "远端 $remote/$rbranch 与本地各自有新提交" "$dirty"
}

main() {
  local raw
  raw=$(cat)
  [ -n "$raw" ] || exit 0

  local -a fields=()
  mapfile -d '' -t fields < <(parse_input "$raw")
  [ "${#fields[@]}" -eq 3 ] || exit 0

  local tool="${fields[0]}" cwd="${fields[1]}" cmd="${fields[2]}"
  [ "$tool" = "Bash" ] || exit 0
  [ -n "$cmd" ] || exit 0

  local seg
  seg=$(find_commit_segment "$cmd") || exit 0

  # 信息格式只看命令行，与仓库状态无关，先判：提交被拦时提示更直接
  check_commit_message "$seg"

  local repo
  repo=$(resolve_repo_dir "$seg" "$cwd")
  [ -n "$repo" ] || exit 0
  [ -d "$repo" ] || exit 0
  check_repo_state "$repo"
}

main
