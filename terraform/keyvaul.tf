
resource "azurerm_key_vault" "kv" {
  name = "kv-mk-${var.project}-001"
  resource_group_name = var.resource_group
  location            = var.region

  sku_name  = "standard"
  tenant_id = data.azurerm_client_config.current.tenant_id
}



# The deployment SP should have set permission to write the 
# secrets. ensure that the access policy is defined for this
resource "azurerm_key_vault_access_policy" "kv_acp_deployer" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.this.object_id

  secret_permissions = ["get", "list", "set", "delete", "restore"]
}

# Store the storage account SAS key, this will be used 
# to copy the project files into the docker image
#
resource "azurerm_key_vault_secret" "client_id" {
  depends_on   = [azurerm_key_vault_access_policy.kv_acp_deployer]
  name         = "clientid"
  value        = var.client_id
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "secrete_id" {
  depends_on   = [azurerm_key_vault_access_policy.kv_acp_deployer]
  name         = "secreteid"
  value        = var.secrete
  key_vault_id = azurerm_key_vault.kv.id
}
