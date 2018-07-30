#Terraform main file

provider "aws" {
  region = "${var.aws_region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

#VPC

resource "aws_vpc" "tf_vpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_hostnames = true
}

#IGW

resource "aws_internet_gateway" "tf_igw" {
  vpc_id = "${aws_vpc.tf_vpc.id}"
}

#Route Tables

resource "aws_route_table" "tf_public_rt" {
  vpc_id = "${aws_vpc.tf_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.tf_igw.id}"
  }

  tags {
    Name = "public"
  }
}

resource "aws_default_route_table" "tf_private_rt" {
  default_route_table_id = "${aws_vpc.tf_vpc.default_route_table_id}"

  tags {
    Name = "private"
  }
}

#Subnets

resource "aws_subnet" "tf_public_subnet_1" {
  vpc_id                  = "${aws_vpc.tf_vpc.id}"
  cidr_block              = "${var.cidrs["public_subnet_1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "public1"
  }
}

resource "aws_subnet" "tf_public_subnet_2" {
  vpc_id                  = "${aws_vpc.tf_vpc.id}"
  cidr_block              = "${var.cidrs["public_subnet_2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "public2"
  }
}

resource "aws_subnet" "tf_private_subnet_1" {
  vpc_id                  = "${aws_vpc.tf_vpc.id}"
  cidr_block              = "${var.cidrs["private_subnet_1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "private1"
  }
}

resource "aws_subnet" "tf_private_subnet_2" {
  vpc_id                  = "${aws_vpc.tf_vpc.id}"
  cidr_block              = "${var.cidrs["private_subnet_2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "private2"
  }
}

#subnet associations

resource "aws_route_table_association" "public_1_assoc" {
  subnet_id = "${aws_subnet.tf_public_subnet_1.id}"
  route_table_id = "${aws_route_table.tf_public_rt.id}"
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id = "${aws_subnet.tf_public_subnet_2.id}"
  route_table_id = "${aws_route_table.tf_public_rt.id}"
}















