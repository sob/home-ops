output "api_key" {
  description = "The API key for SABnzbd"
  value       = var.api_key
  sensitive   = true
}

output "url" {
  description = "The URL of the SABnzbd instance"
  value       = var.url
}

output "download_dir" {
  description = "Path for incomplete downloads"
  value       = var.download_dir
}

output "complete_dir" {
  description = "Path for completed downloads"
  value       = var.complete_dir
}

output "categories" {
  description = "Configured categories"
  value       = var.categories
}

output "general_settings" {
  description = "General SABnzbd settings"
  value       = local.general_settings
}