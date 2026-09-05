# nnf3-idp

Ory Kratos（ユーザー管理）と Ory Hydra（OAuth 2.0 / OIDC）、PostgreSQL によるセルフホスト IdP です。

認証・認可フローの説明は [docs/](docs/README.md) を見てください。GCP + Neon への載せ方は [docs/gcp.md](docs/gcp.md) です。

## ディレクトリ

```
├── compose.yaml                 # ローカルスタック
├── config/                      # Kratos / Hydra / Postgres（後で Terraform からも利用）
├── docs/                        # 認証・認可の説明
├── scripts/                     # ローカル / GCP 用ヘルパー
├── deploy/                      # Cloud Run 用イメージ
├── apps/sample-web              # ローカル用 callback（:3000）
└── infra/terraform/             # GCP + Neon（modules / envs/dev / envs/prd）
```

## ローカル URL

ホスト名は常に `127.0.0.1` を使ってください（`localhost` と混ぜない）。

| サービス | URL |
|---|---|
| Hydra public（issuer、`/oauth2/*`、discovery） | http://127.0.0.1:4444 |
| Hydra admin（ローカル専用） | http://127.0.0.1:4445 |
| Kratos public | http://127.0.0.1:4433 |
| Kratos admin（ローカル専用） | http://127.0.0.1:4434 |
| ログイン / 同意 / 設定 UI | http://127.0.0.1:4455 |
| Mailslurper（確認メール） | http://127.0.0.1:4436 |
| sample-web（自社アプリの代わり） | http://127.0.0.1:3000 |

Admin ポートはローカルデバッグ用に公開しています。GCP では公開しないでください。

## 起動

```bash
docker compose up -d
docker compose ps
```

設定を上書きする場合は `.env.example` を `.env` にコピーします。

Postgres の初期化は空の volume のときだけ走ります。`config/postgres/init.sql` を変えたあとは `docker compose down -v` でリセットしてください。

## ヘルスチェック

```bash
curl -s http://127.0.0.1:4444/health/ready
curl -s http://127.0.0.1:4433/health/ready
curl -s http://127.0.0.1:4444/.well-known/openid-configuration
```

## 自社向け OAuth2 クライアント

```bash
./scripts/create-first-party-client.sh
```

公開クライアント `nnf3-web` を作ります（PKCE、リダイレクト `http://127.0.0.1:3000/callback`、同意画面なし）。

ブラウザで認可リクエストを開始するには、次の URL を開きます。

```
http://127.0.0.1:4444/oauth2/auth?client_id=nnf3-web&redirect_uri=http://127.0.0.1:3000/callback&response_type=code&scope=openid%20offline%20email%20profile&state=localdev
```

UI で登録またはログインしてください。確認メールは Mailslurper に届きます。自社クライアントは同意画面を出さず、`http://127.0.0.1:3000/callback` に戻ります。sample-web が code をトークンに交換して表示します。authorization code は一度しか使えないので、接続拒否のあとに同じ URL を開き直しても交換に失敗します。その場合は認可 URL からやり直してください。

## 補足

- ホスト向け URL（`issuer`、ログイン / 同意、`KRATOS_BROWSER_URL`）は `127.0.0.1` を使います。
- コンテナ間 URL（`oauth2_provider`、Admin API、`KRATOS_PUBLIC_URL`）は Compose のサービス名を使います。
- アクセストークンは opaque です。GCP でサービス間検証するときは、後から JWT に切り替えられます。
- `--dev` はローカルの HTTP cookie 用です。GCP では外しています。Cloud Run が HTTPS を終端します。
- `identity.schema.json: no such file or directory` が出たら、Docker のバインドマウントが空になっています。`docker compose up -d --force-recreate` で直ります。
- GCP へ載せる手順は [docs/gcp.md](docs/gcp.md) です。
