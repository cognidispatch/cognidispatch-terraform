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
  description = "The Object ID of the user/service principal to be assigned Grafana Admin rights. Defaults to the deploying identity."
  type        = string
  default     = ""
}
