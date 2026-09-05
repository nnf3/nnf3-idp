locals {
  kratos_common_env = {
    # Browser-facing Kratos endpoints are proxied through the UI host so the
    # browser flow's CSRF cookie is available to the server-rendered UI.
    SERVE_PUBLIC_BASE_URL                                     = local.ui_url
    SERVE_ADMIN_BASE_URL                                      = local.kratos_admin_url
    SERVE_PUBLIC_CORS_ALLOWED_ORIGINS                         = local.cors_origins
    OAUTH2_PROVIDER_URL                                       = local.hydra_admin_url
    SELFSERVICE_DEFAULT_BROWSER_RETURN_URL                    = local.ui_url
    SELFSERVICE_ALLOWED_RETURN_URLS                           = local.return_urls
    SELFSERVICE_FLOWS_ERROR_UI_URL                            = "${local.ui_url}/error"
    SELFSERVICE_FLOWS_SETTINGS_UI_URL                         = "${local.ui_url}/settings"
    SELFSERVICE_FLOWS_RECOVERY_UI_URL                         = "${local.ui_url}/recovery"
    SELFSERVICE_FLOWS_VERIFICATION_UI_URL                     = "${local.ui_url}/verification"
    SELFSERVICE_FLOWS_LOGOUT_AFTER_DEFAULT_BROWSER_RETURN_URL = "${local.ui_url}/login"
    SELFSERVICE_FLOWS_LOGIN_UI_URL                            = "${local.ui_url}/login"
    SELFSERVICE_FLOWS_REGISTRATION_UI_URL                     = "${local.ui_url}/registration"
  }

  hydra_common_env = {
    URLS_SELF_ISSUER                  = local.hydra_public_url
    URLS_LOGIN                        = "${local.ui_url}/login"
    URLS_CONSENT                      = "${local.ui_url}/consent"
    URLS_LOGOUT                       = "${local.ui_url}/logout"
    SERVE_PUBLIC_CORS_ALLOWED_ORIGINS = local.cors_origins
  }
}

