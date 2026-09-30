#!/usr/bin/env bash
# 会话开始时把编码思维约定注入上下文，正文放在 hooks/session-rules.txt。
# 任何失败都静默退出，绝不因为提醒文本读不到就让会话启动失败。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="$SCRIPT_DIR/../session-rules.txt"

[ -f "$RULES_FILE" ] || exit 0

cat "$RULES_FILE"
