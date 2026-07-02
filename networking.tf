# ---------------------------------------------------------------
# NETWORKING — VPC, Subnets, IGW, NAT Gateway, Route Tables
#
# SA Exam concept: A VPC spans a whole Region.
# Subnets live inside ONE AZ — you place subnets in multiple AZs
# to achieve High Availability (HA).
#
# Public subnet  = has a route to the Internet Gateway (IGW)
# Private subnet = routes outbound traffic through a NAT Gateway
#                  so EC2 can reach the internet but is NOT reachable from it.
# ---------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

# --- Public Subnets (one per AZ) ---
# count = 2 creates two subnets; count.index selects the right CIDR and AZ from the lists.
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Instances in public subnets get a public IP automatically (needed for ALB)
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  })
}

# --- Private Subnets (one per AZ) ---
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

# --- Internet Gateway ---
# Attaches the VPC to the internet. Without this, nothing in the VPC can reach the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

# --- Elastic IP for NAT Gateway ---
# NAT Gateway needs a static public IP so that private subnet traffic appears
# to come from one known address when leaving the VPC.
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat-eip" })
}

# --- NAT Gateway ---
# Lives in a PUBLIC subnet. Private subnet instances route outbound traffic here.
# SA Exam: NAT Gateway is managed by AWS (no patching), scales automatically.
# It is NOT free — $0.045/hr + data transfer costs. Always destroy when not needed.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-nat" })

  depends_on = [aws_internet_gateway.main]
}

# --- Route Table: Public ---
# Routes all internet-bound traffic (0.0.0.0/0) through the IGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt-public" })
}

# Associate both public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route Table: Private ---
# Routes internet-bound traffic through the NAT Gateway (not the IGW directly).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-rt-private" })
}

# Associate both private subnets with the private route table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
