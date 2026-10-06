variable "ami_image" {
  description = "ami image"
  type        = string
  default     = null
}

variable "instance_type" {
  description = " Type of EC2 instance"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "A mapping of additional resource tags"
  default     = {}
}

variable "instance_profile_name" {
  description = "Name of an existing IAM instance profile to attach"
  type        = string
  default     = "web-ec2"
}

variable "environment" {
  description = "Used in the App tag that the deploy script targets"
  type        = string
}