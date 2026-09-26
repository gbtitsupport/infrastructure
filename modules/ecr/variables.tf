variable "repo_name" {
  type = string
}

variable "untagged_expiry_days" {
  type    = number
  default = 7
}

variable "tag_rules" {
  description = "One lifecycle rule per tag prefix"
  type = list(object({
    prefix = string
    keep   = number
  }))
  default = []
}