from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import mimetypes
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import threading
import urllib.parse
import wave
import zlib

import websocket


ROOT = Path(__file__).resolve().parents[1]
WEB_DIR = ROOT / "build" / "web"
OUT_DIR = ROOT / "preview_screenshots"


USER = {"id": "u1", "username": "admin", "role": "admin"}


def settings():
    return {
        "user_id": "u1",
        "playback_speed": 1.0,
        "theme": "auto",
        "auto_play": True,
        "auto_preload": True,
        "auto_cache": False,
        "widget_css": ".widget-mode { background: transparent !important; }",
        "sleep_timer_default": 0,
        "settings_json": {
            "bookshelf_sort_by": "created_at",
            "bookshelf_icon_size": "medium",
            "bookshelf_cover_shape": "rect",
            "widgetCss": ".widget-mode { background: transparent !important; }",
        },
    }


def books(host):
    base = f"http://{host}"
    rows = [
        ("b1", "\u4e09\u4f53\uff1a\u5730\u7403\u5f80\u4e8b", "\u5218\u6148\u6b23", "\u738b\u660e\u519b", "\u79d1\u5e7b,\u7ecf\u5178", 2026),
        ("b2", "\u660e\u671d\u90a3\u4e9b\u4e8b\u513f", "\u5f53\u5e74\u660e\u6708", "\u5f20\u9707", "\u5386\u53f2", 2025),
        ("b3", "\u957f\u591c\u96be\u660e", "\u7d2b\u91d1\u9648", "\u591a\u4eba\u6709\u58f0\u5267", "\u60ac\u7591", 2024),
        ("b4", "\u4e00\u53e5\u9876\u4e00\u4e07\u53e5", "\u5218\u9707\u4e91", "\u674e\u91ce\u58a8", "\u6587\u5b66", 2023),
        ("b5", "\u592a\u767d\u91d1\u661f\u6709\u70b9\u70e6", "\u9a6c\u4f2f\u5eb8", "\u59dc\u5e7f\u6d9b", "\u5e7b\u60f3", 2022),
        ("b6", "\u7f6e\u8eab\u4e8b\u5185", "\u5170\u5c0f\u6b22", "\u738b\u52c7", "\u7ecf\u6d4e", 2021),
        ("b7", "\u5e73\u51e1\u7684\u4e16\u754c", "\u8def\u9065", "\u674e\u91ce\u58a8", "\u6587\u5b66", 2020),
        ("b8", "\u94f6\u6cb3\u5e1d\u56fd\uff1a\u57fa\u5730", "\u827e\u8428\u514b\u00b7\u963f\u897f\u83ab\u592b", "\u53f6\u6e05", "\u79d1\u5e7b", 2019),
    ]
    description = (
        "\u8fd9\u662f\u4e00\u6bb5\u7528\u4e8e\u9884\u89c8 UI "
        "\u7684\u6709\u58f0\u4e66\u7b80\u4ecb\uff0c\u5c55\u793a"
        "\u6392\u7248\u3001\u6309\u94ae\u548c\u7ae0\u8282\u5217\u8868"
        "\u7684\u5b9e\u9645\u5bc6\u5ea6\u3002"
    )
    return [
        {
            "id": book_id,
            "library_id": "l1",
            "title": title,
            "author": author,
            "narrator": narrator,
            "description": description,
            "cover_url": f"{base}/preview_cover/{book_id}.png",
            "theme_color": "#0ea5e9",
            "duration": 36000 + index * 1200,
            "path": f"/books/{book_id}",
            "hash": f"hash-{book_id}",
            "created_at": f"2026-06-{10 - index:02d}T00:00:00Z",
            "is_favorite": index in {0, 2, 4},
            "library_type": "local",
            "skip_intro": 0,
            "skip_outro": 0,
            "tags": tags,
            "genre": tags,
            "year": year,
        }
        for index, (book_id, title, author, narrator, tags, year) in enumerate(rows)
    ]


def libraries():
    return [
        {
            "id": "l1",
            "name": "\u4e3b\u4e66\u5e93",
            "library_type": "local",
            "root_path": "/audiobooks",
            "created_at": "2026-01-01T00:00:00Z",
        },
        {
            "id": "l2",
            "name": "WebDAV \u8fdc\u7a0b\u5e93",
            "library_type": "webdav",
            "root_path": "/",
            "url": "https://dav.example.com",
            "created_at": "2026-01-02T00:00:00Z",
        },
    ]


