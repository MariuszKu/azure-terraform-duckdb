resource "random_password" "sql_administrator_login_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 1

}

resource "azurerm_key_vault_secret" "sql_administrator_login" {
  name            = "synapseSQLpass"
  value           = random_password.sql_administrator_login_password.result
  key_vault_id    = azurerm_key_vault.kv.id
  content_type    = "string"
  expiration_date = "2111-12-31T00:00:00Z"

  depends_on = [
    azurerm_key_vault.kv,
    azurerm_key_vault_access_policy.user
  ]
}




resource "azurerm_synapse_workspace" "this" {
  name = "mk${var.project}syn001"
  resource_group_name                  = var.resource_group
  location                             = var.region
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.sym.id
  sql_administrator_login              = "mariusz"
  sql_administrator_login_password     = azurerm_key_vault_secret.sql_administrator_login.value
  #managed_virtual_network_enabled      = false
  #public_network_access_enabled        = true
  #data_exfiltration_protection_enabled = true

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_storage_account.datalake,
    azurerm_key_vault_secret.sql_administrator_login
    ]

}

resource "azurerm_key_vault_access_policy" "kv_acp_deployer" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_synapse_workspace.this.identity[0].principal_id

  secret_permissions = ["Get", "List", "Set", "Delete"]
}
 