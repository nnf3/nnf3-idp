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

resource "google_project_iam_member" "cloudbuild_ar" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.this.number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_project_service.services]
}

resource "google_project_iam_member" "cloudbuild_run" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${data.google_project.this.number}@cloudbuild.gserviceaccount.com"

  depends_on = [google_project_service.services]
}