def chapters():
    result = []
    for index in range(1, 19):
        title = (
            f"\u7b2c {index} \u7ae0 "
            + ("\u7ea2\u5cb8" if index == 12 else "\u5b87\u5b99\u95ea\u70c1")
        )
        result.append(
            {
                "id": f"c{index}",
                "book_id": "b1",
                "title": title,
                "path": f"/audio/c{index}.mp3",
                "duration": 2400 + index * 25,
                "chapter_index": index,
                "is_extra": 0,
                "progress_position": 1860.0 if index == 12 else None,
                "progress_updated_at": "2026-06-10T08:00:00Z"
                if index == 12
                else None,
            }
        )
    return result


def cache_items(host):
    all_books = books(host)
    rows = [
        (all_books[0], "c12", "\u7b2c 12 \u7ae0 \u7ea2\u5cb8", 42_467_328, "2026-06-10T08:20:00Z"),
        (all_books[0], "c13", "\u7b2c 13 \u7ae0 \u4e09\u4f53\u6e38\u620f", 39_812_096, "2026-06-10T08:32:00Z"),
        (all_books[0], "c14", "\u7b2c 14 \u7ae0 \u5b87\u5b99\u95ea\u70c1", 45_920_768, "2026-06-10T09:05:00Z"),
        (all_books[1], "m5", "\u7b2c 5 \u7ae0 \u6731\u5143\u748b\u7684\u5f00\u5c40", 31_457_280, "2026-06-09T22:14:00Z"),
        (all_books[1], "m6", "\u7b2c 6 \u7ae0 \u53cd\u51fb", 28_110_848, "2026-06-09T22:45:00Z"),
    ]
    caches = []
    for book, chapter_id, chapter_title, size, created_at in rows:
        caches.append(
            {
                "chapter_id": chapter_id,
                "book_id": book["id"],
                "book_title": book["title"],
                "chapter_title": chapter_title,
                "file_size": size,
                "created_at": created_at,
                "cover_url": book["cover_url"],
            }
        )
    return {
        "caches": caches,
        "total": len(caches),
        "totalSize": sum(item["file_size"] for item in caches),
    }


def playlists(host):
    all_books = books(host)
    series_rows = series(host)
    return [
        {
            "id": "p1",
            "user_id": "u1",
            "title": "\u901a\u52e4\u8def\u4e0a",
            "description": "\u8282\u594f\u7a33\u4e00\u70b9\uff0c\u9002\u5408\u65e5\u5e38\u8def\u4e0a\u542c\u3002",
            "accent": "#0ea5e9",
            "created_at": "2026-06-08T08:00:00Z",
            "updated_at": "2026-06-11T10:00:00Z",
            "book_ids": ["b1", "b3"],
            "books": [all_books[0], all_books[2]],
            "items": [
                {
                    "item_type": "book",
                    "item_id": "b1",
                    "order": 1,
                    "book": all_books[0],
                    "series": None,
                },
                {
                    "item_type": "series",
                    "item_id": "s1",
                    "order": 2,
                    "book": None,
                    "series": series_rows[0],
                },
            ],
        },
        {
            "id": "p2",
            "user_id": "u1",
            "title": "\u7761\u524d\u653e\u677e",
            "description": "\u7761\u524d\u6162\u6162\u542c\u7684\u4e66\u5355\u3002",
            "accent": "#8b5cf6",
            "created_at": "2026-06-09T08:00:00Z",
            "updated_at": "2026-06-10T10:00:00Z",
            "book_ids": ["b4", "b7"],
            "books": [all_books[3], all_books[6]],
            "items": [
                {
                    "item_type": "book",
                    "item_id": "b4",
                    "order": 1,
                    "book": all_books[3],
                    "series": None,
                }
            ],
        },
    ]


def series(host):
    all_books = books(host)
    return [
        {
            "id": "s1",
            "library_id": "l1",
            "title": "\u5218\u6148\u6b23\u79d1\u5e7b\u5b87\u5b99",
            "author": "\u5218\u6148\u6b23",
            "description": "\u786c\u79d1\u5e7b\u7ecf\u5178\u4f5c\u54c1\u5408\u96c6\u3002",
            "books": all_books[:2],
        }
    ]


