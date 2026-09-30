#!/usr/bin/env python3
"""HTTP 模拟服务模板：替掉一个还没就绪、不可达或本机起不来的对端服务。

只用标准库，起模拟服务不引入任何依赖。

用法：
    python3 http_stub.py --port 18080 --weight 12.345
    python3 http_stub.py --port 18080 --mode fail        # 对端返回业务失败
    python3 http_stub.py --port 18080 --mode bad         # 返回参数非法
    python3 http_stub.py --port 18080 --mode hang        # 挂起不返回，测超时分支

    curl "http://127.0.0.1:18080/api/weight"
    curl "http://127.0.0.1:18080/api/weight?value=9.5"     # 改模拟服务里的状态

改造办法：
    1. 把 dispatch 里的路由换成被测方真正会调到的，其余一律兜底 404。
    2. 返回体形状照被替掉的那份源码抄，成功与失败两种都要有。
    3. 默认只挂了 GET 与 POST。对端还用到 PUT、DELETE 时，照着补同名 do_ 方法。
"""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

# 模拟服务里的可变状态，用查询参数或子命令改，便于构造边界值
STATE = {"weight": 0.0}
MODE = "success"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self.dispatch("GET")

    def do_POST(self):
        self.dispatch("POST")

    def do_PUT(self):
        self.dispatch("PUT")

    def do_DELETE(self):
        self.dispatch("DELETE")

    def dispatch(self, method):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        query = parse_qs(parsed.query)
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length).decode("utf-8", "replace") if length else ""
        print(f"[stub] {method} {path} query={query} body={raw}", flush=True)

        if MODE == "hang":
            # 挂起不返回：测超时分支要先把被测方的超时阈值临时调小，否则等不起
            time.sleep(3600)
            return
        if MODE == "fail":
            return self.reply(200, {"code": 500, "msg": "模拟服务构造的业务失败"})
        if MODE == "bad":
            return self.reply(400, {"code": 400, "msg": "参数非法", "detail": "模拟服务构造的参数错误"})

        # 能改状态的写在读状态之前，顺序反了会永远读到旧值
        if path == "/api/weight" and method == "GET":
            if "value" in query:
                try:
                    STATE["weight"] = round(float(query["value"][0]), 3)
                except ValueError:
                    return self.reply(400, {"code": 400, "msg": f"无法识别的数值：{query['value'][0]}"})
                print(f"[stub] 状态已更新 weight={STATE['weight']}", flush=True)
            return self.reply(200, {"ok": True, "weight": STATE["weight"], "unit": "kg"})

        if path == "/api/report" and method == "POST":
            try:
                body = json.loads(raw or "{}")
            except json.JSONDecodeError:
                return self.reply(400, {"code": 400, "msg": "请求体不是合法 JSON 对象"})
            if not body.get("data"):
                return self.reply(400, {"code": 400, "msg": "缺少 data 字段"})
            return self.reply(200, {"code": 200, "msg": "success", "data": body["data"]})

        # 兜底必须带可读消息，否则"模拟服务没实现"会被误判成"链路断了"
        return self.reply(404, {"code": 404, "msg": f"模拟服务未实现：{method} {path}"})

    def reply(self, status, payload):
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
        print(f"[stub] 已返回 status={status} body={data.decode('utf-8')}", flush=True)

    def log_message(self, fmt, *args):
        # 压掉默认的逐请求访问日志，保留自己的两行
        return


def main():
    global MODE
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=18080)
    ap.add_argument("--weight", type=float, default=0.0, help="模拟服务启动时的初始值")
    ap.add_argument("--mode", default="success", choices=["success", "fail", "bad", "hang"],
                    help="故障注入：成功、业务失败、参数非法、挂起不返回")
    args = ap.parse_args()

    STATE["weight"] = round(args.weight, 3)
    MODE = args.mode

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"[stub] 监听 {args.host}:{args.port}，mode={MODE}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
