variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "docker_image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "docker_image" {
  description = "Docker image name without tag"
  type        = string
  default     = "aymen138/akaunting_devops_project"
}
