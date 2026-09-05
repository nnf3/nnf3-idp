output "ui_url" {
  value = module.idp.ui_url
}

output "hydra_public_url" {
  value = module.idp.hydra_public_url
}

output "kratos_public_url" {
  value = module.idp.kratos_public_url
}

output "hydra_admin_service" {
  value = module.idp.hydra_admin_service
}

output "hydra_admin_url" {
  value = module.idp.hydra_admin_url
}

output "kratos_admin_url" {
  value = module.idp.kratos_admin_url
}

output "expected_issuer" {
  value = module.idp.expected_issuer
}

output "neon_project_id" {
  value = module.idp.neon_project_id
}

output "authorize_url_example" {
  value = module.idp.authorize_url_example
}

output "kratos_migrate_job" {
  value = module.idp.kratos_migrate_job
}

output "hydra_migrate_job" {
  value = module.idp.hydra_migrate_job
}

output "hydra_create_client_job" {
  value = module.idp.hydra_create_client_job
}

output "artifact_registry" {
  value = module.idp.artifact_registry
}
