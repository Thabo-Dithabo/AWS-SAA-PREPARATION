# ---------------------------------------------------------------
# SECURITY GROUPS — Layered / Defense-in-Depth model
#
# SA Exam concept: Security Groups are STATEFUL firewalls.
# Stateful means: if you allow inbound traffic on port 80,
# the return traffic is automatically allowed — you don't need
# an explicit outbound rule for the response.
#
# The layered model here:
#   Internet → ALB SG (443 open) → EC2 SG (only from ALB) → RDS SG (only from EC2)
#
# This means even if someone bypasses CloudFront, they still
# can't reach EC2 directly, and EC2 can never reach RDS directly
# unless the app does it through the allowed port.
# ---------------------------------------------------------------

# --- ALB Security Group ---
# Accepts HTTPS traffic from the public internet
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-sg-alb"
  description = "Allow HTTPS inbound from internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-alb" })
}

# --- EC2 Security Group ---
# ONLY accepts traffic from the ALB security group — NOT the internet directly.
# This is the key security win: EC2 is invisible to the public internet.
resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-sg-ec2"
  description = "Allow inbound only from ALB security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (for package installs, AWS API calls)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-ec2" })
}

# --- RDS Security Group ---
# ONLY accepts Postgres traffic from the EC2 security group.
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-sg-rds"
  description = "Allow Postgres inbound only from EC2 security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from EC2 only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # RDS does not need outbound — it only responds to requests
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-sg-rds" })
}
