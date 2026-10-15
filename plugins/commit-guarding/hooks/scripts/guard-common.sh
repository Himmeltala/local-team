#!/usr/bin/env bash
# svn 与 git 两份提交闸门共用的部分：钩子输入解析、提交信息取值、前缀判定、提示输出。
#
# 判据不在这里：svn 的落后与冲突读 `svn status --xml -u`，git 的落后读 `git ls-remote`，
# 没有可复用的判定，各自留在自己的脚本里。
#
# 任何异常一律放行：闸门只拦确定坏的情况，自身出故障时绝不能堵住提交。

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

# 读钩子输入，把 tool_name、cwd、command 三段写进全局数组 HOOK_FIELDS。
# cwd 不在这里消化：svn 闸门的 resolve_target 要用它。
# 不是 Bash 调用、缺命令、JSON 解析失败时返回 1。
hook_input() {
  local raw
  raw=$(cat)
  [ -n "$raw" ] || return 1

  HOOK_FIELDS=()
  mapfile -d '' -t HOOK_FIELDS < <(parse_input "$raw")
  [ "${#HOOK_FIELDS[@]}" -eq 3 ] || return 1

  [ "${HOOK_FIELDS[0]}" = "Bash" ] || return 1
  [ -n "${HOOK_FIELDS[2]}" ] || return 1
}

# 匹配 -m / --message 的值：带引号的整段，或单个非空白词（-mMSG 粘写）。
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

# 行首是 <type>( 就算带范围括号。前后空白与大小写都不影响判定。
has_scope_prefix() {
  local probe="${1,,}"
  [[ "$probe" =~ ^(feat|fix|refactor|perf|docs|style|test|chore|build|ci|revert)[[:space:]]*\( ]]
}

# kind 取 scope、multiline、missing。提示里的示例不写具体命令，
# 两份闸门共用同一段文本，不让 svn 的提示里出现 git 字样。
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
    echo "  写成   fix: 门禁记录统计接口补齐无数据的区域与操作类型"
    echo "  不写   fix(doorRecord): 统计接口补齐无数据的区域与操作类型"
    echo
    case "$kind" in
      multiline)
        echo "多个 -m、引号跨行、-F 文件多行，提交命令会把它们拼成第二段正文，本团队不写正文。"
        echo "一行说不清说明这次提交装的事太多，拆成多次提交。"
        ;;
      missing)
        echo "非交互环境里不带 -m 的提交会打开编辑器，命令一直卡住。"
        echo "要沿用上一条信息就写 --amend --no-edit。"
        ;;
    esac
    echo
    echo "改好命令后重新执行刚才的提交。"
  } >&2
  exit 2
}
