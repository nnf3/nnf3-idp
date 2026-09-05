resource "random_password" "hydra_system" {
  length  = 32
  special = false
}

resource "random_password" "kratos_cookie" {
  length  = 32
  special = false
}

resource "random_password" "kratos_cipher" {
  length  = 32
  special = false
}

resource "random_password" "ui_cookie" {
  length  = 32
  special = false
}

resource "random_password" "ui_csrf" {
  length  = 32
  special = false
}

locals {
  secrets = {
    kratos-dsn-pooled = local.kratos_dsn_pooled
    kratos-dsn-direct = local.kratos_dsn_direct
    hydra-dsn-pooled  = local.hydra_dsn_pooled
    hydra-dsn-direct  = local.hydra_dsn_direct
    hydra-system      = random_password.hydra_system.result
    kratos-cookie     = random_password.kratos_cookie.result
    kratos-cipher     = random_password.kratos_cipher.result
    ui-cookie         = random_password.ui_cookie.result
    ui-csrf           = random_password.ui_csrf.result
    smtp-uri          = var.smtp_connection_uri
  }
}

resource "google_secret_manager_secret" "this" {
  for_each  = local.secrets
  secret_id = "${local.prefix}-${each.key}"

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_version" "this" {
  for_each    = local.secrets
  secret      = google_secret_manager_secret.this[each.key].id
  secret_data = each.value
}

resource "google_project_iam_member" "run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.run.email}"
}
