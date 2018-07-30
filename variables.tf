variable "aws_region" {}
variable "aws_profile" {}
data "aws_availability_zones" "available" {}
variable "localip" {}
variable "vpc_cidr" {}
variable "cidrs" {
  type = "map"
}
variable "access_key" {}
variable "secret_key" {}
