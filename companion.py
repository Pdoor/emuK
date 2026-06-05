from __future__ import annotations

import base64
import hashlib
import json
import os
import socket
import socketserver
import struct
import threading
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler
from pathlib import Path
from typing import Any
import ctypes
from ctypes import wintypes


APP_NAME = "emuK"
HOST = "0.0.0.0"
PORT = int(os.environ.get("EMUK_PORT", "8787"))
ROOT = Path(__file__).resolve().parent
WEB_ROOT = ROOT / "web"


INPUT_KEYBOARD = 1
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
KEYEVENTF_SCANCODE = 0x0008
MAPVK_VK_TO_VSC = 0


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ctypes.POINTER(ctypes.c_ulong)),
    ]


class INPUT_UNION(ctypes.Union):
    _fields_ = [("ki", KEYBDINPUT)]


class INPUT(ctypes.Structure):
    _fields_ = [("type", wintypes.DWORD), ("union", INPUT_UNION)]


SendInput = ctypes.windll.user32.SendInput
MapVirtualKeyW = ctypes.windll.user32.MapVirtualKeyW


VK = {
    "backspace": 0x08,
    "tab": 0x09,
    "enter": 0x0D,
    "shift": 0x10,
    "ctrl": 0x11,
    "control": 0x11,
    "alt": 0x12,
    "pause": 0x13,
    "capslock": 0x14,
    "escape": 0x1B,
    "esc": 0x1B,
    "space": 0x20,
    "pageup": 0x21,
    "pagedown": 0x22,
    "end": 0x23,
    "home": 0x24,
    "left": 0x25,
    "up": 0x26,
    "right": 0x27,
    "down": 0x28,
    "printscreen": 0x2C,
    "insert": 0x2D,
    "delete": 0x2E,
    "win": 0x5B,
    "meta": 0x5B,
    "apps": 0x5D,
    "numlock": 0x90,
    "scrolllock": 0x91,
}

for i in range(10):
    VK[str(i)] = 0x30 + i
for i, char in enumerate("abcdefghijklmnopqrstuvwxyz"):
    VK[char] = 0x41 + i
for i in range(1, 13):
    VK[f"f{i}"] = 0x70 + i - 1


PUNCTUATION = {
    ";": 0xBA,
    "=": 0xBB,
    ",": 0xBC,
    "-": 0xBD,
    ".": 0xBE,
    "/": 0xBF,
    "`": 0xC0,
    "[": 0xDB,
    "\\": 0xDC,
    "]": 0xDD,
    "'": 0xDE,
}


def _input(vk: int = 0, scan: int = 0, flags: int = 0) -> INPUT:
    return INPUT(
        type=INPUT_KEYBOARD,
        union=INPUT_UNION(ki=KEYBDINPUT(vk, scan, flags, 0, None)),
    )


def _send(*items: INPUT) -> None:
    array_type = INPUT * len(items)
    array = array_type(*items)
    sent = SendInput(len(items), array, ctypes.sizeof(INPUT))
    if sent != len(items):
        raise ctypes.WinError()


def press_vk(vk: int) -> None:
    scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC)
    _send(_input(vk, scan, 0), _input(vk, scan, KEYEVENTF_KEYUP))


def down_vk(vk: int) -> None:
    scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC)
    _send(_input(vk, scan, 0))


def up_vk(vk: int) -> None:
    scan = MapVirtualKeyW(vk, MAPVK_VK_TO_VSC)
    _send(_input(vk, scan, KEYEVENTF_KEYUP))


def type_text(text: str) -> None:
    events: list[INPUT] = []
    for char in text:
        code = ord(char)
        events.append(_input(0, code, KEYEVENTF_UNICODE))
        events.append(_input(0, code, KEYEVENTF_UNICODE | KEYEVENTF_KEYUP))
    if events:
        _send(*events)


def key_to_vk(key: str) -> int | None:
    normalized = key.strip().lower().replace(" ", "")
    if normalized in VK:
        return VK[normalized]
    if normalized in PUNCTUATION:
        return PUNCTUATION[normalized]
    return None


def tap_key(key: str) -> None:
    vk = key_to_vk(key)
    if vk is not None:
        press_vk(vk)
        return
    if len(key) == 1:
        type_text(key)