def notification_events():
    return [
        {"id": "user.login", "label": "\u7528\u6237\u767b\u5f55", "description": "\u7528\u6237\u6210\u529f\u767b\u5f55\u7cfb\u7edf"},
        {"id": "playback.play", "label": "\u64ad\u653e\u5f00\u59cb", "description": "\u9996\u6b21\u5199\u5165\u8fdb\u5ea6\u65f6\u89e6\u53d1"},
        {"id": "library.scan_completed", "label": "\u626b\u63cf\u5b8c\u6210", "description": "\u5a92\u4f53\u5e93\u626b\u63cf\u5b8c\u6210"},
    ]


def notification_webhooks():
    return [
        {
            "id": "n1",
            "name": "\u8fd0\u7ef4\u901a\u77e5",
            "url": "https://example.com/webhook",
            "enabled": True,
            "events": ["user.login", "library.scan_completed"],
            "secret": None,
            "created_at": "2026-06-11T08:00:00Z",
            "updated_at": "2026-06-11T09:00:00Z",
        }
    ]


def system_logs():
    return {
        "logs": [
            {
                "timestamp": "2026-06-11T18:22:14Z",
                "level": "INFO",
                "module": "audit::login",
                "message": "admin \u767b\u5f55\u6210\u529f",
                "fields": {
                    "username": "admin",
                    "server": "preview",
                    "client": "flutter-web",
                },
            },
            {
                "timestamp": "2026-06-11T18:23:02Z",
                "level": "INFO",
                "module": "audit::playback",
                "message": "\u5f00\u59cb\u64ad\u653e\u300a\u4e09\u4f53\uff1a\u5730\u7403\u5f80\u4e8b\u300b\u7b2c 12 \u7ae0",
                "fields": {
                    "bookId": "b1",
                    "chapterId": "c12",
                    "position": 1860,
                },
            },
            {
                "timestamp": "2026-06-11T18:24:10Z",
                "level": "INFO",
                "module": "audit::scan",
                "message": "\u5a92\u4f53\u5e93\u626b\u63cf\u5b8c\u6210",
                "task_id": "task-scan-1",
                "task_status": "completed",
                "task_type": "library_scan",
                "fields": {
                    "library": "\u4e3b\u4e66\u5e93",
                    "added": 8,
                    "updated": 3,
                },
            },
            {
                "timestamp": "2026-06-11T18:25:18Z",
                "level": "WARN",
                "module": "audit::metadata",
                "message": "\u5206\u522b\u4fdd\u7559\u4eba\u5de5\u7f16\u8f91\u8fc7\u7684\u5143\u6570\u636e\u5b57\u6bb5",
                "fields": {
                    "bookId": "b4",
                    "source": "douban",
                },
            },
        ],
        "total": 4,
        "page": 1,
        "pageSize": 100,
    }


def admin_statistics():
    return {
        "overview": {
            "total_books": 128,
            "total_chapters": 4820,
            "total_duration": 682400,
            "total_libraries": 2,
            "total_users": 4,
            "total_listen_seconds": 92340,
        },
        "library_breakdown": [
            {"id": "l1", "name": "\u4e3b\u4e66\u5e93", "library_type": "local", "total_books": 92},
            {"id": "l2", "name": "WebDAV \u8fdc\u7a0b\u5e93", "library_type": "webdav", "total_books": 36},
        ],
        "user_activity": [],
        "recent_activity": [],
        "top_books": [
            {"id": "b1", "title": "\u4e09\u4f53\uff1a\u5730\u7403\u5f80\u4e8b", "listeners": 8, "listen_seconds": 32100},
            {"id": "b2", "title": "\u660e\u671d\u90a3\u4e9b\u4e8b\u513f", "listeners": 5, "listen_seconds": 18800},
        ],
        "generated_at": "2026-06-11T12:00:00Z",
    }