resource "google_cloud_run_v2_service" "kratos_public" {
  name     = local.service.kratos_public
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = var.deletion_protection

  # API writes a service-level scaling block (manual_instance_count=0) that we do not set.
  lifecycle {
    ignore_changes = [
      scaling,
      template[0].containers[0].image,
    ]
  }

  template {
    service_account                  = google_service_account.run.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.idp.id
        subnetwork = google_compute_subnetwork.idp.id
      }
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = local.kratos_image
      args  = ["serve", "-c", "/etc/config/kratos/kratos.gcp.yml", "--watch-courier", "--sqa-opt-out"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      startup_probe {
        http_get {
          path = "/health/alive"
        }
        initial_delay_seconds = 2
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 12
      }

      dynamic "env" {
        for_each = local.kratos_common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DSN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-dsn-pooled"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_COOKIE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-cookie"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_CIPHER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-cipher"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "COURIER_SMTP_CONNECTION_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["smtp-uri"].secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.idp,
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
    google_dns_record_set.run_app,
  ]
}

resource "google_cloud_run_v2_service" "kratos_admin" {
  name                 = local.service.kratos_admin
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true

  deletion_protection = var.deletion_protection

  # API writes a service-level scaling block (manual_instance_count=0) that we do not set.
  lifecycle {
    ignore_changes = [
      scaling,
      template[0].containers[0].image,
    ]
  }

  template {
    service_account                  = google_service_account.run.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.idp.id
        subnetwork = google_compute_subnetwork.idp.id
      }
    }

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = local.kratos_image
      args  = ["serve", "-c", "/etc/config/kratos/kratos.gcp.yml", "--sqa-opt-out"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      startup_probe {
        http_get {
          path = "/admin/health/alive"
        }
        initial_delay_seconds = 2
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 12
      }

      env {
        name  = "SERVE_PUBLIC_PORT"
        value = "4433"
      }

      env {
        name  = "SERVE_ADMIN_PORT"
        value = "8080"
      }

      dynamic "env" {
        for_each = local.kratos_common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DSN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-dsn-pooled"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_COOKIE"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-cookie"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_CIPHER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["kratos-cipher"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "COURIER_SMTP_CONNECTION_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["smtp-uri"].secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.idp,
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
    google_dns_record_set.run_app,
  ]
}

resource "google_cloud_run_v2_service" "hydra_public" {
  name     = local.service.hydra_public
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = var.deletion_protection

  # API writes a service-level scaling block (manual_instance_count=0) that we do not set.
  lifecycle {
    ignore_changes = [
      scaling,
      template[0].containers[0].image,
    ]
  }

  template {
    service_account                  = google_service_account.run.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = local.hydra_image
      args  = ["serve", "public", "-c", "/etc/config/hydra/hydra.gcp.yml", "--sqa-opt-out"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      startup_probe {
        http_get {
          path = "/health/alive"
        }
        initial_delay_seconds = 2
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 12
      }

      dynamic "env" {
        for_each = local.hydra_common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DSN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["hydra-dsn-pooled"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_SYSTEM"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["hydra-system"].secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.idp,
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
  ]
}

resource "google_cloud_run_v2_service" "hydra_admin" {
  name                 = local.service.hydra_admin
  location             = var.region
  ingress              = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  invoker_iam_disabled = true

  deletion_protection = var.deletion_protection

  # API writes a service-level scaling block (manual_instance_count=0) that we do not set.
  lifecycle {
    ignore_changes = [
      scaling,
      template[0].containers[0].image,
    ]
  }

  template {
    service_account                  = google_service_account.run.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = local.hydra_image
      args  = ["serve", "admin", "-c", "/etc/config/hydra/hydra.gcp.yml", "--sqa-opt-out"]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      startup_probe {
        http_get {
          path = "/health/alive"
        }
        initial_delay_seconds = 2
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 12
      }

      dynamic "env" {
        for_each = local.hydra_common_env
        content {
          name  = env.key
          value = env.value
        }
      }

      env {
        name = "DSN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["hydra-dsn-pooled"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "SECRETS_SYSTEM"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["hydra-system"].secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_artifact_registry_repository.idp,
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
  ]
}

resource "google_cloud_run_v2_service" "ui" {
  name     = local.service.ui
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = var.deletion_protection

  # API writes a service-level scaling block (manual_instance_count=0) that we do not set.
  lifecycle {
    ignore_changes = [
      scaling,
      template[0].containers[0].image,
    ]
  }

  template {
    service_account                  = google_service_account.run.email
    timeout                          = "60s"
    max_instance_request_concurrency = 40

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = google_compute_network.idp.id
        subnetwork = google_compute_subnetwork.idp.id
      }
    }

    containers {
      image = local.ui_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "KRATOS_PUBLIC_URL"
        value = local.kratos_public_url
      }

      env {
        name  = "KRATOS_BROWSER_URL"
        value = local.ui_url
      }

      env {
        name  = "KRATOS_ADMIN_URL"
        value = "http://127.0.0.1:8081/kratos"
      }

      env {
        name  = "HYDRA_ADMIN_URL"
        value = "http://127.0.0.1:8081/hydra"
      }

      env {
        name  = "KRATOS_ADMIN_UPSTREAM"
        value = local.kratos_admin_url
      }

      env {
        name  = "HYDRA_ADMIN_UPSTREAM"
        value = local.hydra_admin_url
      }

      env {
        name  = "TRUSTED_CLIENT_IDS"
        value = var.first_party_client_id
      }

      env {
        name  = "CSRF_COOKIE_NAME"
        value = "ory_csrf_ui"
      }

      env {
        name = "COOKIE_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["ui-cookie"].secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "CSRF_COOKIE_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.this["ui-csrf"].secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
    google_dns_record_set.run_app,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  for_each = {
    kratos_public = google_cloud_run_v2_service.kratos_public
    hydra_public  = google_cloud_run_v2_service.hydra_public
    ui            = google_cloud_run_v2_service.ui
  }

  project  = var.project_id
  location = var.region
  name     = each.value.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

