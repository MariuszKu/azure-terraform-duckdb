resource "azurerm_key_vault" "kv" {
  name = "mk-${var.project}-kv003"
  resource_group_name = var.resource_group
  location            = var.region

  sku_name  = "standard"
  tenant_id = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_access_policy" "sp" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.this.object_id
  secret_permissions = ["Get", "List", "Set", "Delete"]
  depends_on = [ azurerm_key_vault.kv]
}

resource "azurerm_key_vault_access_policy" "user" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = ["Get", "List", "Set", "Delete"]
  depends_on = [ azurerm_key_vault.kv]
}


resource "azurerm_key_vault_secret" "client_id" {
  
  name         = "clientid"
  value        = var.client_id
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.user]

}

resource "azurerm_key_vault_secret" "secrete_id" {
  
  name         = "secreteid"
  value        = var.secrete
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault_access_policy.user]
}
