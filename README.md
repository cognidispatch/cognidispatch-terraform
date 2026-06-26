# CogniDispatch Infrastructure Management (Terraform)

This repository contains the complete **Infrastructure as Code (IaC)** code using Terraform to deploy the secure, private **Hub-and-Spoke** network topology on Microsoft Azure for the **CogniDispatch** platform.

## 📐 Architecture Overview
The infrastructure isolates the Kubernetes workload inside a private Virtual Network using Azure Private Link, Network Security Groups, and a dual-gateway pattern (Azure WAF App Gateway and internal Kubernetes API Gateway):

1.  **Hub VNet (`vnet-cogni-hub`)**: Houses the administrative ingress subnets and Azure Bastion Host.
2.  **Spoke VNet (`vnet-cogni-spoke`)**: Contains subnets for:
    *   **AKS (`snet-aks`)**: HARDENED private cluster running Cilium Overlay networking.
    *   **WAF Ingress (`snet-appgw`)**: Azure Application Gateway WAF_v2.
    *   **Private Endpoints (`snet-private-ep`)**: NIC connections for Cosmos DB, Key Vault, Container Registry, Azure OpenAI, and Speech APIs.
    *   **Management (`snet-mgmt`)**: Private Linux Jumpbox VM.

---

## 📁 Repository Modules
The setup is organized into modular Terraform segments:

```
├── modules/
│   ├── network/          # VNets, subnets, peering, NSGs, and Private DNS Zones
│   ├── aks/              # Private AKS cluster, node pools, overlay networking
│   ├── app_gateway/      # Azure Application Gateway (WAF v2) & policies
│   ├── registry/         # Azure Container Registry (Premium SKU)
│   ├── data/             # Azure Key Vault and Cosmos DB (MongoDB API)
│   ├── cognitive/        # Azure OpenAI and Speech Cognitive Services
│   ├── monitoring/       # Prometheus Workspace and Azure Managed Grafana
│   ├── security/         # User-Assigned Identities and OIDC Federated Credentials
│   └── bastion/          # Bastion Host and Management Linux Jumpbox VM
├── main.tf               # Root module linking all sub-modules
├── variables.tf          # Root variables definitions
├── outputs.tf            # Output definitions (endpoints, IDs)
├── providers.tf          # Azurerm, Azuread, and Random provider details
└── setup_state.ps1       # Script to initialize Azure remote state container
```

---

## ⚙️ Variables and Parameters

### 1. Variables (`variables.tf`)
The root module configures the following main variables:

| Name | Description | Default |
| :--- | :--- | :--- |
| `resource_group_name` | Resource Group where all resources are provisioned | `"test-rg"` |
| `location` | Main Azure region for network and core compute | `"centralindia"` |
| `jumpbox_admin_username` | Default SSH admin user for the Jumpbox VM | `"azure"` |
| `jumpbox_ssh_public_key` | SSH key to authorize. If empty, a key pair is generated automatically | `""` |
| `smtp_user` | Sender email address for SMTP mail notifications (Sensitive) | `""` |
| `smtp_pass` | Password/App key for the SMTP server (Sensitive) | `""` |

### 2. Output Configurations (`outputs.tf`)
Upon a successful apply, Terraform outputs resource endpoints:
*   `app_gateway_public_ip`: Public entry-point IP of the application.
*   `aks_cluster_name`: Private AKS cluster identifier.
*   `acr_login_server`: Registry domain to push Docker images.
*   `key_vault_uri`: Key Vault URL.
*   `grafana_endpoint`: Managed Grafana monitoring portal.
*   `jumpbox_private_ip`: Internal management endpoint.

---

## 🛠️ How to Deploy

### 1. Prerequisite Tools
*   Azure CLI (`az`)
*   Terraform CLI (`terraform` v1.5+)

### 2. Configure Azure Authenticated Session
Ensure you are logged into Azure and targeting the correct subscription:
```bash
az login
az account set --subscription "your-subscription-id"
```

### 3. Initialize Remote State Backend
Before running Terraform, run the PowerShell helper script to provision a secure Azure storage account to hold the Terraform state files:
```powershell
./setup_state.ps1
```

### 4. Apply Terraform Configurations
Run the standard deployment loop:
```bash
# Initialize providers and download modules
terraform init

# Plan and verify changes
terraform plan -out=tfplan

# Apply changes to Azure (requires approval)
terraform apply tfplan
```

### 5. Accessing the Private AKS Cluster
Since the AKS API server is private, you must connect via the Bastion Jumpbox:
1.  Connect to the Jumpbox VM using Azure Bastion from the Azure Portal.
2.  Run the deployment helper inside the Jumpbox VM to set up `kubectl` context:
    ```bash
    az aks get-credentials --resource-group test-rg --name cogni-aks --admin
    ```
