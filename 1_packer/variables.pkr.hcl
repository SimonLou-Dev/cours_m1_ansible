variable "proxmox_api_url" {
  type    = string
  default = "https://172.16.0.111:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type    = string
  default = "packer@pve!packer"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "root_password" {
  type    = string
  default = "password"
}

variable "custom_user" {
  type    = string
  default = "esgi"
}

variable "custom_password" {
  type    = string
  default = "esgi"
}
