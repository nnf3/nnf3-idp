# ドキュメント

このリポジトリが実装している認証・認可の説明です。起動手順は [README.md](../README.md) を見てください。

## スコープ

実装していること:

- メール + パスワードでの登録 / ログイン
- メール確認とアカウントリカバリ（コード）
- 自社アプリ向け OAuth 2.0 Authorization Code + OpenID Connect

意図的に外していること:

- Google など外部 IdP によるソーシャルログイン
- Client Credentials（マシン間）
- JWT アクセストークン
- Keto / Oathkeeper

## 用語

| 用語 | このリポジトリでの意味 |
|---|---|
| Resource Owner | 登録したユーザー |
| Client | 自社アプリ。現在は `nnf3-web` |
| Authorization Server | Hydra。code / token を発行する。ユーザーは持たない |
| Identity Provider | Kratos。本人確認と identity を持つ |
| Login / Consent UI | `oryd/kratos-selfservice-ui-node` |
| Access token | Hydra が発行する opaque トークン |
| ID Token | OIDC の JWT。アプリがユーザーを識別する |

## 目次

1. [アーキテクチャ](architecture.md) — コンポーネントと URL
2. [認証・認可フロー](flows.md) — シーケンス
