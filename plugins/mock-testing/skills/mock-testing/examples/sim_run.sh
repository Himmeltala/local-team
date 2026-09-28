#!/usr/bin/env bash
# 起停脚本模板：把桩、被测后端、日志跟踪一次拉起来，并提供 stop / status / check。
#
# 用法：
#   ./sim_run.sh                起桩与被测后端，跟踪日志
#   ./sim_run.sh --no-app       只起桩，后端自己另外起
#   ./sim_run.sh stop           停掉本次起的进程
#   ./sim_run.sh status         看端口占用
#   ./sim_run.sh check          打印关键文件与进程状态
#
# 改造办法：把 STUBS、APP_PORT 与 APP_CMD 换成自己项目的进程与端口即可。
#           被测后端用复合命令启动（如 cd x && java -jar ...）也没问题。
set -Eeuo pipefail

RUN_DIR="${RUN_DIR:-/tmp/sim-demo}"
PID_DIR="$RUN_DIR/pids"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$PID_DIR" "$LOG_DIR"

# 本次要起的桩：名字|端口|启动命令
STUBS=(
  "http-stub|18080|python3 $(dirname "$0")/http_stub.py --port 18080"
)
APP_NAME="backend"
APP_PORT=18090
APP_CMD="${APP_CMD:-}"
LOG_KEY='收到|已下发|校验通过|处理完成|ERROR'

usage() {
  sed -n '2,12p' "$0"
}

# 端口上监听的进程号，取不到返回空
port_pid() {
  local port="$1"
  ss -lntpH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2
}

require_free() {
  local name="$1" port="$2" pid
  pid="$(port_pid "$port" || true)"
  if [[ -n "$pid" ]]; then
    echo "端口 $port 已被占用（pid=$pid），先确认是不是上一轮没停干净：$name" >&2
    exit 1
  fi
}

start_proc() {
  local name="$1" port="$2" cmd="$3"
  require_free "$name" "$port"
  local log="$LOG_DIR/$name.log" launcher pid waited=0
  bash -c "$cmd" >"$log" 2>&1 &
  launcher=$!
  while (( waited < 150 )); do
    pid="$(port_pid "$port" || true)"
    if [[ -n "$pid" ]]; then
      # 记真正在监听的进程号：启动命令是复合命令时，它与外层 shell 的进程号不同
      echo "$pid" >"$PID_DIR/$name.pid"
      echo "已就绪：$name pid=$pid 端口=$port 日志=$log"
      return 0
    fi
    if ! kill -0 "$launcher" 2>/dev/null; then
      echo "$name 已退出，日志末尾：" >&2
      tail -20 "$log" >&2
      exit 1
    fi
    sleep 0.2
    waited=$((waited + 1))
  done
  echo "$name 在 30 秒内未就绪，日志末尾：" >&2
  tail -20 "$log" >&2
  exit 1
}

start_app() {
  if [[ -z "$APP_CMD" ]]; then
    echo "未设置 APP_CMD，跳过后端启动（需要时用 APP_CMD='...' ./sim_run.sh 传入）"
    return 0
  fi
  start_proc "$APP_NAME" "$APP_PORT" "$APP_CMD"
}

stop_all() {
  local pid_file name pid
  for pid_file in "$PID_DIR"/*.pid; do
    [[ -e "$pid_file" ]] || continue
    name="$(basename "$pid_file" .pid)"
    pid="$(cat "$pid_file")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      echo "已停止：$name pid=$pid"
    fi
    rm -f "$pid_file"
  done
}

# 端口列表从 STUBS 推导，往数组里加桩之后 status 自动跟上
all_ports() {
  local entry port
  echo "$APP_PORT"
  for entry in "${STUBS[@]}"; do
    IFS='|' read -r _ port _ <<<"$entry"
    echo "$port"
  done
}

status() {
  local port pid
  while read -r port; do
    pid="$(port_pid "$port" || true)"
    if [[ -n "$pid" ]]; then
      echo "端口 $port 监听中 pid=$pid"
    else
      echo "端口 $port 空闲"
    fi
  done < <(all_ports)
}

check() {
  echo "运行目录：$RUN_DIR"
  ls -l "$PID_DIR" "$LOG_DIR" 2>/dev/null || true
  status
}

tail_logs() {
  # 记录起始行号，只打增量，并按关键字过滤，避免刷屏把关键行冲走
  declare -A offsets
  local log from total
  while true; do
    for log in "$LOG_DIR"/*.log; do
      [[ -e "$log" ]] || continue
      from="${offsets[$log]:-0}"
      total="$(wc -l <"$log")"
      if (( total > from )); then
        tail -n +"$((from + 1))" "$log" | grep -E "$LOG_KEY" | sed "s|^|[$(basename "$log" .log)] |" || true
        offsets["$log"]="$total"
      fi
    done
    sleep 3
  done
}

case "${1:-}" in
  stop) stop_all ;;
  status) status ;;
  check) check ;;
  -h|--help) usage ;;
  *)
    [[ "${1:-}" == "--no-app" ]] || start_app
    for entry in "${STUBS[@]}"; do
      IFS='|' read -r name port cmd <<<"$entry"
      start_proc "$name" "$port" "$cmd"
    done
    trap 'echo; echo "收到中断，停掉本次起的进程"; stop_all' INT TERM
    tail_logs
    ;;
esac
