output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "vpc_cidr_block" {
  value = "${aws_vpc.main.cidr_block}"
}

output "vpn_gateway_id" {
  value = "${element(concat(aws_vpn_gateway.vpn_gateway.*.id, list("")), 0)}" 
}

output "vpc_name" {
  value = "${var.name}"
}

output "internet_gateway_id" {
  value = "${element(concat(aws_internet_gateway.igw.*.id, list("")), 0)}" 
}

output "vpc_s3_endpoint" {
  value = "${element(concat(aws_vpc_endpoint.s3-endpoint.*.id, list("")), 0)}" 
}
