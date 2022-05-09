data "template_cloudinit_config" "server_config" {
  gzip          = true
  base64_encode = true

    part {
      filename              = "cloud-config.yaml"
      content_type          = "text/cloud-config"
      content               = templatefile("${path.module}/files/cloud-config.yaml", {
        ssh_authorized_keys = var.ssh_authorized_keys
      }) 
    }

    part {
      content_type = "text/x-shellscript"
      content                     = templatefile("${path.module}/files/k3s-init.tftpl", {
        bootstrap_password        = resource.random_string.random.result
        cert_manager_email        = var.cert_manager_email
        cert_manager_version        = var.cert_manager_version
        cloudflare_account_email  = var.cloudflare_account_email
        cloudflare_api_key        = var.cloudflare_api_key
        k3s_token                 = resource.random_password.k3s_token.result
        node_type                 = "server"
        rancher_url               = var.rancher_url
        server_url                = resource.aws_lb.cp_lb.dns_name
      }) 
    }
}

data "template_cloudinit_config" "agent_config" {
  gzip          = true
  base64_encode = true

    part {
      filename              = "cloud-config.yaml"
      content_type          = "text/cloud-config"
      content               = templatefile("${path.module}/files/cloud-config.yaml", {
        ssh_authorized_keys = var.ssh_authorized_keys
      }) 
    }

    part {
      content_type = "text/x-shellscript"
      content               = templatefile("${path.module}/files/k3s-init.tftpl", {
        bootstrap_password        = resource.random_string.random.result
        cert_manager_email        = var.cert_manager_email
        cert_manager_version        = var.cert_manager_version
        cloudflare_account_email  = var.cloudflare_account_email
        cloudflare_api_key        = var.cloudflare_api_key
        k3s_token                 = resource.random_password.k3s_token.result
        node_type                 = "agent"
        rancher_url               = ""
        server_url                = resource.aws_lb.cp_lb.dns_name
      }) 
    }
}
