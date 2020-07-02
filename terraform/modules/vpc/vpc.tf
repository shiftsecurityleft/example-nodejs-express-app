### Network
variable "AZ_COUNT" {
  description = "Number of AZs to cover in a given AWS region"
  default     = "2"
}

variable "VPC_NAME" {
  description = "the Name tag of any resources created"
}

variable "VPC_CIDR" {
  description = "the Name tag of any resources created"
  default     = "172.18.0.0/16"
}

variable "TAGS" {
  type = "map"
}

# Fetch AZs in the current region
data "aws_availability_zones" "available" {}

data "aws_region" "current" {}

locals {
  cidr_blocks = {
    vpc = "${var.VPC_CIDR}" # VPC's entire private CIDR block
    igw = "0.0.0.0/0"       # IGW's destination CIDR block
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "${local.cidr_blocks["vpc"]}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}"
		)
	)}"
}

# Create var.AZ_COUNT private subnets, each in a different AZ
resource "aws_subnet" "private" {
  count             = "${var.AZ_COUNT}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-prv${count.index}",
      "Tier", "private"
		)
	)}"
}

# Create var.AZ_COUNT public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = "${var.AZ_COUNT}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.AZ_COUNT + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-pub${count.index}",
      "Tier", "public"
		)
	)}"
}

resource "aws_subnet" "db" {
  count             = "${var.AZ_COUNT}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, var.AZ_COUNT * 2 + count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-db${count.index}",
      "Tier", "db"
		)
	)}"
}

# IGW for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}"
		)
	)}"
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "${local.cidr_blocks["igw"]}"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
resource "aws_eip" "gw" {
  count      = "${var.AZ_COUNT}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-${count.index}"
		)
	)}"
}

resource "aws_nat_gateway" "gw" {
  count         = "${var.AZ_COUNT}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-${count.index}"
		)
	)}"
}

# Create a new route table for the private subnets
# And make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count  = "${var.AZ_COUNT}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block     = "${local.cidr_blocks["igw"]}"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }

  tags = "${merge(
		var.TAGS,
		map(
			"Name","${var.VPC_NAME}-prv${count.index}"
		)
	)}"
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = "${var.AZ_COUNT}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}

# OUTPUT
output "vpc_id" {
  description = "The canonical ID of the VPC instance"
  value       = "${aws_vpc.main.id}"
}

output "vpc_name" {
  description = "The Name tag of the VPC instance"
  value       = "${aws_vpc.main.tags["Name"]}"
}
