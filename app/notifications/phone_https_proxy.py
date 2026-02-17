#!/usr/bin/env python3
"""
Serve built Flutter web assets and proxy /api/* to local backend.

This gives a single origin for phone usage:
- Web app: https://<public-url>/
- Backend API: https://<public-url>/api/*
"""

from __future__ import annotations

import argparse
import http.client
import posixpath
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


def _parse_backend(url: str) -> tuple[str, str, int]:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("Backend URL must start with http:// or https://")
    host = parsed.hostname or "127.0.0.1"
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    return parsed.scheme, host, port


class ProxyHandler(BaseHTTPRequestHandler):
    server_version = "PolarisPhoneProxy/1.0"

    def _is_api(self) -> bool:
        return self.path.startswith("/api/")

    def _proxy_api(self) -> None:
        backend_scheme = self.server.backend_scheme
        backend_host = self.server.backend_host
        backend_port = self.server.backend_port

        parsed = urllib.parse.urlsplit(self.path)
        backend_path = parsed.path[len("/api") :]
        if not backend_path:
            backend_path = "/"
        if parsed.query:
            backend_path = f"{backend_path}?{parsed.query}"

        content_length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(content_length) if content_length else None

        if backend_scheme == "https":
            conn = http.client.HTTPSConnection(backend_host, backend_port, timeout=30)
        else:
            conn = http.client.HTTPConnection(backend_host, backend_port, timeout=30)

        fwd_headers = {
            k: v
            for k, v in self.headers.items()
            if k.lower() not in {"host", "connection", "accept-encoding"}
        }
        fwd_headers["Host"] = f"{backend_host}:{backend_port}"

        conn.request(self.command, backend_path, body=body, headers=fwd_headers)
        resp = conn.getresponse()
        resp_body = resp.read()

        self.send_response(resp.status, resp.reason)
        for k, v in resp.getheaders():
            kl = k.lower()
            if kl in {"connection", "transfer-encoding", "content-encoding"}:
                continue
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.end_headers()
        self.wfile.write(resp_body)

    def _safe_web_path(self, url_path: str) -> Path:
        clean = posixpath.normpath(urllib.parse.unquote(url_path)).lstrip("/")
        candidate = (self.server.web_root / clean).resolve()
        if self.server.web_root not in candidate.parents and candidate != self.server.web_root:
            return self.server.web_root / "index.html"
        return candidate

    def _serve_web(self) -> None:
        parsed = urllib.parse.urlsplit(self.path)
        target = self._safe_web_path(parsed.path)

        if target.is_dir():
            target = target / "index.html"
        if not target.exists() or not target.is_file():
            # SPA fallback
            target = self.server.web_root / "index.html"

        content = target.read_bytes()
        content_type = self._guess_content_type(target.name)
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    @staticmethod
    def _guess_content_type(filename: str) -> str:
        name = filename.lower()
        if name.endswith(".html"):
            return "text/html; charset=utf-8"
        if name.endswith(".js"):
            return "application/javascript; charset=utf-8"
        if name.endswith(".css"):
            return "text/css; charset=utf-8"
        if name.endswith(".json"):
            return "application/json; charset=utf-8"
        if name.endswith(".png"):
            return "image/png"
        if name.endswith(".jpg") or name.endswith(".jpeg"):
            return "image/jpeg"
        if name.endswith(".svg"):
            return "image/svg+xml"
        if name.endswith(".wasm"):
            return "application/wasm"
        if name.endswith(".ico"):
            return "image/x-icon"
        return "application/octet-stream"

    def do_GET(self) -> None:  # noqa: N802
        if self._is_api():
            self._proxy_api()
        else:
            self._serve_web()

    def do_POST(self) -> None:  # noqa: N802
        if self._is_api():
            self._proxy_api()
        else:
            self.send_error(405, "Method not allowed")

    def do_PUT(self) -> None:  # noqa: N802
        if self._is_api():
            self._proxy_api()
        else:
            self.send_error(405, "Method not allowed")

    def do_PATCH(self) -> None:  # noqa: N802
        if self._is_api():
            self._proxy_api()
        else:
            self.send_error(405, "Method not allowed")

    def do_DELETE(self) -> None:  # noqa: N802
        if self._is_api():
            self._proxy_api()
        else:
            self.send_error(405, "Method not allowed")

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        # Keep output concise.
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-root", required=True, help="Path to Flutter web build output")
    parser.add_argument("--backend", default="http://127.0.0.1:8000", help="Backend base URL")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    web_root = Path(args.web_root).resolve()
    if not web_root.exists():
        raise SystemExit(f"Web root not found: {web_root}")

    backend_scheme, backend_host, backend_port = _parse_backend(args.backend)

    httpd = ThreadingHTTPServer((args.host, args.port), ProxyHandler)
    httpd.web_root = web_root
    httpd.backend_scheme = backend_scheme
    httpd.backend_host = backend_host
    httpd.backend_port = backend_port

    print(f"Phone proxy listening on http://{args.host}:{args.port}")
    print(f"Serving web from: {web_root}")
    print(f"Proxying /api -> {backend_scheme}://{backend_host}:{backend_port}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
