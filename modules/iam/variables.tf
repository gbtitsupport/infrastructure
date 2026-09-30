variable "name_prefix" {
  description = "Prefix for the role and instance profile names"
  type        = string
}

variable "attach_ssm" {
  description = "Attach AmazonSSMManagedInstanceCore (needed for SSM Run Command / Session Manager)"
  type        = bool
  default     = false
}

variable "attach_ecr_pull" {
  description = "Attach AmazonEC2ContainerRegistryPullOnly (pull images from ECR)"
  type        = bool
  default     = false
}

variable "additional_policy_arns" {
  description = "Extra managed policies to attach. Map of a static key to a policy ARN."
  type        = map(string)
  default     = {}
}

variable "inline_policy_json" {
  description = "Optional inline policy (JSON) for permissions not covered by managed policies"
  type        = string
  default     = null
}

variable "create_instance_profile" {
  description = "Create an instance profile so the role can be attached to EC2"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}