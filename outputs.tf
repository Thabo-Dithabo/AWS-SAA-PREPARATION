output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (one per AZ)"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "DNS name of the ALB — paste this in a browser to test"
  value       = aws_lb.main.dns_name
}

output "ec2_instance_ids" {
  description = "IDs of the EC2 instances (one per AZ)"
  value       = aws_instance.app[*].id
}

output "ec2_iam_role_arn" {
  description = "ARN of the IAM role attached to EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway — all outbound private subnet traffic comes from this IP"
  value       = aws_eip.nat.public_ip
}
