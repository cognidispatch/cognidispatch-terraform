output "bastion_host_name" {
  description = "The name of the Azure Bastion Host"
  value       = azurerm_bastion_host.bastion.name
}

output "jumpbox_private_ip" {
  description = "The private IP address of the Linux Jumpbox VM"
  value       = azurerm_linux_virtual_machine.jumpbox.private_ip_address
}

output "jumpbox_private_key" {
  description = "The SSH private key for the Linux Jumpbox VM"
  value       = var.ssh_public_key == "" ? tls_private_key.jumpbox_key[0].private_key_pem : null
  sensitive   = true
}

output "jumpbox_principal_id" {
  description = "The principal ID of the Jumpbox VM's User-Assigned Managed Identity"
  value       = azurerm_user_assigned_identity.jumpbox_identity.principal_id
}