def installed_plugins():
    return [
        {
            "id": "douban-scraper@1.0.0",
            "name": "\u8c46\u74e3\u5143\u6570\u636e\u522e\u524a",
            "version": "1.0.0",
            "plugin_type": "scraper",
            "runtime": "javascript",
            "author": "Ting Reader",
            "description": "\u4ece\u8c46\u74e3\u641c\u7d22\u6709\u58f0\u4e66\u5143\u6570\u636e\uff0c\u652f\u6301\u4e66\u540d\u3001\u4f5c\u8005\u3001\u7b80\u4ecb\u548c\u6807\u7b7e\u56de\u586b\u3002",
            "state": "active",
            "permissions": ["network"],
            "config_schema": {"type": "object"},
            "repo": "ting-reader/douban-scraper",
        },
        {
            "id": "metadata-writer@0.8.0",
            "name": "Metadata Writer",
            "version": "0.8.0",
            "plugin_type": "utility",
            "runtime": "wasm",
            "author": "Community",
            "description": "\u6279\u91cf\u751f\u6210 NFO \u548c metadata.json\uff0c\u7528\u4e8e\u4e0e\u5176\u4ed6\u6709\u58f0\u4e66\u670d\u52a1\u5171\u7528\u5143\u6570\u636e\u3002",
            "state": "active",
            "permissions": ["filesystem"],
        },
    ]


def store_plugins():
    return [
        {
            "id": "douban-scraper",
            "name": "\u8c46\u74e3\u5143\u6570\u636e\u522e\u524a",
            "version": "1.1.0",
            "pluginType": "scraper",
            "runtime": "javascript",
            "author": "Ting Reader",
            "description": "\u4ece\u8c46\u74e3\u641c\u7d22\u6709\u58f0\u4e66\u5143\u6570\u636e\u3002",
            "longDescription": "\u652f\u6301\u6839\u636e\u4e66\u540d\u3001\u4f5c\u8005\u548c ISBN \u641c\u7d22\uff0c\u53ef\u81ea\u52a8\u56de\u586b\u5c01\u9762\u3001\u4f5c\u8005\u3001\u6f14\u64ad\u3001\u7b80\u4ecb\u548c\u6807\u7b7e\u5b57\u6bb5\u3002",
            "license": "MIT",
            "repo": "ting-reader/douban-scraper",
            "permissions": ["network"],
            "supportedExtensions": [".mp3", ".m4b", ".flac"],
            "configSchema": {"type": "object"},
        },
        {
            "id": "m4b-format",
            "name": "M4B Chapter Parser",
            "version": "0.6.2",
            "pluginType": "format",
            "runtime": "wasm",
            "author": "Community",
            "description": "\u89e3\u6790 M4B \u5185\u7f6e\u7ae0\u8282\u548c\u5c01\u9762\uff0c\u4f18\u5316\u5355\u6587\u4ef6\u6709\u58f0\u4e66\u5bfc\u5165\u6d41\u7a0b\u3002",
            "license": "Apache-2.0",
            "supportedExtensions": [".m4b"],
        },
        {
            "id": "metadata-writer",
            "name": "Metadata Writer",
            "version": "0.8.0",
            "pluginType": "utility",
            "runtime": "wasm",
            "author": "Community",
            "description": "\u6279\u91cf\u751f\u6210 NFO \u548c metadata.json\u3002",
            "dependencies": ["douban-scraper"],
            "permissions": ["filesystem"],
        },
    ]


def scraper_sources():
    return {
        "sources": [
            {
                "id": "douban-scraper",
                "name": "\u8c46\u74e3\u5143\u6570\u636e",
                "description": "\u4ece\u8c46\u74e3\u641c\u7d22\u4e66\u7c4d\u5143\u6570\u636e",
                "version": "1.1.0",
                "enabled": True,
                "auto_scrape": True,
            },
            {
                "id": "xiimalaya-scraper-js",
                "name": "\u559c\u9a6c\u62c9\u96c5\u522e\u524a",
                "description": "\u5339\u914d\u6709\u58f0\u4e66\u4e13\u8f91",
                "version": "0.9.0",
                "enabled": True,
                "auto_scrape": True,
            },
            {
                "id": "manual-importer",
                "name": "\u624b\u52a8\u5bfc\u5165\u5de5\u5177",
                "version": "0.3.0",
                "enabled": True,
                "auto_scrape": False,
            },
        ]
    }


def png(width, height, primary):
    r, g, b = primary
    rows = []
    for y in range(height):
        row = bytearray()
        for x in range(width):
            t = (x / max(width - 1, 1) + y / max(height - 1, 1)) / 2
            row.extend(
                [
                    int(r * (1 - t) + 248 * t),
                    int(g * (1 - t) + 250 * t),
                    int(b * (1 - t) + 252 * t),
                ]
            )
        rows.append(b"\x00" + bytes(row))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    raw = b"".join(rows)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def silence_wav(duration_seconds=0.25, sample_rate=8000):
    import io

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(b"\x00\x00" * int(sample_rate * duration_seconds))
    return buffer.getvalue()


