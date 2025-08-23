#!/usr/bin/env python3
"""
Simple HTTP server for local development
Serves the docs directory with CORS headers
"""

import http.server
import socketserver
import os
from pathlib import Path

class CORSHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

if __name__ == "__main__":
    PORT = 8000
    docs_dir = Path(__file__).parent.parent / "docs"
    
    os.chdir(docs_dir)
    
    with socketserver.TCPServer(("", PORT), CORSHTTPRequestHandler) as httpd:
        print(f"🌐 Serving docs at http://localhost:{PORT}")
        print(f"📂 Directory: {docs_dir}")
        print("Press Ctrl+C to stop")
        httpd.serve_forever()
