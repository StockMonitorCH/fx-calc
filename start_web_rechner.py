#!/usr/bin/env python3
"""
Startet den Web-Rechner & Währungsrechner im Browser.
"""
import http.server
import threading
import webbrowser
import os
import socket
import time

PORT = 8765
DIR = os.path.dirname(os.path.abspath(__file__))


class _SilentHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def log_message(self, *args):
        pass


def _wait_for_server(port, timeout=5.0):
    """Wartet bis der Server antwortet."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection(('localhost', port), timeout=0.5):
                return True
        except OSError:
            time.sleep(0.1)
    return False


def main():
    # Anderen Port versuchen falls 8765 belegt
    port = PORT
    for p in range(PORT, PORT + 20):
        try:
            test = socket.socket()
            test.bind(('localhost', p))
            test.close()
            port = p
            break
        except OSError:
            continue

    server = http.server.HTTPServer(('localhost', port), _SilentHandler)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()

    # Erst öffnen wenn Server wirklich bereit ist
    if _wait_for_server(port):
        url = f'http://localhost:{port}/currency_converter.html'
        webbrowser.open(url)
        print(f"Rechner läuft unter: {url}")
        print("Enter drücken zum Beenden.")
    else:
        print("Fehler: Server konnte nicht gestartet werden.")
        return

    try:
        input()
    except (KeyboardInterrupt, EOFError):
        pass
    server.shutdown()


if __name__ == '__main__':
    main()
