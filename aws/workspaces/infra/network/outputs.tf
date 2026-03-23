output "vpc" {
  value = aws_vpc.app
}

output "public_subnet" {
  value = aws_subnet.public
}

output "private_subnet" {
  value = aws_subnet.private
}

output "availability_zones" {
  value = data.aws_availability_zones.available
}

output "gateway_ip" {
  value = aws_eip.gw.*.public_ip
}

output "private_route_table" {
  value = aws_route_table.private
}
