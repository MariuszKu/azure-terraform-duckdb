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

resource "azurerm_storage_data_lake_gen2_filesystem" "this" {
  name = "commonstorage" 
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "syn" {
  name = "syn" 
  storage_account_id = azurerm_storage_account.datalake.id
}

resource "azurerm_container_registry" "this" {
  name                     = "crmk${var.project}001"
  resource_group_name      = var.resource_group
  location                 = var.region
  sku                      = "Basic"
  admin_enabled            = true
}

resource "null_resource" "build" {

  provisioner "local-exec" {
    command = <<EOT
     cd ..
     docker build -t tree .
     docker tag tree ${azurerm_container_registry.this.name}.azurecr.io/tree
     az acr login --name ${azurerm_container_registry.this.name} 
     docker push ${azurerm_container_registry.this.name}.azurecr.io/tree
    EOT
  }
}


resource "azurerm_container_group" "this" {
  name                = "cg-mk-${var.project}-001"
  location            = var.region
  resource_group_name = var.resource_group
  os_type             = "Linux"
  restart_policy      = "Never"

  image_registry_credential {
    username = azurerm_container_registry.this.admin_username
    password = azurerm_container_registry.this.admin_password 
    server   = azurerm_container_registry.this.login_server
  }

  container {
    name   = "examplecontainer"
    image  = "${azurerm_container_registry.this.login_server}/tree:latest"
    cpu    = "4"
    memory = "8"

    commands = [
      "python", "/app/code/import.py"
    ]

    environment_variables = {
      AZURE_STORAGE_ACCOUNT_KEY  = azurerm_storage_account.datalake.primary_access_key 
      AZURE_STORAGE_ACCOUNT_NAME = azurerm_storage_account.datalake.name
    }
    ports {
      port     = 80
      protocol = "TCP"
    }
  }

  depends_on = [ 
    null_resource.build,
    azurerm_container_registry.this
      ]
   
  tags = {
    environment = "testing"
  }
}


