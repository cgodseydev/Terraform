#Terraform main file

provider "aws" {
  region     = "${var.aws_region}"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
}

#VPC

resource "aws_vpc" "tf_vpc" {
  cidr_block           = "10.1.0.0/16"
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
  subnet_id      = "${aws_subnet.tf_public_subnet_1.id}"
  route_table_id = "${aws_route_table.tf_public_rt.id}"
}

resource "aws_route_table_association" "public_2_assoc" {
  subnet_id      = "${aws_subnet.tf_public_subnet_2.id}"
  route_table_id = "${aws_route_table.tf_public_rt.id}"
}

#VPC Endpoint for S3

resource "aws_vpc_endpoint" "tf_privateS3_endpoint" {
  vpc_id       = "${aws_vpc.tf_vpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = ["${aws_vpc.tf_vpc.main_route_table_id}", "${aws_route_table.tf_public_rt.id}"]

  policy = <<POLICY
{
  "Statement": [
      {
        "Action": "*",
        "Effect": "Allow",
        "Resource": "*",
        "Principle": "*"
      }
    ]
}
POLICY
}

#------ S3 Code Bucket -----

#S3 KMS Master Key

resource "aws_kms_key" "s3_kms_key" {
  description = "This key is used for encrypting objects in S3 bucket"
  deletion_window_in_days = 10
}

resource "random_id" "tf_code_bucket" {
  byte_length = 2
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.domain_name}-${random_id.tf_code_bucket.dec}"
  acl           = "private"
  force_destroy = true
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.s3_kms_key.arn}"
        sse_algorithm = "aws:kms"
      }
    }
  }
  versioning {
    enabled = true
  }

  tags {
    Name = "code bucket"
  }
}

#----- RDS -----

#DB Subnet Group

resource "aws_db_subnet_group" "tf_db_subnet_group" {
  name = "tf_db_subnet_group"
  subnet_ids = ["${aws_subnet.tf_private_subnet_1.id}", "${aws_subnet.tf_private_subnet_2.id}"]
}

#RDS Security Group

resource "aws_security_group" "tf_rds_sg" {
  name = "tf_rds_sg"
  description = "RDS access within the VPC only"
  vpc_id = "${aws_vpc.tf_vpc.id}"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
}

#RDS Instance

resource "aws_db_instance" "tf_db" {
  name = "${var.db_name}"
  allocated_storage = 20
  engine = "mysql"
  instance_class = "db.t2.micro" 
  password = "${var.db_password}"
  username = "db_user"
  storage_encrypted = true
  availability_zone = "${data.aws_availability_zones.available.names[0]}"
  vpc_security_group_ids = ["${aws_security_group.tf_rds_sg.id}"]
  db_subnet_group_name = "tf_db_subnet_group"
}

#EC2 Dev Instance

#EC2 Security Group

resource "aws_security_group" "tf_public_sg" {
  name = "tf_public_sg"
  description = "EC2 security group"
  vpc_id = "${aws_vpc.tf_vpc.id}"

  #HTTP

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound Internet Access

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#EC2 IAM Role

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = "${aws_iam_role.ec2_role.id}"

  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "s3:*",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"
  path = "/"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

#Key Pair

resource "aws_key_pair" "tf_dev_auth" {
  key_name = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#Dev Instance

resource "aws_instance" "tf_dev" {
  instance_type = "${var.dev_instance_type}"
  ami = "${var.dev_ami}"
  
  tags {
    Name = "tf_dev"
  }

  key_name = "${aws_key_pair.tf_dev_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.tf_public_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.ec2_profile.id}"
  sunet_id = "${aws_subnet.tf_public_subnet_1.id}"

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF> aws_hosts
[dev]
${aws_instance.tf_dev.public_ip}
[dev:vars]
s3code=${aws_s3_bucket.code.bucket}
domain${var.domain_name}
EOF
EOD
}

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.tf_dev.id} --profile ${var.aws_profile} && ansible-playbook -i aws_hosts wordpress.yml"
  }
}





