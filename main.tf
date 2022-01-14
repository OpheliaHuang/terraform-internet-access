variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }
variable "region" { default = "eu-west-1" }

provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# add vpc
resource "aws_vpc" "my-aws-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My-VPC-Instance"
  }
}

# create a internet gateway
resource "aws_internet_gateway" "dev-gw" {
  vpc_id = aws_vpc.my-aws-vpc.id

  tags = {
    Name = "My-Internet-Gateway"
  }
}

# create route table to internet gateway
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.my-aws-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "My-Prod-Route-Table"
  }
}
