from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import json
import mimetypes
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import urllib.parse
import urllib.request

import websocket


ROOT = Path(__file__).resolve().parents[1]
WEB_DIR = ROOT / "build" / "web"
OUT_DIR = ROOT / "real_compare_screenshots"
BACKEND = "http://localhost:3000"
WEB_FRONTEND = "http://localhost:8000"
VIEWPORT_WIDTH = 1530
VIEWPORT_HEIGHT = 900


class FlutterStaticHandler(BaseHTTPRequestHandler):
    def log_message(self, _format, *args):
        return

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/":
            target = WEB_DIR / "index.html"
        else:
            rel = urllib.parse.unquote(parsed.path).lstrip("/")
            target = (WEB_DIR / rel).resolve()
            try:
                target.relative_to(WEB_DIR.resolve())
            except ValueError:
                target = WEB_DIR / "index.html"
            if not target.is_file():
                target = WEB_DIR / "index.html"

        content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        if target.suffix == ".wasm":
            content_type = "application/wasm"
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)


class CdpClient:
    def __init__(self, url):
        self._socket = websocket.create_connection(url, timeout=8)
        self._next_id = 0

    def close(self):
        self._socket.close()

    def send(self, method, params=None):
        self._next_id += 1
        message_id = self._next_id
        self._socket.send(
            json.dumps({"id": message_id, "method": method, "params": params or {}})
        )
        while True:
            payload = json.loads(self._socket.recv())
            if payload.get("id") != message_id:
                continue
            if "error" in payload:
                raise RuntimeError(f"{method}: {payload['error']}")
            return payload.get("result", {})


