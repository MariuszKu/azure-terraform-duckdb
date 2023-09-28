terraform {
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm =  {
      source  = "hashicorp/azurerm"
      version = "3.37.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    databricks = {
      source  = "databricks/databricks"
      #version = "~> 0.5"
    }
  }
}

provider "azuread"{}

provider "azurerm" {
  features {}
}

provider "databricks" {
  azure_workspace_resource_id = azurerm_databricks_workspace.this.id
  host  = azurerm_databricks_workspace.this.workspace_url
  azure_client_id             = var.client_id
  azure_client_secret         = var.secrete
  azure_tenant_id             = data.azurerm_client_config.current.tenant_id
}