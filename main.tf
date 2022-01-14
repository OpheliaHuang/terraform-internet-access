variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }
variable "region" { default = "eu-west-1" }
variable "avaliablity_zone" { default = "eu-west-1c" }

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
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dev-gw.id
  }

  tags = {
    Name = "My-Prod-Route-Table"
  }
}

# added subnet
resource "aws_subnet" "dev-subnet" {
  vpc_id     = aws_vpc.my-aws-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "My-Dev-Subnet"
  }
}

# associate subnet to route table
resource "aws_route_table_association" "my-subnet-association" {
  subnet_id      = aws_subnet.dev-subnet.id
  route_table_id = aws_route_table.prod-route-table.id
}

# create a security group for internet access
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound and outbound traffic"
  vpc_id      = aws_vpc.my-aws-vpc.id

  ingress {
    description = "Allow HTTPS in-bound traffic from all ip addresses"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my-aws-vpc.cidr_block]
  }

  ingress {
    description = "Allow HTTP in-bound traffic from all ip addresses"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my-aws-vpc.cidr_block]
  }

  ingress {
    description = "Allow SSH in-bound traffic from all ip addresses"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.my-aws-vpc.cidr_block]
  }


  egress {
    description      = "Allow outbound traffic from all portocols"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# create a network interface with an ip in the subnet for internet connection
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.dev-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]

  tags = {
    Name = "My-Test-Network-Interface"
  }
}

# associate network interface with an elastic ip address
resource "aws_eip" "my-elastic-ip" {
  vpc                       = true
  network_interface         = aws_network_interface.test.id
  associate_with_private_ip = aws_network_interface.test.private_ip
  depends_on                = [aws_internet_gateway.dev-gw]
}

# create an ubuntu instance
resource "aws_instance" "web-server-instance" {

  ami               = "ami-08ca3fed11864d6bb"
  instance_type     = "t2.micro"
  availability_zone = var.avaliablity_zone
  key_name          = "main-key"

  network_interface {
    network_interface_id = aws_network_interface.test.id
    device_index         = 0
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo this is my first web server on aws > /var/www/html/index.html'
    ls /var
  EOF

  tags = {
    Name = "web-server"
  }


}

output "test-avaliability-zone" {
  value = var.avaliablity_zone
}