class PreviewHandler(BaseHTTPRequestHandler):
    server_version = "TingReaderPreview/1.0"

    def log_message(self, _format, *args):
        return

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)
        host = self.headers.get("Host", "127.0.0.1")

        if path == "/seed":
            target = query.get("target", ["/"])[0]
            return self.html(seed_page(target, authenticated=True))
        if path == "/clear":
            target = query.get("target", ["/"])[0]
            return self.html(seed_page(target, authenticated=False))
        if path.startswith("/preview_cover/"):
            color = cover_color(Path(path).stem)
            return self.bytes(png(520, 720, color), "image/png")

        if path == "/api/health":
            return self.json({"ok": True, "version": "0.9.8"})
        if path == "/api/me":
            return self.json(USER)
        if path == "/api/settings":
            return self.json(settings())
        if path == "/api/cache":
            return self.json(cache_items(host))
        if path == "/api/v1/plugins":
            return self.json(installed_plugins())
        if path == "/api/v1/store/plugins":
            return self.json(store_plugins())
        if path in {"/api/scraper/sources", "/api/v1/scraper/sources"}:
            return self.json(scraper_sources())
        if path.startswith("/api/v1/plugins/") and path.endswith("/config"):
            return self.json({"plugin_id": path.split("/")[4], "config": {"enabled": True}})
        if path == "/api/stats":
            return self.json(
                {
                    "total_books": 128,
                    "total_chapters": 4820,
                    "total_duration": 682400,
                    "last_scan_time": "2026-06-10T08:30:00Z",
                }
            )
        if path == "/api/progress/recent":
            all_books = books(host)
            return self.json(
                [
                    {
                        "book_id": "b1",
                        "chapter_id": "c12",
                        "position": 1860,
                        "duration": 3600,
                        "book_title": all_books[0]["title"],
                        "chapter_title": "\u7b2c 12 \u7ae0 \u7ea2\u5cb8",
                        "cover_url": all_books[0]["cover_url"],
                        "library_id": "l1",
                        "chapter_duration": 3600,
                    },
                    {
                        "book_id": "b2",
                        "chapter_id": "c5",
                        "position": 1200,
                        "duration": 2800,
                        "book_title": all_books[1]["title"],
                        "chapter_title": "\u6731\u5143\u748b\u7684\u5f00\u5c40",
                        "cover_url": all_books[1]["cover_url"],
                        "library_id": "l1",
                        "chapter_duration": 2800,
                    },
                ]
            )
        if path == "/api/playlists":
            return self.json(playlists(host))
        if path == "/api/playlists/p1":
            return self.json(playlists(host)[0])
        if path == "/api/system/notifications":
            return self.json(notification_webhooks())
        if path == "/api/system/notifications/events":
            return self.json(notification_events())
        if path in {"/api/system/logs", "/api/v1/system/logs"}:
            return self.json(system_logs())
        if path in {"/api/system/logs/export", "/api/v1/system/logs/export"}:
            return self.bytes(
                "\n".join(
                    f"{item['timestamp']} {item['level']} {item['module']} {item['message']}"
                    for item in system_logs()["logs"]
                ).encode("utf-8"),
                "text/plain; charset=utf-8",
            )
        if path == "/api/system/statistics":
            return self.json(admin_statistics())
        if path == "/api/libraries":
            return self.json(libraries())
        if path == "/api/storage/folders":
            sub_path = query.get("subPath", [""])[0]
            if sub_path:
                return self.json(
                    [
                        {"name": "\u79d1\u5e7b", "path": f"{sub_path}/\u79d1\u5e7b", "isDirectory": True},
                        {"name": "\u5386\u53f2", "path": f"{sub_path}/\u5386\u53f2", "isDirectory": True},
                    ]
                )
            return self.json(
                [
                    {"name": "audiobooks", "path": "audiobooks", "isDirectory": True},
                    {"name": "podcasts", "path": "podcasts", "isDirectory": True},
                    {"name": "webdav-cache", "path": "webdav-cache", "isDirectory": True},
                ]
            )
        if path == "/api/books":
            data = books(host)
            params = urllib.parse.parse_qs(parsed.query)
            term = params.get("search", [""])[0].lower()
            if term:
                data = [
                    item
                    for item in data
                    if term in item["title"].lower() or term in item["author"].lower()
                ]
            return self.json(data)
        if path == "/api/v1/series":
            return self.json(series(host))
        if path == "/api/favorites":
            all_books = books(host)
            return self.json([all_books[0], all_books[2], all_books[4]])
        if path == "/api/tags":
            return self.json(
                [
                    "\u79d1\u5e7b",
                    "\u5386\u53f2",
                    "\u60ac\u7591",
                    "\u6587\u5b66",
                    "\u7ecf\u6d4e",
                ]
            )
        if path == "/api/books/b1":
            return self.json({**books(host)[0], "is_favorite": True})
        if path == "/api/books/b1/chapters":
            return self.json(chapters())
        if path.startswith("/api/stream/"):
            return self.bytes(silence_wav(), "audio/wav")

        return self.static(path)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/api/auth/login":
            return self.json({"token": "preview-token", "user": USER})
        if parsed.path == "/api/settings":
            return self.json(settings())
        if parsed.path == "/api/libraries/test-connection":
            return self.json({"success": True, "message": "\u8fde\u63a5\u6210\u529f\uff01"})
        if parsed.path in {"/api/v1/store/cache/clear", "/api/v1/store/install"}:
            return self.json({"ok": True})
        if parsed.path.startswith("/api/v1/plugins/") and parsed.path.endswith("/reload"):
            return self.json({"message": "Plugin reloaded successfully"})
        return self.json({"ok": True})

    def do_PATCH(self):
        return self.json({"ok": True})

    def do_PUT(self):
        return self.json({"ok": True})

    def do_DELETE(self):
        return self.json({"ok": True})

    def json(self, data, status=200):
        payload = json.dumps(data).encode("utf-8")
        return self.bytes(payload, "application/json; charset=utf-8", status)

    def html(self, content, status=200):
        return self.bytes(content.encode("utf-8"), "text/html; charset=utf-8", status)

    def bytes(self, data, content_type, status=200):
        try:
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):
            pass

    def static(self, path):
        if not WEB_DIR.exists():
            return self.bytes(b"Run flutter build web first.", "text/plain", 500)

        if path == "/":
            target = WEB_DIR / "index.html"
        else:
            rel = urllib.parse.unquote(path).lstrip("/")
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
        self.bytes(target.read_bytes(), content_type)


