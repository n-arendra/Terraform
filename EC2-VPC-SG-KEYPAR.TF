 terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
} 

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

#Generate .pem file
resource "tls_private_key" "rsa_4096" {
  algorithm   = "RSA"
  rsa_bits =  4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = "us-east-2"
  public_key = tls_private_key.rsa_4096.public_key_openssh
  }

resource "local_file" "foo" {
  content = tls_private_key.rsa_4096.private_key_pem
  filename = "us-east-2"
}

locals {
  ports_in = [
    443,
    80,
    22
  ]
  ports_out = [
    0
  ]
}

resource "aws_security_group" "secgrp" {
    name = "terra_SG"
    vpc_id = aws_vpc.cust-VPC.id
   
    dynamic "ingress" {
    for_each = toset(local.ports_in)
    content {
      description      = "HTTPS from VPC"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }

  dynamic "egress" {
    for_each = toset(local.ports_out)
    content {
      from_port        = egress.value
      to_port          = egress.value
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }
}

resource "aws_vpc" "cust-VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "Cust-VPC"
  }
}

resource "aws_subnet" "public-subent" {
  vpc_id     = aws_vpc.cust-VPC.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "Public-subnet"
  }
}


resource "aws_subnet" "private-subent" {
  vpc_id     = aws_vpc.cust-VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "Private-subnet"
  }
}

resource "aws_internet_gateway" "internet-gt" {
  vpc_id = aws_vpc.cust-VPC.id

  tags = {
    Name = "Internet-Gateway"
  }
}

resource "aws_egress_only_internet_gateway" "ipv6-gateway" {
  vpc_id = aws_vpc.cust-VPC.id

  tags = {
    Name = "IPV6-gateway"
  }
}


resource "aws_eip" "ip1" {
  vpc      = true
}

resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.ip1.id
  subnet_id     = aws_subnet.private-subent.id

  tags = {
    Name = "NAT-gateway"
  }
  depends_on = [ aws_internet_gateway.internet-gt ]
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.cust-VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gt.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.ipv6-gateway.id
  }

  tags = {
    Name = "Public-RouteTable"
  }
}

resource "aws_route_table_association" "public-association" {
  subnet_id      = aws_subnet.public-subent.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.cust-VPC.id

  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_nat_gateway.nat-gateway.id
  }

  tags = {
    Name = "Private-RouteTable"
  }
}

resource "aws_route_table_association" "private-association" {
  subnet_id      = aws_subnet.private-subent.id
  route_table_id = aws_route_table.private-rt.id
}


resource "aws_instance" "instance-1" {
  ami           = "ami-0e820afa569e84cc1"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.secgrp.id]
  subnet_id = aws_subnet.public-subent.id

  tags = {
    Name = "Public-instance"
  }
}

resource "aws_instance" "instance-2" {
  ami           = "ami-0e820afa569e84cc1"
  instance_type = "t2.micro"
  key_name = aws_key_pair.key_pair.key_name
  vpc_security_group_ids = [aws_security_group.secgrp.id]
  subnet_id = aws_subnet.private-subent.id

  tags = {
    Name = "Private-instance"
  }
}
