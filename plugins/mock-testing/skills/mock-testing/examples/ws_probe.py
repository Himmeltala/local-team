#!/usr/bin/env python3
"""WebSocket 观察器模板：不上界面，直接看服务端广播出来的报文。

界面上的数字在跳，只能说明某条通道活着，不能说明业务分支走对了。
这个脚本替代界面，把每次广播的类型与原文打出来。

用法：
    python3 ws_probe.py --host 127.0.0.1 --port 8765 --path /ws
    python3 ws_probe.py --heartbeat 15          # 每 15 秒发一次心跳，保活

注意：
    有的服务端只保留最新一个连接，新连接进来会把旧连接踢掉。
    观察器与界面不要同时连，两边会互相顶替，看到的现象会互相矛盾。
"""
import argparse
import base64
import json
import os
import socket
import struct


def handshake(sock, host, port, path):
    """完成握手，返回握手响应之后可能已经到达的剩余字节。"""
    key = base64.b64encode(os.urandom(16)).decode()
    request = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        "Sec-WebSocket-Version: 13\r\n\r\n"
    )
    sock.sendall(request.encode("utf-8"))
    buf = b""
    while b"\r\n\r\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("握手失败：连接被对端关闭")
        buf += chunk
    head, leftover = buf.split(b"\r\n\r\n", 1)
    status_line = head.split(b"\r\n", 1)[0].decode("utf-8", "replace")
    if "101" not in status_line:
        raise ConnectionError(f"握手失败：{status_line}")
    # 首条广播可能和握手响应同包到达，剩的字节要留着，不能丢
    return leftover


def send_frame(sock, payload, opcode=0x1):
    data = payload.encode("utf-8") if isinstance(payload, str) else payload
    header = bytearray([0x80 | opcode])
    mask = os.urandom(4)
    length = len(data)
    if length < 126:
        header.append(0x80 | length)
    elif length < 65536:
        header.append(0x80 | 126)
        header += struct.pack("!H", length)
    else:
        header.append(0x80 | 127)
        header += struct.pack("!Q", length)
    header += mask
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
    sock.sendall(bytes(header) + masked)


class FrameReader:
    """按帧读。握手剩余的字节先垫进缓冲，避免丢掉首帧。"""

    def __init__(self, sock, leftover=b""):
        self.sock = sock
        self.buf = leftover

    def read_exact(self, count):
        while len(self.buf) < count:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("连接已关闭")
            self.buf += chunk
        out, self.buf = self.buf[:count], self.buf[count:]
        return out

    def read_frame(self):
        b1, b2 = self.read_exact(2)
        fin = bool(b1 & 0x80)
        opcode = b1 & 0x0F
        masked = bool(b2 & 0x80)
        length = b2 & 0x7F
        if length == 126:
            length = struct.unpack("!H", self.read_exact(2))[0]
        elif length == 127:
            length = struct.unpack("!Q", self.read_exact(8))[0]
        mask = self.read_exact(4) if masked else None
        payload = self.read_exact(length) if length else b""
        if mask:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        return fin, opcode, payload


def label_of(payload):
    text = payload.decode("utf-8", "replace")
    try:
        obj = json.loads(text)
        # 广播类型字段各家命名不同，常见 code 与 cmd 两种
        return (obj.get("code") or obj.get("cmd") or "unknown"), text
    except json.JSONDecodeError:
        return "raw", text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--path", default="/ws")
    ap.add_argument("--heartbeat", type=int, default=0, help="心跳间隔秒数，0 表示不发")
    ap.add_argument("--heartbeat-body", default='{"type":"ping"}')
    args = ap.parse_args()

    sock = socket.create_connection((args.host, args.port), timeout=10)
    leftover = handshake(sock, args.host, args.port, args.path)
    print(f"[ws] 已连接 ws://{args.host}:{args.port}{args.path}", flush=True)
    sock.settimeout(args.heartbeat if args.heartbeat else 3600)
    reader = FrameReader(sock, leftover)

    fragments = []
    fragment_opcode = None

    while True:
        try:
            fin, opcode, payload = reader.read_frame()
        except socket.timeout:
            # 没开心跳时，超时只代表这一段空闲，继续等
            if args.heartbeat:
                send_frame(sock, args.heartbeat_body)
                print("[ws] 已发心跳", flush=True)
            continue
        except (ConnectionError, OSError) as exc:
            print(f"[ws] {exc}", flush=True)
            return

        if opcode == 0x9:
            send_frame(sock, payload, opcode=0xA)
            print("[ws] 收到 ping，已回 pong", flush=True)
            continue
        if opcode == 0xA:
            continue
        if opcode == 0x8:
            print("[ws] 对端关闭连接", flush=True)
            return

        if opcode == 0x0:
            # 续帧：接着上一段未完成的消息
            if fragment_opcode is None:
                continue
            fragments.append(payload)
            if not fin:
                continue
            payload, opcode = b"".join(fragments), fragment_opcode
            fragments, fragment_opcode = [], None
        elif opcode in (0x1, 0x2):
            if not fin:
                # 分片消息的开头，等续帧拼完再打印
                fragment_opcode, fragments = opcode, [payload]
                continue
        else:
            continue

        label, text = label_of(payload)
        print(f"[{label}] {text}", flush=True)


if __name__ == "__main__":
    main()
