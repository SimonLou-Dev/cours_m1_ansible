variable "proxmox_api_url" {
  type    = string
}

variable "proxmox_token_id" {
  type    = string
  default = "terraform@pve!terraform"
}

variable "proxmox_token_secret" {
  type      = string
  sensitive = true
}

variable "ssh_user" {
  type    = string
}

variable "ssh_password" {
  type      = string
  sensitive = true
}
