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
