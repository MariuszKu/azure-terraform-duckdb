resource "azurerm_data_factory" "adf_transform" {
  resource_group_name = var.resource_group
  location            = var.region
  name = "mk-${var.project}-adf01"

  identity {
    type = "SystemAssigned"
  }
}

# ADF should have access to kv to read the service principal
resource "azurerm_key_vault_access_policy" "kv_adf_transform" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.adf_transform.identity[0].principal_id

  secret_permissions = ["get", "list"]
}

resource "azurerm_data_factory_linked_service_key_vault" "adf_kv_ls" {
  name                = "ls_kv"
  resource_group_name = var.resource_group
  data_factory_id   = azurerm_data_factory.adf_transform.id
  key_vault_id        = azurerm_key_vault.kv.id
  description         = " Used for retrieving sp information. "
}

resource "azurerm_data_factory_linked_service_azure_databricks" "at_linked" {
  name                = "ADBLinkedServiceViaAccessToken"
  resource_group_name = var.resource_group
  data_factory_id     = azurerm_data_factory.adf_transform.id
  description         = "ADB Linked Service via Access Token"
  existing_cluster_id = databricks_cluster.this.id

  access_token = azurerm_key_vault_secret.dbpattoken.value
  adb_domain   = "https://${azurerm_databricks_workspace.this.workspace_url}"
}

resource "azurerm_data_factory_pipeline" "databricks_pipe" {
  name                = "databricks_pipeline"
  resource_group_name = var.resource_group
  data_factory_id   = azurerm_data_factory.adf_transform.id
  description         = "Databricks"
  activities_json = <<EOF_JSON
        [
            {
                "name": "Transform_Notebook",
                "type": "DatabricksNotebook",
                "dependsOn": [],
                "policy": {
                    "timeout": "0.12:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "notebookPath": "/Shared/test/test"
                },
                "linkedServiceName": {
                    "referenceName": "AzureDatabricks1",
                    "type": "ADBLinkedServiceViaAccessToken"
                }
            }
        ]

  EOF_JSON  

}


