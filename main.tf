terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  email   = var.cloudflare_account_email
  api_key = var.cloudflare_api_key 
}

data "cloudflare_zone" "cf_zone" {
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_record" "cf_record" {
  zone_id = var.cloudflare_zone_id 
  name    = trimsuffix(var.rancher_url, ".${data.cloudflare_zone.cf_zone.name}")
  value = resource.aws_lb.cp_lb.dns_name
  type = "CNAME"
  ttl = 3600
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "cluster_subnet" {
  availability_zone = "${var.aws_region}a"
  default_for_az    = true
  vpc_id            = data.aws_vpc.default.id
}

resource "aws_security_group" "cluster_secgroup" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "http_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = resource.aws_security_group.cluster_secgroup.id
}

resource "aws_security_group_rule" "https_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = resource.aws_security_group.cluster_secgroup.id
}

resource "aws_security_group_rule" "kube_cp_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 6443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = resource.aws_security_group.cluster_secgroup.id
}

resource "aws_security_group_rule" "cluster_internal" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = resource.aws_security_group.cluster_secgroup.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = resource.aws_security_group.cluster_secgroup.id
}

resource "aws_lb_target_group" "cp_lb" {
  for_each    = toset(["80", "443", "6443", "9443"])

  port        = each.value
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id

}

resource "aws_lb_target_group_attachment" "server0" {
  for_each    = toset(["80", "443", "6443", "9443"])

  target_id         = resource.aws_instance.server[0].id
  target_group_arn  = resource.aws_lb_target_group.cp_lb[each.value].arn
}

resource "aws_lb_target_group_attachment" "server1" {
  for_each    = toset(["80", "443", "6443", "9443"])

  target_id         = resource.aws_instance.server[1].id
  target_group_arn  = resource.aws_lb_target_group.cp_lb[each.value].arn
}

resource "aws_lb_target_group_attachment" "server2" {
  for_each    = toset(["80", "443", "6443", "9443"])

  target_id         = resource.aws_instance.server[2].id
  target_group_arn  = resource.aws_lb_target_group.cp_lb[each.value].arn
}

resource "aws_lb_listener" "cp_lb" {
  for_each          = toset(["80", "443", "6443", "9443"])

  load_balancer_arn = resource.aws_lb.cp_lb.arn
  port              = each.value
  protocol          = "TCP"
  
  default_action {
    type              = "forward"
    target_group_arn  = resource.aws_lb_target_group.cp_lb[each.value].arn
  }
  
}

resource "aws_lb" "cp_lb" {
  name                = "cp-lb-${resource.random_string.random.result}"
  internal            = false
  load_balancer_type  = "network"
  subnets             = [data.aws_subnet.cluster_subnet.id] 
  
}

resource "random_password" "k3s_token" {
  length    = 32
  special   = false
}

resource "random_string" "random" {
  length  = 8
  special = false
}

resource "aws_launch_template" "server_launch_template" {
  image_id                  = var.aws_master_ami 
  instance_type             = var.aws_master_instance_type
  user_data                 = data.template_cloudinit_config.server_config.rendered
  network_interfaces {
    associate_public_ip_address = true
    subnet_id           = data.aws_subnet.cluster_subnet.id
    security_groups     = [resource.aws_security_group.cluster_secgroup.id]
  }
}

resource "aws_launch_template" "agent_launch_template" {
  image_id                  = var.aws_worker_ami
  instance_type             = var.aws_worker_instance_type
  user_data                 = data.template_cloudinit_config.agent_config.rendered
  network_interfaces {
    associate_public_ip_address = false
    subnet_id           = data.aws_subnet.cluster_subnet.id
    security_groups     = [resource.aws_security_group.cluster_secgroup.id]
  }
}

resource "aws_instance" "server" {
  count                     = 3
  metadata_options {
    instance_metadata_tags  = "enabled"
    http_endpoint           = "enabled"
  }
  launch_template {
    id      = resource.aws_launch_template.server_launch_template.id
    version = "$Latest"
  }
  tags  = {
    Name           = "k3s-server-${resource.random_string.random.result}-${count.index}"
    ServerInstance = count.index
  }
}

resource "aws_autoscaling_group" "agent_pool" {
  name                  = "k3s-agent-pool-${resource.random_string.random.result}"
  availability_zones    = ["${var.aws_region}a"]
  min_size              = 1
  max_size              = 5
  desired_capacity      = 3
  launch_template {
    id = resource.aws_launch_template.agent_launch_template.id
    version = "$Latest"
  }
}
