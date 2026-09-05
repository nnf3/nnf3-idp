resource "google_cloudbuild_trigger" "deploy" {
  count = var.github_deploy.enabled ? 1 : 0

  name        = "idp-deploy-${var.environment}"
  description = "Build IdP images, deploy to Cloud Run, and run migrations (${var.environment})"
  # 第 1 世代の GitHub 連携は Cloud Run と同じリージョンにあるとは限らない。
  # Console の接続画面（asia-northeast1 など）か global に合わせる。
  location = var.github_deploy.trigger_location

  # 第 1 世代: Console で「Cloud Build GitHub アプリ」経由の接続を使う（接続名不要）
  github {
    owner = var.github_deploy.owner
    name  = var.github_deploy.repository

    push {
      branch = var.github_deploy.branch_pattern
      tag    = var.github_deploy.tag_pattern
    }
  }

  filename       = "deploy/cloudbuild.yaml"
  included_files = var.github_deploy.included_files

  substitutions = {
    _PROJECT_ID       = var.project_id
    _ENV              = var.environment
    _REGION           = var.region
    _REPO             = local.repo
    _TAG              = var.github_deploy.image_tag_substitution
    _HYDRA_PUBLIC_URL = local.hydra_public_url
    _UI_URL           = local.ui_url
    _DEPLOY           = "true"
    _MIGRATE          = "true"
    _SYNC_CLIENTS     = "true"
  }

  service_account = google_service_account.cloudbuild.id

  depends_on = [
    google_project_iam_member.cloudbuild_ar,
    google_project_iam_member.cloudbuild_run,
    google_project_iam_member.cloudbuild_secret_accessor,
    google_project_iam_member.cloudbuild_builder,
    google_service_account_iam_member.cloudbuild_run_sa_user,
  ]
}

resource "google_service_account_iam_member" "cloudbuild_run_sa_user" {
  service_account_id = google_service_account.run.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# 手元から gcloud builds submit する Terraform 用 SA が Cloud Build SA を使えるようにする
resource "google_service_account_iam_member" "cloudbuild_sa_user_terraform" {
  service_account_id = google_service_account.cloudbuild.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:idp-terraform@${var.project_id}.iam.gserviceaccount.com"
}
