terraform {
  required_version = ">= 0.12.6"

  required_providers {
    aws = ">= 2.65"
  }
}

provider "aws" {
  region = "eu-north-1"
}


##################################################################
# Data sources to get VPC, subnet, security group and AMI details
##################################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# module "security_group" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "~> 4.0"
#
#   name        = "pd-task-sg"
#   description = "Security group for pipedrive task"
#   vpc_id      = data.aws_vpc.default.id
#
#   ingress_cidr_blocks = ["0.0.0.0/0"]
#   ingress_rules       = ["http-80-tcp", "all-icmp", ""]
#   egress_rules        = ["all-all"]
# }

resource "aws_eip" "this" {
  vpc      = true
  instance = module.ec2.id[0]
}

# resource "aws_placement_group" "web" {
#   name     = "hunky-dory-pg"
#   strategy = "cluster"
# }

resource "aws_kms_key" "this" {
}

resource "aws_network_interface" "this" {
  count = 1

  subnet_id = tolist(data.aws_subnet_ids.all.ids)[count.index]
}

module "ec2" {
  source = "../../"

  instance_count = 1

  name          = "example-normal"
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = tolist(data.aws_subnet_ids.all.ids)[0]
  #  private_ips                 = ["172.31.32.5", "172.31.46.20"]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  placement_group             = aws_placement_group.web.id

  user_data_base64 = base64encode(local.user_data)

  enable_volume_tags = false
  root_block_device = [
    {
      volume_type = "gp2"
      volume_size = 10
      tags = {
        Name = "my-root-block"
      }
    },
  ]

  ebs_block_device = [
    {
      device_name = "/dev/sdf"
      volume_type = "gp2"
      volume_size = 5
      encrypted   = true
      kms_key_id  = aws_kms_key.this.arn
    }
  ]

  tags = {
    "Env"      = "Private"
    "Location" = "Secret"
  }
}

module "ec2_with_t2_unlimited" {
  source = "../../"

  instance_count = 1

  name          = "example-t2-unlimited"
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  cpu_credits   = "unlimited"
  subnet_id     = tolist(data.aws_subnet_ids.all.ids)[0]
  #  private_ip = "172.31.32.10"
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
}

module "ec2_with_t3_unlimited" {
  source = "../../"

  instance_count = 1

  name                        = "example-t3-unlimited"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.large"
  cpu_credits                 = "unlimited"
  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
}

module "ec2_with_metadata_options" {
  source = "../../"

  instance_count = 1

  name                        = "example-metadata_options"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.small"
  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 8
  }
}

module "ec2_with_network_interface" {
  source = "../../"

  instance_count = 1

  name            = "example-network"
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "c5.large"
  placement_group = aws_placement_group.web.id

  network_interface = [
    {
      device_index          = 0
      network_interface_id  = aws_network_interface.this[0].id
      delete_on_termination = false
    }
  ]
}
