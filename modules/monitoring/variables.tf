variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region for the resources"
  type        = string
}

variable "aks_cluster_id" {
  description = "The resource ID of the AKS cluster"
  type        = string
}

variable "grafana_admin_object_id" {
  description = "The Object ID of the user to be assigned Grafana Admin rights in the dashboard"
  type        = string
  default     = "d9cbf12f-3add-4139-8bc6-7e058e9d7870"
}
