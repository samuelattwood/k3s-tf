output "rancher_url" {
  description = "Rancher Access URL"
  value       = var.rancher_url
}
output "boostrap_password" {
  description = "Rancher Boostrap Password"
  value       = resource.random_string.random.result
}
