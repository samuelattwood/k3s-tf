variable "cloudflare_account_email" {
	description	= "Cloudflare Account Email"
	type				= string
}
variable "cloudflare_api_key" {
	description	= "Cloudflare API Key"
	type				= string
}
variable "cloudflare_zone_id" {
	description	= "Cloudflare DNS Zone ID"
	type				= string
}
variable "rancher_url" {
	description	= "Rancher Access URL"
	type				= string
}
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
variable "aws_master_instance_type" {
  description = "Kubernetes Master AWS EC2 Instance Type"
  type        = string
  default     = "t4g.xlarge"
}
variable "aws_master_ami" {
  description = "Kubernetes Master AWS AMI"
  type        = string
  default     = "ami-08f182b25f271ef79"
}
variable "aws_worker_instance_type" {
  description = "Kubernetes Worker AWS EC2 Instance Type"
  type        = string
  default     = "t3a.medium"
}
variable "aws_worker_ami" {
  description = "Kubernetes Worker AWS AMI"
  type        = string
  default     = "ami-08895422b5f3aa64a"
}
variable "ssh_authorized_keys" {
  description = "SSH Authorized Key List"
  type        = list
}
variable "cert_manager_version" {
  description = "Version for Jetstack cert-manager"
  type        = string
  default     = "v1.8.0"
}
variable "cert_manager_email" {
  description = "Contact Email for Certs Issued by cert-manager"
  type        = string
}