resource "azurerm_data_factory_pipeline" "acg_start_pipe" {
  name                = "acg_start_and_wait_pipe"
  resource_group_name = var.resource_group
  data_factory_id   = azurerm_data_factory.adf_transform.id
  description         = " A common pipeline that can be called to trigger the dbt ACG and wait for its completion."

  parameters = {
    #Azure container group, which hosts the dbt container
    "acg_name" = azurerm_container_group.this.name

    # A rough estimate time for the data pipeline is expected to finish.
    # specify in seconds
    "sleep_time_potential_completion" = 300

    # Azure tenant id
    "az_tenant_id" = data.azurerm_client_config.current.tenant_id
    # Azure subscription id
    "az_sub_id" = data.azurerm_client_config.current.subscription_id
    # The resource group which host the ACG
    "acg_rg" = var.resource_group
  }

  variables = {
    "status" = ""
  }

  activities_json = <<EOF_JSON

        [
            {
                "name": "kv_get_acr-sp",
                "description": "Retrieves the service principal id, used for starting the ACG.",
                "type": "WebActivity",
                "dependsOn": [],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "url": "${azurerm_key_vault.kv.vault_uri}secrets/clientid/?api-version=7.0",
                    "method": "GET",
                    "authentication": {
                        "type": "MSI",
                        "resource": "https://vault.azure.net"
                    }
                }
            },
            {
                "name": "kv_get_acr-sp-scrt",
                "description": "Retrieves the service principal secret, used for starting the ACG.",
                "type": "WebActivity",
                "dependsOn": [],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "url": "${azurerm_key_vault.kv.vault_uri}secrets/secreteid/?api-version=7.0",
                    "method": "GET",
                    "authentication": {
                        "type": "MSI",
                        "resource": "https://vault.azure.net"
                    }
                }
            },
            {
                "name": "get_access_token",
                "description": "Get the access token, so that we can use this in subsequent calls.",
                "type": "WebActivity",
                "dependsOn": [
                    {
                        "activity": "kv_get_acr-sp",
                        "dependencyConditions": [
                            "Succeeded"
                        ]
                    },
                    {
                        "activity": "kv_get_acr-sp-scrt",
                        "dependencyConditions": [
                            "Succeeded"
                        ]
                    }
                ],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "url": {
                        "value": "@concat('https://login.microsoftonline.com/', pipeline().parameters.az_tenant_id,\n'/oauth2/token')",
                        "type": "Expression"
                    },
                    "method": "POST",
                    "headers": {
                        "Content-Type": "application/x-www-form-urlencoded"
                    },
                    "body": {
                        "value": "@concat(\n'grant_type=client_credentials&client_id=',\nactivity('kv_get_acr-sp').output.value\n,'&client_secret=',\nactivity('kv_get_acr-sp-scrt').output.value\n,'&resource=https%3A%2F%2Fmanagement.azure.com%2F'\n)",
                        "type": "Expression"
                    }
                }
            },
            {
                "name": "start_acg",
                "description": "Start the specified acg instance (parameter).",
                "type": "WebActivity",
                "dependsOn": [
                    {
                        "activity": "get_access_token",
                        "dependencyConditions": [
                            "Succeeded"
                        ]
                    }
                ],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "url": {
                        "value": "@concat(\n'https://management.azure.com/subscriptions/',\npipeline().parameters.az_sub_id\n,'/resourceGroups/',\npipeline().parameters.acg_rg\n,'/providers/Microsoft.ContainerInstance/containerGroups/',\npipeline().parameters.acg_name\n,'/start?api-version=2019-12-01'\n)",
                        "type": "Expression"
                    },
                    "method": "POST",
                    "headers": {
                        "Authorization": {
                            "value": "@concat(\n 'Bearer ',\n  activity('get_access_token').output.access_token\n)",
                            "type": "Expression"
                        }
                    },
                    "body": {
                        "value": "{}",
                        "type": "Expression"
                    }
                }
            },
            {
                "name": "get_acg_status",
                "description": "Get the status of the ACG to confirm if it finished or still running",
                "type": "WebActivity",
                "dependsOn": [
                    {
                        "activity": "Until_finish",
                        "dependencyConditions": [
                            "Succeeded"
                        ]
                    }
                ],
                "policy": {
                    "timeout": "7.00:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "url": {
                        "value": "@concat(\n'https://management.azure.com/subscriptions/',\npipeline().parameters.az_sub_id\n,'/resourceGroups/',\npipeline().parameters.acg_rg\n,'/providers/Microsoft.ContainerInstance/containerGroups/',\npipeline().parameters.acg_name\n,'?api-version=2019-12-01'\n)",
                        "type": "Expression"
                    },
                    "method": "GET",
                    "headers": {
                        "Authorization": {
                            "value": "@concat(\n 'Bearer ',\n  activity('get_access_token').output.access_token\n)",
                            "type": "Expression"
                        }
                    }
                }
            },
            {
                "name": "Until_finish",
                "type": "Until",
                "dependsOn": [
                    {
                        "activity": "start_acg",
                        "dependencyConditions": [
                            "Succeeded"
                        ]
                    }
                ],
                "userProperties": [],
                "typeProperties": {
                    "expression": {
                        "value": "@or(\n    or(\n    equals(variables('status'),'Succeeded'), \n    equals(variables('status'),'Stopped')\n    ),\n    equals(variables('status'),'Failed')\n    )",
                        "type": "Expression"
                    },
                    "activities": [
                        {
                            "name": "Wait1",
                            "type": "Wait",
                            "dependsOn": [],
                            "userProperties": [],
                            "typeProperties": {
                                "waitTimeInSeconds": 60
                            }
                        },
                        {
                            "name": "get_acg_status_work",
                            "description": "Get the status of the ACG to confirm if it finished or still running",
                            "type": "WebActivity",
                            "dependsOn": [
                                {
                                    "activity": "Wait1",
                                    "dependencyConditions": [
                                        "Succeeded"
                                    ]
                                }
                            ],
                            "policy": {
                                "timeout": "7.00:00:00",
                                "retry": 0,
                                "retryIntervalInSeconds": 30,
                                "secureOutput": false,
                                "secureInput": false
                            },
                            "userProperties": [],
                            "typeProperties": {
                                "url": {
                                    "value": "@concat(\n'https://management.azure.com/subscriptions/',\npipeline().parameters.az_sub_id\n,'/resourceGroups/',\npipeline().parameters.acg_rg\n,'/providers/Microsoft.ContainerInstance/containerGroups/',\npipeline().parameters.acg_name\n,'?api-version=2019-12-01'\n)",
                                    "type": "Expression"
                                },
                                "method": "GET",
                                "headers": {
                                    "Authorization": {
                                        "value": "@concat(\n 'Bearer ',\n  activity('get_access_token').output.access_token\n)",
                                        "type": "Expression"
                                    }
                                }
                            }
                        },
                        {
                            "name": "Set status",
                            "type": "SetVariable",
                            "dependsOn": [
                                {
                                    "activity": "get_acg_status_work",
                                    "dependencyConditions": [
                                        "Succeeded"
                                    ]
                                }
                            ],
                            "policy": {
                                "secureOutput": false,
                                "secureInput": false
                            },
                            "userProperties": [],
                            "typeProperties": {
                                "variableName": "status",
                                "value": {
                                    "value": "@activity('get_acg_status_work').output.properties.provisioningState",
                                    "type": "Expression"
                                }
                            }
                        }
                    ],
                    "timeout": "0.12:00:00"
                }
            }
        ]

EOF_JSON

}
