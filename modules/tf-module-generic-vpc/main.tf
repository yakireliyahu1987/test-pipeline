# /Resources

locals {
  common_tags = {
    CreatedBy   = "Terraform"
    Environment = "${var.environment}"
  }
}

data "aws_region" "current" {
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr}"
  enable_dns_support   = "${var.enable_dns_support}"
  enable_dns_hostnames = "${var.enable_dns_hostnames}"

  tags = "${merge(local.common_tags, var.shared_tags, map(
      "Name", "${var.name}"
  ))}"
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  count  = "${var.create_igw ? 1 : 0}"
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.shared_tags, map(
      "Name", "igw-${var.name}"
  ))}"
}

# Define the Virtual Private Gateway for the VPC
resource "aws_vpn_gateway" "vpn_gateway" {
  count  = "${var.create_vgw ? 1 : 0}"
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(local.common_tags, var.shared_tags, map(
      "Name", "vgw-${var.name}"
  ))}"
}

# Create DHCP Options
resource "aws_vpc_dhcp_options" "dhcp_options" {
  domain_name         = "${var.dhcp_domain_name}"
  domain_name_servers = ["${split(",", length(var.dhcp_domain_name_servers) != 0 ? join(",", var.dhcp_domain_name_servers) : "AmazonProvidedDNS")}"]

  tags = "${merge(local.common_tags, var.shared_tags, map(
      "Name", "dhcp_${aws_vpc.main.id}"
  ))}"
}

# Associate the DHCP Options we created with our VPC
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.dhcp_options.id}"
}

resource "aws_vpc_endpoint" "s3-endpoint" {
  count        = "${var.create_s3_endpoint != "false" ? 1 : 0 }"
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_id       = "${aws_vpc.main.id}"
}
