locals {
  name_prefix = "${var.environment}-day13"

  common_tags = {
    Environment = var.environment
    Project     = "day13-secure-multi-az"
    ManagedBy   = "terraform"
  }
}
