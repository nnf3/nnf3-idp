output "ui_url" {
  value = local.ui_url
}

output "hydra_public_url" {
  value = local.hydra_public_url
}

output "kratos_public_url" {
  value = local.kratos_public_url
}

output "hydra_admin_service" {
  value = google_cloud_run_v2_service.hydra_admin.name
}

output "hydra_admin_url" {
  value       = local.hydra_admin_url
  description = "Internal only. Sync OAuth clients with hydra_sync_clients_job, not a public proxy."
}

output "hydra_sync_clients_job" {
  value       = google_cloud_run_v2_job.hydra_sync_clients.name
  description = "Syncs OAuth clients from config/hydra/clients/{environment}.yaml."
}

output "hydra_create_client_job" {
  value       = google_cloud_run_v2_job.hydra_sync_clients.name
  description = "Deprecated alias for hydra_sync_clients_job."
}

output "kratos_migrate_job" {
  value = google_cloud_run_v2_job.kratos_migrate.name
}

output "hydra_migrate_job" {
  value = google_cloud_run_v2_job.hydra_migrate.name
}

output "artifact_registry" {
  value = local.repo
}

output "kratos_admin_url" {
  value       = local.kratos_admin_url
  description = "Internal only."
}

output "expected_issuer" {
  value       = local.hydra_public_url
  description = "Must match hydra_public_url. If it differs, OIDC clients will break."
}

output "neon_project_id" {
  value = neon_project.idp.id
}

output "authorize_url_example" {
  value = "${local.hydra_public_url}/oauth2/auth?client_id=${var.first_party_client_id}&redirect_uri=${urlencode("${local.app_origin}/callback")}&response_type=code&scope=openid%20offline%20email%20profile&state=gcp-${var.environment}-1"
}

output "cloudbuild_service_account" {
  value       = google_service_account.cloudbuild.email
  description = "User-managed Cloud Build service account for deploy pipelines."
}

output "cloudbuild_deploy_trigger" {
  value       = try(google_cloudbuild_trigger.deploy[0].id, null)
  description = "GitHub-triggered deploy pipeline. Null when github_deploy.enabled is false."
}
