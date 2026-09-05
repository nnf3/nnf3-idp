resource "google_cloud_run_v2_job" "kratos_migrate" {
  name     = local.job.kratos_migrate
  location = var.region

  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.run.email

      containers {
        image = local.kratos_image
        args  = ["migrate", "sql", "-e", "--yes", "-c", "/etc/config/kratos/kratos.gcp.yml"]

        env {
          name = "DSN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this["kratos-dsn-direct"].secret_id
              version = "latest"
            }
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

resource "google_cloud_run_v2_job" "hydra_migrate" {
  name     = local.job.hydra_migrate
  location = var.region

  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.run.email

      containers {
        image = local.hydra_image
        args  = ["migrate", "-c", "/etc/config/hydra/hydra.gcp.yml", "sql", "up", "-e", "--yes"]

        env {
          name = "DSN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this["hydra-dsn-direct"].secret_id
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

        env {
          name  = "URLS_SELF_ISSUER"
          value = local.hydra_public_url
        }

        env {
          name  = "URLS_LOGIN"
          value = "${local.ui_url}/login"
        }

        env {
          name  = "URLS_CONSENT"
          value = "${local.ui_url}/consent"
        }

        env {
          name  = "URLS_LOGOUT"
          value = "${local.ui_url}/logout"
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

resource "google_cloud_run_v2_job" "hydra_create_client" {
  name     = local.job.hydra_create_client
  location = var.region

  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.run.email
      timeout         = "120s"

      containers {
        image   = local.hydra_image
        command = ["sh", "-c"]
        args = [<<-EOT
          set -eu
          hydra serve admin -c /etc/config/hydra/hydra.gcp.yml --sqa-opt-out &
          i=0
          while [ "$i" -lt 45 ]; do
            if wget -q -O /dev/null http://127.0.0.1:8080/health/alive; then
              break
            fi
            i=$((i + 1))
            sleep 1
          done
          hydra create oauth2-client \
            --endpoint http://127.0.0.1:8080 \
            --id "$CLIENT_ID" \
            --name "NNF3 Web" \
            --grant-type authorization_code,refresh_token \
            --response-type code \
            --scope openid,offline,offline_access,email,profile \
            --redirect-uri "$REDIRECT_URI" \
            --token-endpoint-auth-method none \
            --skip-consent \
            --skip-logout-consent
        EOT
        ]

        env {
          name  = "CLIENT_ID"
          value = var.first_party_client_id
        }

        env {
          name  = "REDIRECT_URI"
          value = "${local.app_origin}/callback"
        }

        env {
          name  = "URLS_SELF_ISSUER"
          value = local.hydra_public_url
        }

        env {
          name  = "URLS_LOGIN"
          value = "${local.ui_url}/login"
        }

        env {
          name  = "URLS_CONSENT"
          value = "${local.ui_url}/consent"
        }

        env {
          name  = "URLS_LOGOUT"
          value = "${local.ui_url}/logout"
        }

        env {
          name = "DSN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this["hydra-dsn-direct"].secret_id
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
  }

  depends_on = [
    google_secret_manager_secret_version.this,
    google_project_iam_member.run_secret_accessor,
  ]
}

resource "google_cloud_run_v2_job" "hydra_janitor" {
  name     = local.job.hydra_janitor
  location = var.region

  deletion_protection = var.deletion_protection

  template {
    template {
      service_account = google_service_account.run.email

      containers {
        image = local.hydra_image
        args  = ["janitor", "-c", "/etc/config/hydra/hydra.gcp.yml", "--tokens", "--requests", "--grants"]

        env {
          name = "DSN"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.this["hydra-dsn-direct"].secret_id
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

        env {
          name  = "URLS_SELF_ISSUER"
          value = local.hydra_public_url
        }

        env {
          name  = "URLS_LOGIN"
          value = "${local.ui_url}/login"
        }

        env {
          name  = "URLS_CONSENT"
          value = "${local.ui_url}/consent"
        }

        env {
          name  = "URLS_LOGOUT"
          value = "${local.ui_url}/logout"
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

resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_project_iam_member" "run_can_invoke" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.run.email}"
}

resource "google_cloud_scheduler_job" "hydra_janitor" {
  name      = "hydra-janitor-weekly-${var.environment}"
  region    = var.region
  schedule  = "0 3 * * 0"
  time_zone = "Asia/Tokyo"

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.hydra_janitor.name}:run"

    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }

  depends_on = [
    google_project_service.services,
    google_project_iam_member.scheduler_run_invoker,
  ]
}
