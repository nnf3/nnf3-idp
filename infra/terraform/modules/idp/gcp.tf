resource "google_project_service" "services" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudscheduler.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "idp" {
  location      = var.region
  repository_id = "idp-${var.environment}"
  description   = "Kratos and Hydra images for ${local.name}"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}

resource "google_service_account" "run" {
  account_id   = "${local.prefix}-run"
  display_name = "${local.name} Cloud Run"
}

resource "google_service_account" "scheduler" {
  account_id   = "${local.prefix}-scheduler"
  display_name = "${local.name} Cloud Scheduler"
}

resource "google_service_account" "cloudbuild" {
  account_id   = "${local.prefix}-build"
  display_name = "${local.name} Cloud Build"
}

resource "google_project_iam_member" "cloudbuild_ar" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "cloudbuild_run" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "cloudbuild_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "cloudbuild_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"

  depends_on = [google_project_service.services]
}

# Cloud Build のソース/ログ用バケット（{project_id}_cloudbuild）は初回 submit 時に自動作成される
data "google_storage_bucket" "cloudbuild" {
  name = "${var.project_id}_cloudbuild"

  depends_on = [google_project_service.services]
}

resource "google_storage_bucket_iam_member" "cloudbuild_source" {
  bucket = data.google_storage_bucket.cloudbuild.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloudbuild.email}"
}
