variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "juice-shop"
}

variable "AWS_ROLE_TO_ASSUME" {
  description = "ARN of AWS role to assume (optional for OIDC workflows)"
  type        = string
  default     = ""
}
