#!/usr/bin/env python3
"""假上游桩模板：顶替一个不可达的云端或第三方入口，并主动下发一条指令。

与 http_stub.py 的区别：这个桩不只是被动应答，还要在被问到时"下发"东西，
用于测那种"本机拉取指令、再按指令干活"的链路。

用法：
    python3 cloud_stub.py --port 18081 --payload-url http://127.0.0.1:19000/pkg.zip --md5 <md5>
    python3 cloud_stub.py --port 18081 --payload-url ... --tag t0001 --once   # 只下发一次

    模拟云端下发：
    curl -sX POST http://127.0.0.1:18081/anything -H 'Content-Type: application/json' \
      -d '{"url":"/admin/command/getLatest"}'

要点：
    1. 被测方通常只看请求体里的目标地址字段，路径本身可能任意，所以按 body 匹配。
    2. 返回体统一包一层，形状照被替掉的那份源码抄。
    3. 指令的序号字段往往有隐含格式（例如"年份-后缀"，用于分表），照抄别自创。
    4. 本桩按代理语义工作：路径不参与匹配，未命中目标地址时也返回 200 加空数据，
       这是代理入口的真实行为，所以不套用 SKILL.md 里"未实现路径兜底 404"那条规则。
       换成非代理语义的上游时，按那份源码的失败形状补兜底。
"""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ARGS = None
SENT = False


def build_command():
    payload = {
        "url": ARGS.payload_url,
        "method": "get",
        # 常见的"版本号==摘要"格式，照被替掉的那份源码抄
        "data": f"{ARGS.version}=={ARGS.md5}",
    }
    return {
        "id": ARGS.command_id,
        # 序号前缀常被用于分表，格式错了对端不认
        "seq": f"{time.localtime().tm_year}-{ARGS.tag}",
        "deviceId": ARGS.device_id,
        "type": ARGS.command_type,
        # 有的字段是二次编码的 JSON 字符串，照抄
        "payload": json.dumps(payload, ensure_ascii=False),
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        print(f"[cloud] GET {self.path}", flush=True)
        self.reply(200, {"code": 200, "msg": "success", "data": None})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length).decode("utf-8", "replace") if length else ""
        target = ""
        try:
            target = str(json.loads(raw or "{}").get("url") or "")
        except json.JSONDecodeError:
            target = ""
        print(f"[cloud] POST {urlparse(self.path).path} target={target}", flush=True)

        if "getLatest" in target:
            global SENT
            if ARGS.once and SENT:
                print("[cloud] --once 只下发一次，本次返回空", flush=True)
                return self.reply(200, {"code": 200, "msg": "success", "data": None})
            data = build_command()
            SENT = True
            print(f"[cloud] 已下发指令 seq={data['seq']}", flush=True)
            self.reply(200, {"code": 200, "msg": "success", "data": data})
            return

        self.reply(200, {"code": 200, "msg": "success", "data": None})

    def reply(self, status, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        return


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=18081)
    ap.add_argument("--payload-url", required=True, help="指令里携带的下载地址")
    ap.add_argument("--md5", default="", help="指令里携带的摘要")
    ap.add_argument("--version", default="V0.0.1")
    ap.add_argument("--device-id", default="DEV-000")
    ap.add_argument("--command-type", default="ACTION:DEMO")
    ap.add_argument("--command-id", type=int, default=1)
    ap.add_argument("--tag", default="t0001", help="序号后缀，换一个就能重复测同一个场景")
    ap.add_argument("--once", action="store_true", help="只下发一次，便于测幂等")
    ARGS = ap.parse_args()

    server = ThreadingHTTPServer((ARGS.host, ARGS.port), Handler)
    print(f"[cloud] 监听 {ARGS.host}:{ARGS.port}，tag={ARGS.tag}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
