variable "resource_group_name" {
  description = "The name of the Azure resource group to deploy resources into"
  type        = string
  default     = "test-rg"
}

variable "location" {
  description = "The primary Azure region for resource deployments"
  type        = string
  default     = "centralindia"
}

variable "jumpbox_admin_username" {
  description = "The admin username for the Linux Jumpbox VM"
  type        = string
  default     = "azure"
}

variable "jumpbox_ssh_public_key" {
  description = "The SSH public key for logging into the Linux Jumpbox VM. If not provided, SSH keys will not be configured."
  type        = string
  default     = ""
}

variable "jumpbox_vm_size" {
  description = "The size of the Linux Jumpbox VM"
  type        = string
  default     = "Standard_D2s_v5"
}

# ── Email / SMTP credentials ───────────────────────────────────────────────────
variable "smtp_user" {
  description = "SMTP sender email address (e.g. your Gmail address)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_pass" {
  description = "SMTP password or Gmail App Password for the sender account"
  type        = string
  sensitive   = true
  default     = ""
}

# Trigger comment for Infracost cost analysis test pipeline run v2.
