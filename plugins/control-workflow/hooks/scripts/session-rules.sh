#!/usr/bin/env bash
# 会话开始时把团队约定注入上下文。
#
# 规则正文放在 hooks/session-rules.txt，改规则只改那个文件。
# 用纯文本 stdout 输出：Claude Code 会把它作为 SessionStart 上下文注入。
# 同环境下的 caveman 插件用的就是这条路径（其 hooks 里是 node 直接 write 文本），
# 比 JSON 包装少一层出错可能——中文与引号都不需要转义。
#
# 任何失败都静默退出，绝不能因为提醒文本读不到就让会话启动失败。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../session-rules.txt"

[ -f "$RULES_FILE" ] || exit 0

cat "$RULES_FILE"
