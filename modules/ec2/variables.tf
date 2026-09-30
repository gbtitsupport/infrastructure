variable "ami_image" {
  description = "ami image"
  type        = string
  default     = null
}

variable "instance_type" {
  description = " Type of EC2 instance"
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "A mapping of additional resource tags"
  default     = {}
}
