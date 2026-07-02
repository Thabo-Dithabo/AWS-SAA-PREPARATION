# Day 13 — Secure Multi-AZ Web Application

> **AWS Solutions Architect prep project** covering VPC networking, multi-AZ high availability, layered security groups, and IAM least-privilege patterns.

---

## Architecture

```<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/f66b0264-ebc9-4f14-9ab3-1e2bc2bf7bc9" />

```

---

## What This Project Covers

| Topic | Terraform File | SA Exam Domain |
|---|---|---|
| VPC, Subnets, IGW, NAT GW, Route Tables | `networking.tf` | Design Resilient Architectures |
| Multi-AZ EC2 placement | `compute.tf` | Design Resilient Architectures |
| ALB (Layer 7) + Target Groups + Health Checks | `compute.tf` | Design Resilient Architectures |
| Layered Security Groups (defense-in-depth) | `security_groups.tf` | Design Secure Architectures |
| IAM Role + Instance Profile (no hardcoded keys) | `iam.tf` | Design Secure Architectures |
| Least-privilege IAM policies | `iam.tf` | Design Secure Architectures |

---

## Key Concepts Explained

### Regions, AZs, and Edge Locations

| Concept | What it is | How it appears here |
|---|---|---|
| **Region** | Isolated geographic area with its own AWS infrastructure | `us-east-1` in `providers.tf` |
| **Availability Zone** | Separate data center(s) within a Region | `us-east-1a`, `us-east-1b` — one subnet per AZ |
| **Edge Location** | CloudFront CDN cache point, 400+ worldwide | Would sit in front of the ALB |
| **Local Zone** | AWS compute in major cities (e.g. LA) for <10ms latency | Extension of a Region, opt-in |
| **Wavelength** | AWS compute inside 5G carrier networks | Ultra-low latency for mobile apps |
| **Outposts** | AWS rack shipped to your own data center | Hybrid on-premises deployments |

### Why Multi-AZ?

Placing subnets and EC2 instances in **two AZs** means:
- If AZ-a has an outage, AZ-b keeps serving traffic
- The ALB detects failed health checks and stops routing to the affected AZ
- This is **High Availability (HA)** — the core resilience pattern on the SA exam

### Security Group Chain (Defense in Depth)

```
Internet → ALB SG (443 open) → EC2 SG (only from ALB SG) → RDS SG (only from EC2 SG)
```

Each layer only accepts traffic from the layer directly above it. EC2 is invisible to the internet.

### IAM: No Credentials on EC2

EC2 gets an **Instance Profile** (a wrapper around an IAM Role). The instance fetches temporary, auto-rotating credentials from the metadata service at `169.254.169.254`. No access keys are ever stored on the machine.

---

## File Layout

```
day13/
├── providers.tf          # AWS provider + Terraform version
├── backend.tf            # S3 remote state — key: day13/terraform.tfstate
├── variables.tf          # All input variables
├── terraform.tfvars      # Concrete values (gitignored)
├── locals.tf             # name_prefix and common_tags
├── networking.tf         # VPC, subnets, IGW, NAT GW, route tables
├── security_groups.tf    # ALB → EC2 → RDS layered SGs
├── iam.tf                # Role, Instance Profile, least-privilege policies
├── compute.tf            # EC2 (×2 AZs), ALB, Target Group, Listener
└── outputs.tf            # ALB DNS, instance IDs, NAT IP
```

---

## Usage

```powershell
cd day13

# 1. Download provider and configure backend
terraform init

# 2. Check for errors
terraform validate

# 3. Preview changes (no AWS calls that cost money)
terraform plan

# 4. Deploy (costs money — ~$0.05/hr for NAT GW + EC2)
terraform apply

# 5. Test — grab the ALB DNS from outputs and open in browser
# Each refresh may route to a different AZ

# 6. Tear down when done
terraform destroy
```

---

## Cost Warning

| Resource | Approx cost |
|---|---|
| NAT Gateway | ~$0.045/hr + $0.045/GB |
| EC2 t3.micro (×2) | ~$0.0104/hr each |
| ALB | ~$0.008/hr + LCU charges |

**Always run `terraform destroy` when finished.** The NAT Gateway is the biggest cost driver.

---

## AWS Solutions Architect Exam Tips from This Project

- **ALB = Layer 7 (HTTP/HTTPS). NLB = Layer 4 (TCP/UDP).** ALB supports path-based and host-based routing.
- **Security Groups are stateful.** Return traffic is automatic — you only write inbound rules.
- **NACLs are stateless.** You need explicit inbound AND outbound rules. (Not used here — worth adding as an extension.)
- **NAT Gateway vs NAT Instance.** NAT GW is managed, scales automatically, no patching. NAT Instance is self-managed EC2 — cheaper but more work.
- **Instance Profile ≠ IAM Role.** The Profile is the container that lets EC2 use a Role. You attach the Profile to EC2, not the Role directly.
- **Resource ARN scope matters.** Using `"*"` on an IAM policy Resource is a red flag in exam questions and real architectures.
