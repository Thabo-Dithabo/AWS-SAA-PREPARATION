# ---------------------------------------------------------------
# IAM — Instance Role with Least Privilege
#
# SA Exam concept: NEVER put AWS credentials (access keys) on EC2.
# Instead, attach an IAM Role via an Instance Profile.
# EC2 fetches temporary, auto-rotating credentials from the
# instance metadata service (IMDS) at 169.254.169.254.
#
# Least Privilege = grant only the exact permissions the app needs.
# Here: read from a specific S3 bucket + write logs to CloudWatch.
# ---------------------------------------------------------------

# --- Trust Policy ---
# Tells AWS: "EC2 is allowed to assume this role."
# Without this, the role exists but nothing can use it.
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# --- IAM Role ---
resource "aws_iam_role" "ec2_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = local.common_tags
}

# --- Permission Policy: S3 read-only on a specific bucket ---
# Note: using a resource ARN pattern, not "*"
# SA Exam: wildcard (*) on Resource is a common exam trap — it violates least privilege.
data "aws_iam_policy_document" "s3_read" {
  statement {
    sid    = "AllowS3ReadOnAppBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.name_prefix}-app-assets",
      "arn:aws:s3:::${local.name_prefix}-app-assets/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${local.name_prefix}-s3-read-policy"
  description = "Allow EC2 to read from app assets bucket only"
  policy      = data.aws_iam_policy_document.s3_read.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# --- Permission Policy: CloudWatch Logs ---
# Allows the app to write logs to CloudWatch without needing credentials.
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# --- Instance Profile ---
# The "wrapper" that lets you attach an IAM Role to an EC2 instance.
# SA Exam: you attach an Instance Profile to EC2, not the Role directly.
# Under the hood, a Profile is just a container for one Role.
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.common_tags
}
