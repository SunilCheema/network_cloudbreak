provider "aws" {

profile    = "default"
region     = "us-west-2"

}

locals {
  instance-userdata = <<EOF
  #!/bin/bash

  yum -y update
  yum -y install net-tools ntp wget lsof unzip tar iptables-services
  systemctl enable ntpd && systemctl start ntpd
  systemctl disable firewalld && systemctl stop firewalld
  iptables --flush INPUT && \
  iptables --flush FORWARD && \
  service iptables save
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  getenforce
  yum install -y docker
  systemctl start docker
  systemctl enable docker
  sed -i 's/journald/json-file/' /etc/sysconfig/docker
  systemctl restart docker
  systemctl status docker
  yum -y install unzip tar
  curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.8.0_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd
  cbd --version
  mkdir cloudbreak-deployment
  cd cloudbreak-deployment
  curl https://ipinfo.io/ip > address.txt
  ip=$(cat address.txt)
  printf "export UAA_DEFAULT_SECRET=<secret>\nexport UAA_DEFAULT_USER_PW=<password>\nexport UAA_DEFAULT_USER_EMAIL=<email>\nexport PUBLIC_IP=$ip\n" > Profile
  rm *.yml
  cbd generate
  cbd pull-parallel
  sudo cbd start
EOF
}

variable "instance_type_size" {
  type    = list(string)
  default = ["t2.medium"]
}

variable "ip_block" {
  type    = string
}

resource "aws_vpc" "terraform2" {

cidr_block       = "10.0.0.0/16"
tags = {
    Name = "terraformWork"
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.terraform2.id}"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "public_subnet" {

vpc_id     = "${aws_vpc.terraform2.id}"
cidr_block = "10.0.1.0/24"
tags = {
    Name = "terraformWork"
  }

}

resource "aws_subnet" "private_subnet" {
vpc_id     = "${aws_vpc.terraform2.id}"
cidr_block = "10.0.2.0/24"

tags = {
    Name = "terraformWork"
  }

}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.terraform2.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "terraformWork"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.terraform2.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.natGateway.id}"
  }

  tags = {
    Name = "terraformWork"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "b" {
  subnet_id      = "${aws_subnet.private_subnet.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_eip" "lb" {
  vpc      = true
}

resource "aws_nat_gateway" "natGateway" {
  allocation_id = "${aws_eip.lb.id}"
  subnet_id     = "${aws_subnet.public_subnet.id}"
}

resource "aws_security_group" "allow_ssh_https" {
  name        = "allow_ssh_https"
  description = "inbound traffic rules"
  vpc_id      = "${aws_vpc.terraform2.id}"

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["${var.ip_block}"]
  }

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["${var.ip_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh_and_https"
  }
}

resource "aws_instance" "example" {

ami           = "ami-01ed306a12b7d1c96"
instance_type = "${var.instance_type_size[0]}"
subnet_id = "${aws_subnet.public_subnet.id}"
vpc_security_group_ids = ["${aws_security_group.allow_ssh_https.id}"]
associate_public_ip_address = true
key_name = "OregonPair"
user_data = "${local.instance-userdata}"

}
