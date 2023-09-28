data "azurerm_client_config" "current" {
}

data "azuread_service_principal" "this" {
  display_name = "sp-mk-test"
}


resource "azurerm_storage_account" "datalake" {
  name                      = "mk${var.project}sa001"
    
  resource_group_name       = var.resource_group
  location                  = var.region
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  access_tier               = "Hot"
  enable_https_traffic_only = true  
  is_hns_enabled            = true
  
  network_rules {
    default_action = "Allow"
    bypass                     = ["Metrics"]
  } 
  
  identity {
    type = "SystemAssigned"
  }
 
}


resource "azurerm_storage_container" "container" {
  for_each              = toset( ["landing","bronze", "silver", "gold"] )
  name                  = each.key
  storage_account_name  = azurerm_storage_account.datalake.name
 
}

resource "azurerm_storage_data_lake_gen2_filesystem" "sym" {
  name               = "synapse"
  storage_account_id = azurerm_storage_account.datalake.id
}



resource "azurerm_role_assignment" "data_contributor_role" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.this.object_id
}