def seed_page(target, authenticated):
    auth_script = """
const origin = window.location.origin;
Object.keys(localStorage).forEach((key) => {
  if (key.startsWith('flutter.')) localStorage.removeItem(key);
});
"""
    if authenticated:
        user = json.dumps(USER)
        auth_script += f"""
localStorage.setItem('flutter.server_url', JSON.stringify(origin));
localStorage.setItem('flutter.active_url', JSON.stringify(origin));
localStorage.setItem('flutter.auth_token', JSON.stringify('preview-token'));
localStorage.setItem('flutter.user', JSON.stringify(JSON.stringify({user})));
localStorage.setItem('flutter.redirect_cache', JSON.stringify(JSON.stringify({{[origin]: origin}})));
"""
    auth_script += f"window.location.replace({json.dumps(target)});"
    return f"<!doctype html><meta charset='utf-8'><script>{auth_script}</script>"


def cover_color(book_id):
    palette = {
        "b1": (14, 165, 233),
        "b2": (217, 119, 6),
        "b3": (100, 116, 139),
        "b4": (22, 163, 74),
        "b5": (225, 29, 72),
        "b6": (79, 70, 229),
        "b7": (5, 150, 105),
        "b8": (124, 58, 237),
    }
    return palette.get(book_id, (15, 23, 42))


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


def capture(browser, base_url, name, target):
    output = OUT_DIR / name
    profile = Path(tempfile.mkdtemp(prefix="ting-reader-shot-"))
    url = f"{base_url}{target}"
    args = [
        str(browser),
        "--headless",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-extensions",
        "--hide-scrollbars",
        "--run-all-compositor-stages-before-draw",
        "--force-device-scale-factor=1",
        "--window-size=1440,1000",
        "--virtual-time-budget=12000",
        f"--user-data-dir={profile}",
        f"--screenshot={output}",
        url,
    ]
    subprocess.run(
        args,
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return output


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
            json.dumps(
                {
                    "id": message_id,
                    "method": method,
                    "params": params or {},
                }
            )
        )
        while True:
            payload = json.loads(self._socket.recv())
            if payload.get("id") != message_id:
                continue
            if "error" in payload:
                raise RuntimeError(f"{method}: {payload['error']}")
            return payload.get("result", {})


