resource "azurerm_container_registry" "this" {
  count                = var.acr_enable ? 1 : 0
  name                     = "crmk${var.project}001"
  resource_group_name      = var.resource_group
  location                 = var.region
  sku                      = "Basic"
  admin_enabled            = true
}

resource "null_resource" "build" {
  count                = var.acr_enable ? 1 : 0
  depends_on = [azurerm_container_registry.this]
  provisioner "local-exec" {
    command = <<EOT
     cd ..
     docker build -t tree .
     docker tag tree ${azurerm_container_registry.this[0].name}.azurecr.io/tree
     az acr login --name ${azurerm_container_registry.this[0].name} 
     docker push ${azurerm_container_registry.this[0].name}.azurecr.io/tree
    EOT
  }
}


resource "azurerm_container_group" "this" {
  count                = var.acr_enable ? 1 : 0
  name                = "cg-mk-${var.project}-001"
  location            = var.region
  resource_group_name = var.resource_group
  os_type             = "Linux"
  restart_policy      = "Never"

  image_registry_credential {
    username = azurerm_container_registry.this[0].admin_username
    password = azurerm_container_registry.this[0].admin_password 
    server   = azurerm_container_registry.this[0].login_server
  }

  container {
    name   = "examplecontainer"
    image  = "${azurerm_container_registry.this[0].login_server}/tree:latest"
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
