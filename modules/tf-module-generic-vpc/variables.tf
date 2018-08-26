variable "create_igw" {
  description = "Attach an Internet GW to the VPC (true/false)"
  default     = "true"
}

variable "create_vgw" {
  description = "Attach a VPN GW to the VPC (true/false)"
  default     = "true"
}

variable "name" {
  description = "The name of the VPC"
}

variable "cidr" {
  description = "CIDR block for the VPC"
}

variable "enable_dns_support" {
  description = "Enable DNS support in VPC"
  default     = "true"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in VPC"
  default     = "true"
}

variable "dhcp_domain_name" {
  description = "The domain name to publish with DHCP"
  default     = "ec2.internal"
}

variable "dhcp_domain_name_servers" {
  description = "List of the domain name servers"
  type        = "list"
  default     = []
}

variable "environment" {
  description = "Specify the environment the resouce belongs to (production, development, staging, testing etc')"
  default     = ""
}

variable "shared_tags" {
  description = "Tags applied to all ressources"
  type        = "map"
  default     = {}
}

variable "create_s3_endpoint" {
  description = "whether to create a VPC S3 Endpoint"
  default     = "false"
}