def edge_path():
    candidates = [
        Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"),
        Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    found = shutil.which("msedge") or shutil.which("chrome")
    if found:
        return Path(found)
    raise RuntimeError("Microsoft Edge or Chrome was not found.")


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def login():
    body = json.dumps({"username": "admin", "password": "admin123"}).encode("utf-8")
    request = urllib.request.Request(
        f"{BACKEND}/api/auth/login",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def api_json(path, token):
    request = urllib.request.Request(
        f"{BACKEND}{path}",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def real_ids(token):
    books = api_json("/api/books", token)
    series = api_json("/api/v1/series", token)
    if not books:
        raise RuntimeError("No books in backend.")
    theme_book = next(
        (book for book in books if "乱世书" in str(book.get("title", ""))),
        books[0],
    )
    return books[0]["id"], theme_book["id"], (series[0]["id"] if series else None)


def js_string(value):
    return json.dumps(value, ensure_ascii=False)


def web_storage_script(auth):
    user = auth["user"]
    token = auth["token"]
    return f"""
localStorage.setItem('auth_token', {js_string(token)});
localStorage.setItem('user', JSON.stringify({js_string(user)}));
localStorage.setItem('server_url', {js_string(BACKEND)});
localStorage.setItem('active_url', {js_string(BACKEND)});
"""


def flutter_storage_script(auth):
    user = auth["user"]
    token = auth["token"]
    redirect_cache = {BACKEND: BACKEND}
    return f"""
localStorage.setItem('flutter.server_url', JSON.stringify({js_string(BACKEND)}));
localStorage.setItem('flutter.active_url', JSON.stringify({js_string(BACKEND)}));
localStorage.setItem('flutter.auth_token', JSON.stringify({js_string(token)}));
localStorage.setItem('flutter.user', JSON.stringify(JSON.stringify({js_string(user)})));
localStorage.setItem('flutter.redirect_cache', JSON.stringify(JSON.stringify({js_string(redirect_cache)})));
"""


def capture(browser, origin, target, output, storage_script, clicks=None, wheel_steps=0):
    profile = Path(tempfile.mkdtemp(prefix="ting-reader-real-shot-"))
    port = free_port()
    process = subprocess.Popen(
        [
            str(browser),
            "--headless=new",
            "--disable-gpu",
            "--disable-web-security",
            "--allow-running-insecure-content",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            f"--window-size={VIEWPORT_WIDTH},{VIEWPORT_HEIGHT}",
            "--remote-allow-origins=*",
            f"--user-data-dir={profile}",
            f"--remote-debugging-port={port}",
            origin,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    client = None
    try:
        version_url = f"http://127.0.0.1:{port}/json"
        targets = None
        deadline = time.time() + 12
        while time.time() < deadline:
            try:
                with urllib.request.urlopen(version_url, timeout=1) as response:
                    targets = json.loads(response.read().decode("utf-8"))
                break
            except Exception:
                time.sleep(0.2)
        if not targets:
            raise RuntimeError("Unable to connect to headless browser")

        target_info = next((item for item in targets if item.get("type") == "page"), targets[0])
        client = CdpClient(target_info["webSocketDebuggerUrl"])
        client.send("Page.enable")
        client.send("Runtime.enable")
        client.send(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": VIEWPORT_WIDTH,
                "height": VIEWPORT_HEIGHT,
                "deviceScaleFactor": 1,
                "mobile": False,
            },
        )
        time.sleep(1.0)
        client.send(
            "Runtime.evaluate",
            {"expression": storage_script + f"\nlocation.href = {js_string(target)};"},
        )
        time.sleep(7.0)
        for _ in range(wheel_steps):
            client.send(
                "Input.dispatchMouseEvent",
                {"type": "mouseWheel", "x": 1200, "y": 860, "deltaX": 0, "deltaY": 720},
            )
            time.sleep(0.25)
        for x, y in clicks or []:
            client.send(
                "Input.dispatchMouseEvent",
                {"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1},
            )
            client.send(
                "Input.dispatchMouseEvent",
                {"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1},
            )
            time.sleep(0.8)
        screenshot = client.send("Page.captureScreenshot", {"format": "png", "fromSurface": True})
        output.write_bytes(base64.b64decode(screenshot["data"]))
        print(output)
    finally:
        if client is not None:
            client.close()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


def main():
    if not WEB_DIR.exists():
        raise RuntimeError("Run flutter build web first.")
    OUT_DIR.mkdir(exist_ok=True)
    for old in OUT_DIR.glob("*.png"):
        old.unlink()

    auth = login()
    book_id, theme_book_id, series_id = real_ids(auth["token"])
    server = ThreadingHTTPServer(("127.0.0.1", 0), FlutterStaticHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    flutter_origin = f"http://127.0.0.1:{server.server_port}"
    browser = edge_path()

    try:
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/",
            OUT_DIR / "web_home.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=home",
            OUT_DIR / "flutter_home.png",
            flutter_storage_script(auth),
        )
        filter_button = (VIEWPORT_WIDTH - 56, 64)
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/bookshelf",
            OUT_DIR / "web_bookshelf_filter.png",
            web_storage_script(auth),
            clicks=[filter_button],
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=bookshelf",
            OUT_DIR / "flutter_bookshelf_filter.png",
            flutter_storage_script(auth),
            clicks=[filter_button],
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/statistics",
            OUT_DIR / "web_statistics_scrolled.png",
            web_storage_script(auth),
            wheel_steps=2,
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/book/{book_id}",
            OUT_DIR / "web_book_detail.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?book={book_id}",
            OUT_DIR / "flutter_book_detail.png",
            flutter_storage_script(auth),
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/book/{theme_book_id}",
            OUT_DIR / "web_book_detail_theme.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?book={theme_book_id}",
            OUT_DIR / "flutter_book_detail_theme.png",
            flutter_storage_script(auth),
        )
        if series_id:
            capture(
                browser,
                WEB_FRONTEND,
                f"{WEB_FRONTEND}/series/{series_id}",
                OUT_DIR / "web_series_detail.png",
                web_storage_script(auth),
            )
            capture(
                browser,
                flutter_origin,
                f"{flutter_origin}/?series={series_id}",
                OUT_DIR / "flutter_series_detail.png",
                flutter_storage_script(auth),
            )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/admin/logs",
            OUT_DIR / "web_logs.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=logs",
            OUT_DIR / "flutter_logs.png",
            flutter_storage_script(auth),
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/notifications",
            OUT_DIR / "web_notifications.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=notifications",
            OUT_DIR / "flutter_notifications.png",
            flutter_storage_script(auth),
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/admin/plugins",
            OUT_DIR / "web_plugins.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=plugins",
            OUT_DIR / "flutter_plugins.png",
            flutter_storage_script(auth),
        )
        capture(
            browser,
            WEB_FRONTEND,
            f"{WEB_FRONTEND}/admin/users",
            OUT_DIR / "web_users.png",
            web_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=users",
            OUT_DIR / "flutter_users.png",
            flutter_storage_script(auth),
        )
        capture(
            browser,
            flutter_origin,
            f"{flutter_origin}/?page=statistics",
            OUT_DIR / "flutter_statistics_scrolled.png",
            flutter_storage_script(auth),
            wheel_steps=2,
        )
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
