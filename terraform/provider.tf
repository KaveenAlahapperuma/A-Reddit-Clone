terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2" # Set your preferred region (e.g., us-west-2 or us-east-1)
}

# Automatically query the latest official Ubuntu 22.04 LTS AMI for the configured region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu Publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"] # Matches t2.large architecture
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
