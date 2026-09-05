# GCP + Neon への載せ方

検証・低トラフィック向けです。Cloud Run はスケールゼロ、Postgres は Neon（シンガポール）。グローバル LB と Cloud SQL は使いません。

ローカル起動は [README.md](../README.md)、認証の説明は [architecture.md](architecture.md) です。

## 完成形

| 公開 | サービス | 用途 |
|---|---|---|
| 誰でも | `hydra-public` | issuer / `/oauth2/*` |
| 誰でも | `kratos-public` | サーバ間 API（ブラウザ flow は UI 経由） |
| 誰でも | `idp-ui` | ログイン UI と Kratos Public の同一ホスト proxy |
| internal | `hydra-admin` | login accept |
| internal | `kratos-admin` | UI の admin 呼び出し |

Compute は `asia-southeast1`、Neon は `aws-ap-southeast-1`。同じ都市圏に寄せて DB 往復を短くします。

Terraform は [infra/terraform/modules/idp](../infra/terraform/modules/idp) を [envs/dev](../infra/terraform/envs/dev) と [envs/prd](../infra/terraform/envs/prd) から呼びます。リソース名は `kratos-public-dev` のように環境サフィックスが付きます。GCP プロジェクトは分けるのが推奨です。同じプロジェクトでも名前は衝突しませんが、API 有効化と Cloud Build IAM はプロジェクト共通なので、片方を destroy すると他方に影響します。

prd は Cloud Run の `deletion_protection` が有効です。dev は無効です。どちらも当面は `min-instances=0` です。

`run.app` のサービスごとのホスト名では Kratos の CSRF Cookie を UI と共有できません。UI イメージ内の nginx が `/self-service`、`/sessions`、`/schemas` を Kratos Public へ転送し、ブラウザからは UI と同じホストに見せます。localhost 専用の別ポートから Admin へ転送するため、Admin は `ingress=internal` のままです。

アイドル時の目安は環境あたり月 $0〜3 です。初回ログインは Cloud Run 起動と Neon resume で数秒かかることがあります。

## 0. 手元に用意するもの