def capture_interactive(browser, base_url, name, target, interactions):
    output = OUT_DIR / name
    profile = Path(tempfile.mkdtemp(prefix="ting-reader-shot-cdp-"))
    port = 9337
    url = f"{base_url}{target}"
    process = subprocess.Popen(
        [
            str(browser),
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--window-size=1440,1000",
            "--remote-allow-origins=*",
            f"--user-data-dir={profile}",
            f"--remote-debugging-port={port}",
            url,
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    client = None
    try:
        import time
        import urllib.request

        version_url = f"http://127.0.0.1:{port}/json"
        deadline = time.time() + 10
        targets = None
        while time.time() < deadline:
            try:
                with urllib.request.urlopen(version_url, timeout=1) as response:
                    targets = json.loads(response.read().decode("utf-8"))
                break
            except Exception:
                time.sleep(0.2)
        if not targets:
            raise RuntimeError("Unable to connect to headless browser")

        target_info = next(
            (target for target in targets if target.get("type") == "page"),
            targets[0],
        )
        client = CdpClient(target_info["webSocketDebuggerUrl"])
        client.send("Page.enable")
        client.send("Runtime.enable")
        client.send(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": 1440,
                "height": 1000,
                "deviceScaleFactor": 1,
                "mobile": False,
            },
        )
        time.sleep(5)
        for interaction in interactions:
            if interaction[0] == "click":
                _, x, y = interaction
                client.send(
                    "Input.dispatchMouseEvent",
                    {"type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1},
                )
                client.send(
                    "Input.dispatchMouseEvent",
                    {"type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1},
                )
            elif interaction[0] == "wait":
                time.sleep(interaction[1])

        screenshot = client.send("Page.captureScreenshot", {"format": "png", "fromSurface": True})
        output.write_bytes(__import__("base64").b64decode(screenshot["data"]))
        return output
    finally:
        if client is not None:
            client.close()
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


def main():
    OUT_DIR.mkdir(exist_ok=True)
    for old in OUT_DIR.glob("*.png"):
        old.unlink()

    server = ThreadingHTTPServer(("127.0.0.1", 0), PreviewHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_port}"

    browser = edge_path()
    shots = [
        ("01_login.png", "/clear?target=/"),
        ("02_home.png", "/seed?target=/"),
        ("03_bookshelf.png", "/seed?target=/%3Fpage%3Dbookshelf"),
        ("04_favorites.png", "/seed?target=/%3Fpage%3Dfavorites"),
        ("05_book_detail.png", "/seed?target=/%3Fbook%3Db1"),
        ("06_settings.png", "/seed?target=/%3Fpage%3Dsettings"),
        ("07_downloads.png", "/seed?target=/%3Fpage%3Ddownloads"),
        ("08_libraries.png", "/seed?target=/%3Fpage%3Dlibraries"),
        ("09_plugins.png", "/seed?target=/%3Fpage%3Dplugins"),
        ("10_mine.png", "/seed?target=/%3Fpage%3Dmine"),
        ("11_history.png", "/seed?target=/%3Fpage%3Dhistory"),
        ("12_playlists.png", "/seed?target=/%3Fpage%3Dplaylists"),
        ("13_playlist_detail.png", "/seed?target=/%3Fplaylist%3Dp1"),
        ("14_notifications.png", "/seed?target=/%3Fpage%3Dnotifications"),
        ("15_statistics.png", "/seed?target=/%3Fpage%3Dstatistics"),
        ("16_logs.png", "/seed?target=/%3Fpage%3Dlogs"),
    ]
    try:
        for name, target in shots:
            output = capture(browser, base_url, name, target)
            print(output)
        output = capture_interactive(
            browser,
            base_url,
            "17_player_expanded.png",
            "/seed?target=/%3Fbook%3Db1",
            [
                ("wait", 2.0),
                ("click", 850, 253),
                ("wait", 2.0),
                ("click", 720, 930),
                ("wait", 2.0),
            ],
        )
        print(output)
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
