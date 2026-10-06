data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = data.aws_availability_zones.available.names[0]
  default_for_az    = true
}

# Existing instance profile, created manually
data "aws_iam_instance_profile" "web" {
  name = var.instance_profile_name
}

resource "aws_security_group" "web" {
  name_prefix = "web-"
  description = "Allow web inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Pick the AMI that matches the instance type's CPU (ARM or x86)
data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

locals {
  arch = contains(data.aws_ec2_instance_type.this.supported_architectures, "arm64") ? "arm64" : "x86_64"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${local.arch}"
}

locals {
  ami_id = coalesce(var.ami_image, data.aws_ssm_parameter.al2023.value)
}

resource "aws_instance" "web" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = data.aws_iam_instance_profile.web.name

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    dnf install -y docker amazon-ecr-credential-helper
    systemctl enable --now docker
    mkdir -p /root/.docker
    echo '{"credsStore":"ecr-login"}' > /root/.docker/config.json
  EOF
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = merge(var.tags, { App = "${var.environment}-content-management-service" })

  lifecycle {
    ignore_changes = [ami]
  }
}