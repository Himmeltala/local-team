#!/usr/bin/env bash
# 会话开始时把 hooks/session-rules.txt 注入上下文，改规则只改那个文件。
# 任何失败都静默退出，不能因为提醒文本读不到就让会话启动失败。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../session-rules.txt"

[ -f "$RULES_FILE" ] || exit 0

cat "$RULES_FILE"