def combo(keys: list[str]) -> None:
    if not keys:
        return
    vks = [key_to_vk(key) for key in keys]
    if any(vk is None for vk in vks):
        return
    for vk in vks[:-1]:
        down_vk(vk or 0)
        time.sleep(0.01)
    press_vk(vks[-1] or 0)
    for vk in reversed(vks[:-1]):
        up_vk(vk or 0)
        time.sleep(0.01)


def local_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def handle_message(message: dict[str, Any]) -> dict[str, Any]:
    kind = message.get("type")
    if kind == "text":
        type_text(str(message.get("text", "")))
    elif kind == "key":
        tap_key(str(message.get("key", "")))
    elif kind == "combo":
        keys = message.get("keys", [])
        if isinstance(keys, list):
            combo([str(key) for key in keys])
    elif kind == "ping":
        return {"type": "pong"}
    else:
        return {"type": "error", "message": f"Unknown command: {kind}"}
    return {"type": "ok"}


class EmuKHandler(SimpleHTTPRequestHandler):
    server_version = "emuK/1.0"

    def translate_path(self, path: str) -> str:
        clean = path.split("?", 1)[0].split("#", 1)[0]
        if clean == "/":
            clean = "/index.html"
        return str(WEB_ROOT / clean.lstrip("/"))

    def do_GET(self) -> None:
        clean_path = self.path.split("?", 1)[0]
        if clean_path == "/api/info":
            actual_port = self.server.server_address[1]
            self._json(
                {
                    "name": APP_NAME,
                    "host": local_ip(),
                    "port": actual_port,
                    "ws": f"ws://{local_ip()}:{actual_port}/ws",
                }
            )
            return
        if self.path.startswith("/ws"):
            self._websocket()
            return
        super().do_GET()

    def do_POST(self) -> None:
        clean_path = self.path.split("?", 1)[0]
        if clean_path != "/api/send":
            self.send_error(HTTPStatus.NOT_FOUND)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            message = json.loads(raw.decode("utf-8"))
            response = handle_message(message)
            self._json(response)
        except Exception as exc:
            self._json({"type": "error", "message": str(exc)}, HTTPStatus.BAD_REQUEST)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _json(self, payload: dict[str, Any], status: HTTPStatus = HTTPStatus.OK) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _websocket(self) -> None:
        key = self.headers.get("Sec-WebSocket-Key")
        if not key:
            self.send_error(HTTPStatus.BAD_REQUEST, "Missing websocket key")
            return

        accept = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()
        ).decode()
        self.send_response(HTTPStatus.SWITCHING_PROTOCOLS)
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()

        try:
            while True:
                data = self._read_ws_frame()
                if data is None:
                    break
                try:
                    response = handle_message(json.loads(data.decode("utf-8")))
                except Exception as exc:
                    response = {"type": "error", "message": str(exc)}
                self._write_ws_frame(json.dumps(response).encode("utf-8"))
        except (ConnectionError, OSError):
            pass

    def _read_ws_frame(self) -> bytes | None:
        header = self.rfile.read(2)
        if len(header) < 2:
            return None
        first, second = header
        opcode = first & 0x0F
        masked = second & 0x80
        length = second & 0x7F
        if opcode == 0x8:
            return None
        if length == 126:
            length = struct.unpack("!H", self.rfile.read(2))[0]
        elif length == 127:
            length = struct.unpack("!Q", self.rfile.read(8))[0]
        mask = self.rfile.read(4) if masked else b"\x00\x00\x00\x00"
        payload = self.rfile.read(length)
        return bytes(byte ^ mask[i % 4] for i, byte in enumerate(payload))

    def _write_ws_frame(self, payload: bytes) -> None:
        header = bytearray([0x81])
        length = len(payload)
        if length < 126:
            header.append(length)
        elif length < 65536:
            header.extend([126, *struct.pack("!H", length)])
        else:
            header.extend([127, *struct.pack("!Q", length)])
        self.wfile.write(bytes(header) + payload)
        self.wfile.flush()


class ThreadingHTTPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> None:
    server = None
    selected_port = PORT
    for candidate in range(PORT, PORT + 20):
        try:
            server = ThreadingHTTPServer((HOST, candidate), EmuKHandler)
            selected_port = candidate
            break
        except OSError:
            continue
    if server is None:
        raise OSError(f"Nessuna porta libera trovata tra {PORT} e {PORT + 19}")

    with server:
        ip = local_ip()
        print(f"{APP_NAME} companion avviato")
        print(f"Apri dal tablet: http://{ip}:{selected_port}")
        print("Premi Ctrl+C per uscire.")
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nChiusura...")


if __name__ == "__main__":
    main()
