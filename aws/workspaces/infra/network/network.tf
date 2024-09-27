data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.workspace}-network-vpc"
  }
}

# Create var.az_count public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.app.cidr_block, var.vpc_cidr_newbits, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.app.id
  map_public_ip_on_launch = true

  tags = {
    Name                                     = "${var.workspace}-network-public-${substr(data.aws_availability_zones.available.names[count.index], length(data.aws_availability_zones.available.names[count.index]) - 2, 2)}"
    "kubernetes.io/cluster/${var.workspace}" = "shared"
    "kubernetes.io/role/elb"                 = 1
  }
}

# Create var.az_count private subnets, each in a different AZ
resource "aws_subnet" "private" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(aws_vpc.app.cidr_block, var.vpc_cidr_newbits, var.az_count + count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.app.id
  map_public_ip_on_launch = false

  tags = {
    Name                                     = "${var.workspace}-network-private-${substr(data.aws_availability_zones.available.names[count.index], length(data.aws_availability_zones.available.names[count.index]) - 2, 2)}"
    "kubernetes.io/cluster/${var.workspace}" = "shared"
    "kubernetes.io/role/internal-elb"        = 1
  }
}

resource "aws_eip" "gw" {
  count      = var.az_count
  domain     = "vpc"
  depends_on = [aws_internet_gateway.app]

  tags = {
    Name = "${var.workspace}-network-gw-eip"
  }
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.workspace}-network-internet-gw"
  }
}

# Route the public subnet traffic through the IGW
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.app.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app.id
}

# Create a NAT gateway with an Elastic IP for each private subnet to get internet connectivity
resource "aws_nat_gateway" "gw" {
  count         = var.az_count
  subnet_id     = element(aws_subnet.public.*.id, count.index)
  allocation_id = element(aws_eip.gw.*.id, count.index)

  tags = {
    Name = "${var.workspace}-network-nat-gw"
  }
}

# Create a new route table for the private subnets, make it route non-local traffic through the NAT gateway to the internet
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.gw.*.id, count.index)
  }

  tags = {
    Name = "${var.workspace}-network-private-route-table"
  }
}

# Explicitly associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

# VPC endpoint for S3 to bypass NAT Gateway for cost savings
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.app.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = concat(
    aws_route_table.private.*.id,
    [aws_vpc.app.main_route_table_id]
  )

  tags = {
    Name = "${var.workspace}-s3-endpoint"
  }
}
