variable "enable_website" {
  type        = bool
  description = "Enable S3 static website hosting"
  default     = false
}
variable "environment" {
  type = string
}

variable "policy_action" {
  type = list(string)
  default = null  
  description = "Policy Action"
}

variable "policy_effect" {
  type = string
  default = null  
  description = "Policy Effect"
}

variable "policy_principal" {
  type = string
  default = null  
  description = "Policy Principal"
}

variable "policy_sid" {
  type = string
  default = null  
  description = "Policy Sid"
}