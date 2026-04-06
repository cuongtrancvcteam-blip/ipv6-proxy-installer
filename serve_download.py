#!/usr/bin/env python3
from __future__ import annotations

import argparse
import functools
import http.server
import os
import socketserver


class DownloadHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        filename = os.path.basename(self.translate_path(self.path))
        if filename:
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, format: str, *args) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--directory", required=True)
    args = parser.parse_args()

    handler = functools.partial(DownloadHandler, directory=args.directory)
    with socketserver.TCPServer((args.host, args.port), handler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
