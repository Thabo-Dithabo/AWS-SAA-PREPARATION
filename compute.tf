# ---------------------------------------------------------------
# COMPUTE — EC2 instances spread across private subnets in 2 AZs
#
# SA Exam concept: placing instances in multiple AZs means
# if one AZ goes down (rare but happens), the other AZ keeps serving traffic.
# The ALB detects the failure and stops routing to the dead AZ automatically.
#
# These instances are in PRIVATE subnets — they have no public IP,
# they cannot be reached from the internet directly.
# All inbound traffic comes through the ALB.
# ---------------------------------------------------------------

resource "aws_instance" "app" {
  count = length(var.availability_zones)

  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # Attach the IAM Instance Profile — gives EC2 its permissions without hardcoded keys
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Disable public IP — these instances should never be directly reachable
  associate_public_ip_address = false

  # user_data runs once on first boot — installs a simple web server for testing
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>App running in AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</h1>" > /var/www/html/index.html
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-${var.availability_zones[count.index]}"
    AZ   = var.availability_zones[count.index]
  })
}

# --- ALB Target Group ---
# The ALB sends traffic to targets (EC2 instances) registered here.
# Health checks determine which targets are healthy and receive traffic.
resource "aws_lb_target_group" "app" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = local.common_tags
}

# Register each EC2 instance with the target group
resource "aws_lb_target_group_attachment" "app" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

# --- Application Load Balancer ---
# Lives in PUBLIC subnets — it is the only thing that faces the internet.
# SA Exam: ALB operates at Layer 7 (HTTP/HTTPS). NLB operates at Layer 4 (TCP/UDP).
# Use ALB when you need path-based routing, host-based routing, or HTTPS termination.
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  # Span across both public subnets (both AZs) for HA
  subnets = aws_subnet.public[*].id

  tags = local.common_tags
}

# --- ALB Listener ---
# Listens on port 80 and forwards to the target group.
# In production you would add a port 443 listener with an ACM certificate.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
