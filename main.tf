terraform {
  required_version = ">= 0.12.6"

  required_providers {
    aws = ">= 2.65"
  }
}

provider "aws" {
  region = "us-east-1"
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

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"


  name        = "pd-task-sg"
  description = "Security group for pipedrive technical task"
  vpc_id      = data.aws_vpc.default.id
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "ssh"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9200
      to_port     = 9200
      protocol    = "tcp"
      description = "elasticsearch"
      cidr_blocks = "172.31.0.0/16"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      description = "http"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 9300
      to_port     = 9300
      protocol    = "tcp"
      description = "elasticsearch_node"
      cidr_blocks = "172.31.0.0/16"
    },
    {
      from_port   = 9100
      to_port     = 9100
      protocol    = "tcp"
      description = "node_exporter"
      cidr_blocks = "172.31.0.0/16"
    },
    {
      from_port   = 9090
      to_port     = 9090
      protocol    = "tcp"
      description = "prometheus"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = -1
      cidr_blocks = "0.0.0.0/0"
  }]
}


module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  instance_count = 3

  name                        = "example-normal"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.large"
  subnet_id                   = tolist(data.aws_subnet_ids.all.ids)[0]
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true
  key_name                    = "Acer-Laptop"
}

resource "local_file" "ansible_hosts" {
  content = <<EOT
vm-1 ansible_host=${tostring(module.ec2.public_ip[0])} ansible_port=22 ansible_ssh_user=ubuntu ansible_python_interpreter=python3
vm-2 ansible_host=${tostring(module.ec2.public_ip[1])} ansible_port=22 ansible_ssh_user=ubuntu ansible_python_interpreter=python3
vm-3 ansible_host=${tostring(module.ec2.public_ip[2])} ansible_port=22 ansible_ssh_user=ubuntu ansible_python_interpreter=python3

[kibana]
vm-1

[es_master]
vm-1

[es_data]
vm-2
vm-3

[logstash]
vm-2


[grafana]
vm-1

[prometheus]
vm-1
EOT

  filename = "hosts"
}
