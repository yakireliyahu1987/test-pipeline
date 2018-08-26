# Terraform Module - Generic VPC

## Overview

Generic module for creating a VPC.

### Variables

* `create_igw` - Attach an Internet GW to the VPC (boolean).
* `create_vgw` - Attach a VPN GW to the VPC (boolean).
* `name` - The name of the VPC.
* `cidr` - CIDR block for the VPC.
* `enable_dns_support` - Enable DNS support in VPC (boolean).
* `enable_dns_hostnames` - Enable DNS hostnames in VPC (boolean).
* `dhcp_domain_name` - The domain name to publish with DHCP.
* `dhcp_domain_name_servers` - List of the domain name servers.
* `environment` - Tag applied to all resources

### Resources Created

* VPC
* Internet GW
* Virtual GW

### Outputs

* `vpc_id` - ID of the new VPC.
* `internet_gateway_id` - ID of the new Internet Gateway.
* `vpn_gateway_id` - ID of the new VPN Gateway.

## Prerequisites and Dependencies

* **Developed on Terraform 0.9.11**

## Usage

This module should be declared as a Terraform module in your main `.tf` file. Example:

    module "<tf-module-generic-vpc>" {
      source = "git::ssh://git@bitbucket.org/emindsys/tf-module-generic-vpc.git"

      name      = "${var.name}"
      cidr      = "${var.cidr}"
    }

## Maintainer

This module is maintained by [Virgil Niculescu](mailto:virgil.niculescu@allcloud.io).