- `gcloud` と `terraform`（1.3 以降）
- Docker（OAuth クライアント作成時）
- 課金が有効な GCP プロジェクト
- [Neon](https://console.neon.tech) アカウントと API キー（Account settings → API keys）
- 確認メール用 SMTP。Resend の無料枠で足りることが多いです  
  例: `smtps://resend:re_xxxx@smtp.resend.com:465`

## 1. サービスアカウントキーを置く

`gcloud auth login` は使いません。[fitness-app の GCP](https://github.com/nnf3/fitness-app/tree/main/gcp) と同じく、環境ディレクトリの `credentials.json` で認証します。

初回だけ、オーナー権限のあるアカウントでキーを発行します。

```bash
export PROJECT_ID=YOUR_PROJECT_ID
gcloud config set project "${PROJECT_ID}"

gcloud iam service-accounts create idp-terraform \
  --display-name="nnf3-idp Terraform"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:idp-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:idp-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:idp-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.projectIamAdmin"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:idp-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/run.admin"

gcloud iam service-accounts keys create \
  infra/terraform/envs/dev/credentials.json \
  --iam-account="idp-terraform@${PROJECT_ID}.iam.gserviceaccount.com"
```

prd は `envs/prd/credentials.json` に置きます。キーはコミットしないでください。JSON キーは長寿命なので、漏れたらすぐ無効化します。

このあとの `gcloud` / Terraform は、そのファイルを見て動きます。スクリプトは `envs/$ENV/credentials.json` を使います。Terraform は同じファイルと `backend.hcl` の `credentials` を見ます。

キー発行の `gcloud` だけは、最初の一度はユーザーログインが必要です。発行後は不要です。

## 2. Terraform 変数と GCS state を置く

dev から載せます。prd は `envs/prd` で同じ手順です。state は GCS に置きます。dev と prd は同じバケット、`prefix` だけ違います（`envs/dev` / `envs/prd`）。

```bash
export PROJECT_ID=YOUR_PROJECT_ID
export ENV=dev
./scripts/gcp-create-tfstate-bucket.sh

cd infra/terraform/envs/dev
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
```

`terraform.tfvars` の `project_id`、`neon_api_key`、`smtp_connection_uri` を書き換えます。自社アプリの origin がまだなければ `app_origin` は空のままで構いません。

`backend.hcl` の `bucket` を `YOUR_PROJECT_ID-nnf3-idp-tfstate` にします。`terraform.tfvars` と `backend.hcl` はコミットしないでください。

すでにローカル state で `terraform init` 済みなら、次は `-migrate-state` を付けます。

## 3. Artifact Registry まで先に作る

Cloud Run はイメージがないと作成に失敗します。先に API とリポジトリだけ作ります。

```bash
terraform init -backend-config=backend.hcl
terraform apply \
  -target=module.idp.google_project_service.services \
  -target=module.idp.google_artifact_registry_repository.idp \
  -target=module.idp.google_project_iam_member.cloudbuild_ar \
  -target=module.idp.google_project_iam_member.cloudbuild_run \
  -target=module.idp.google_project_iam_member.cloudbuild_secret_accessor \
  -target=module.idp.google_project_iam_member.cloudbuild_builder \
  -target=module.idp.google_service_account.cloudbuild
```

## 4. イメージをビルドする

リポジトリのルートで:

```bash
export PROJECT_ID=YOUR_PROJECT_ID
export ENV=dev
export REGION=asia-southeast1
# 初回だけ Terraform の bootstrap タグと揃える
IMAGE_TAG=v26.2.0-r1 ./scripts/build-gcp-images.sh
```

Kratos / Hydra の設定入りイメージに加え、公式 UI の前に nginx を置いた UI イメージも `idp-dev`（prd なら `idp-prd`）へ push します。nginx は Kratos のブラウザ flow を UI と同じホストにまとめるための薄い proxy です。

初回は Cloud Run がまだないので **push のみ** です（`DEPLOY=auto` がサービス未作成を検知して deploy をスキップします）。

2 回目以降は `./scripts/build-gcp-images.sh` だけで、git の短い SHA をタグにして Cloud Run へ反映します。パイプラインの順序は **migrate（新イメージを直接実行）→ Job/サービス更新 → OAuth クライアント同期** です。migrate はビルド直後のイメージを `docker run` で走らせ、Job 定義の更新はスキーマ適用後にまとめて行います。

手動で migrate だけ再実行する場合は `./scripts/gcp-migrate.sh`（Cloud Run Job 経由）を使えます。

## 5. Job まで apply してマイグレーションする

Ory は `networks` テーブルがないと起動しません。Cloud Run サービスより先にスキーマを作ります。

```bash
cd infra/terraform/envs/dev
terraform apply \
  -target=module.idp.google_cloud_run_v2_job.kratos_migrate \
  -target=module.idp.google_cloud_run_v2_job.hydra_migrate
```

関連する Neon / Secret / IAM も一緒に作られます。そのあとリポジトリルートで:

```bash
export PROJECT_ID=YOUR_PROJECT_ID
export ENV=dev
./scripts/gcp-migrate.sh
```

migrate は Neon の **direct** DSN、ランタイムは pooled（`pgbouncer=true`）です。

## 6. 残りを apply する

```bash
cd infra/terraform/envs/dev
terraform apply
terraform output
```

Cloud Run 5 サービスと週次 janitor ができます。migrate 前にサービスを apply すると、起動プローブが `Unable to locate the table` で失敗します。

`expected_issuer` と `hydra_public_url` が一致していることを確認してください。食い違うと OIDC の issuer が壊れます。

Hydra の `secrets.system` と Kratos の cookie / cipher は Terraform が一度だけ生成します。Secret を作り直すと既存セッションと Hydra の暗号化データが読めなくなります。

## 7. ヘルスチェック

```bash
TF=infra/terraform/envs/dev
terraform -chdir="$TF" output -raw hydra_public_url
terraform -chdir="$TF" output -raw kratos_public_url

curl -sS "$(terraform -chdir="$TF" output -raw hydra_public_url)/health/ready"
curl -sS "$(terraform -chdir="$TF" output -raw kratos_public_url)/health/ready"
curl -sS "$(terraform -chdir="$TF" output -raw hydra_public_url)/.well-known/openid-configuration"
```

アイドル直後は起動に十数秒かかることがあります。

## 8. OAuth クライアント

定義は [config/hydra/clients/dev.yaml](../config/hydra/clients/dev.yaml)（prd は `prd.yaml`）です。`${APP_ORIGIN}` は Terraform の `app_origin`（未設定なら UI URL）に置き換わります。

CI 有効時は main マージ後に自動同期されます。手動なら:

```bash
export PROJECT_ID=YOUR_PROJECT_ID
export ENV=dev
./scripts/gcp-sync-oauth-clients.sh
```

redirect を変えるときは YAML を編集し、`app_origin` を変えた場合は Terraform apply 後に再ビルドまたは sync を実行します。

## 9. ログインを試す

`cd infra/terraform/envs/dev && terraform output authorize_url_example` の URL をブラウザで開きます。UI で登録すると確認メールが SMTP 先に届きます。

authorization code は一度しか使えません。callback 側が落ちたあとに同じ URL を再読み込みしても交換できません。認可からやり直してください。

## 運用

| 作業 | 方法 |
|---|---|
| 設定やイメージ更新 | `ENV=dev ./scripts/build-gcp-images.sh`（migrate → Job/サービス更新 → OAuth 同期） |
| Hydra janitor | 日曜 3:00 JST に Scheduler が `hydra-janitor-dev` を実行。手動は `gcloud run jobs execute hydra-janitor-dev --region asia-southeast1 --wait` |
| OAuth クライアント | `config/hydra/clients/*.yaml` を編集。CI または `ENV=dev ./scripts/gcp-sync-oauth-clients.sh` |
| Admin を直接叩く | 例外時だけ `gcloud run services proxy hydra-admin-dev` |
| 破棄 | 対象 env で `terraform destroy`。その環境の Neon プロジェクトも消えます。prd は `deletion_protection` があるので先に外す |

## 10. CI/CD（GitHub → Cloud Build）

**第 1 世代**の GitHub 連携を使います（Console の「Cloud Build GitHub アプリ」）。**接続名は不要**です。スクリーンショットの `nnf3/nnf3-idp` が連携済みなら、そのまま Trigger を Terraform で作れます。

Trigger はデフォルトで `global` に作ります。`Repository mapping does not exist` になるときは、Console でリポジトリを見たときのリージョン（例: `asia-northeast1`）を `trigger_location` に指定してください。Cloud Run の `asia-southeast1` とは別です。

`terraform.tfvars` に追加:

```hcl
github_deploy = {
  enabled          = true
  owner            = "nnf3"
  repository       = "nnf3-idp"
  branch_pattern   = "^main$"
  trigger_location = "global"
}
```

```bash
cd infra/terraform/envs/dev
terraform apply
```

**dev / prd の分け方**

| 環境 | GCP プロジェクト | トリガー | イメージタグ |
|---|---|---|---|
| dev | `nnf3-idp-dev` など | `main` push | `$SHORT_SHA` |
| prd | 別プロジェクト推奨 | tag `v*.*.*` push | `$TAG_NAME` |

prd の例:

```hcl
github_deploy = {
  enabled                = true
  owner                  = "nnf3"
  repository             = "nnf3-idp"
  tag_pattern            = "^v[0-9]+\\.[0-9]+\\.[0-9]+$"
  image_tag_substitution = "$TAG_NAME"
}
```

リリース: dev で確認後 `git tag v1.0.0 && git push origin v1.0.0` → prd デプロイ。

パスフィルター（デフォルト）: `deploy/**`, `config/kratos/**`, `config/hydra/**`。ドキュメントだけの変更では走りません。

## やらないこと

- Cloud SQL、グローバル HTTPS LB、Cloud NAT、VPC connector、`min-instances`
- Admin サービスのインターネット公開
- Hydra `secrets.system` のローテーション（既存データが読めなくなる）

独自ドメインが要るときは、月 ~$18 のグローバル LB より先に Firebase Hosting のリバースプロキシを検討してください。`issuer` はクライアント登録より前に確定させます。
