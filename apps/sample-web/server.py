#!/usr/bin/env python3
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen

HYDRA_TOKEN_URL = os.environ.get("HYDRA_TOKEN_URL", "http://hydra:4444/oauth2/token")
CLIENT_ID = os.environ.get("FIRST_PARTY_CLIENT_ID", "nnf3-web")
REDIRECT_URI = os.environ.get(
    "FIRST_PARTY_REDIRECT_URI", "http://127.0.0.1:3000/callback"
)
LISTEN_PORT = int(os.environ.get("PORT", "3000"))


def exchange_code(code: str) -> tuple[dict | None, str | None]:
    body = urlencode(
        {
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": REDIRECT_URI,
            "client_id": CLIENT_ID,
        }
    ).encode()
    request = Request(
        HYDRA_TOKEN_URL,
        data=body,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    try:
        with urlopen(request, timeout=10) as response:
            return json.loads(response.read().decode()), None
    except HTTPError as exc:
        detail = exc.read().decode()
        return None, f"HTTP {exc.code}: {detail}"
    except URLError as exc:
        return None, str(exc.reason)


def page(title: str, body: str) -> bytes:
    return f"""<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <title>{title}</title>
  <style>
    body {{ font-family: sans-serif; margin: 2rem auto; max-width: 52rem; }}
    pre {{ background: #f4f4f4; padding: 1rem; overflow: auto; white-space: pre-wrap; }}
    .ok {{ color: #0a7; }}
    .err {{ color: #c00; }}
  </style>
</head>
<body>
{body}
</body>
</html>""".encode()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        return

    def _send(self, status: int, content: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self._send(
                200,
                page(
                    "nnf3-web",
                    """<h1>nnf3-web（サンプル）</h1>
<p>自社アプリの代わりに、Hydra からの callback を受け取るだけのページです。</p>
<p><a href="http://127.0.0.1:4444/oauth2/auth?client_id=nnf3-web&amp;redirect_uri=http://127.0.0.1:3000/callback&amp;response_type=code&amp;scope=openid%20offline%20email%20profile&amp;state=localdev">ログインを開始</a></p>""",
                ),
            )
            return

        if parsed.path != "/callback":
            self._send(404, page("Not found", "<p>Not found</p>"))
            return

        query = parse_qs(parsed.query)
        code = query.get("code", [""])[0]
        state = query.get("state", [""])[0]
        error = query.get("error", [""])[0]

        if error:
            desc = query.get("error_description", [""])[0]
            self._send(
                400,
                page(
                    "認可エラー",
                    f'<h1 class="err">認可エラー</h1><pre>{error}\n{desc}</pre>',
                ),
            )
            return

        if not code:
            self._send(
                400,
                page("callback", "<h1 class='err'>code がありません</h1>"),
            )
            return

        tokens, token_error = exchange_code(code)
        if tokens:
            pretty = json.dumps(tokens, indent=2, ensure_ascii=False)
            self._send(
                200,
                page(
                    "ログイン成功",
                    f"""<h1 class="ok">IdP フロー成功</h1>
<p>state: <code>{state}</code></p>
<p>authorization code をトークンに交換しました。</p>
<pre>{pretty}</pre>""",
                ),
            )
            return

        self._send(
            200,
            page(
                "code は届きました",
                f"""<h1>callback を受信しました</h1>
<p>IdP からのリダイレクトは成功しています。code の交換に失敗しました（期限切れや再利用のことがあります）。</p>
<p>state: <code>{state}</code></p>
<pre>{token_error}</pre>
<p><a href="/">認可をやり直す</a></p>""",
            ),
        )


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", LISTEN_PORT), Handler).serve_forever()
