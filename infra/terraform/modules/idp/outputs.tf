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
  description = "Internal only. Create clients with hydra_create_client_job, not a public proxy."
}

output "hydra_create_client_job" {
  value = google_cloud_run_v2_job.hydra_create_client.name
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
