
data "azurerm_client_config" "current" {}

data "azurerm_managed_api" "this" {
 name     = "keyvault"
 location = var.rg_location
}

resource "azurerm_resource_group" "rg" {
  location = var.rg_location
  name     = var.rg_name
  tags = {
    createby = "eirc"
  }
}

resource "azurerm_key_vault" "kv" {
  name                = var.kv_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

    access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "List",
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
  tags = {
    createby = "eric"
  }
  depends_on = [ azurerm_resource_group.rg ]
}

resource "azurerm_key_vault_secret" "secret1" {
  name         = "AppID"
  value        = "szechuan_v2"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [ azurerm_key_vault.kv ]
}

resource "azurerm_user_assigned_identity" "uai" {
  location            = var.rg_location
  name                = "uai-la-read-keyvault"
  resource_group_name = var.rg_name
  tags = {
    createby = "eirc"
  }
  depends_on = [
    azurerm_resource_group.rg,
  ]
}

resource "azurerm_key_vault_access_policy" "uai_access" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.uai.principal_id

  secret_permissions = [
    "Get", "List",
  ]

  depends_on = [ 
    azurerm_user_assigned_identity.uai
   ]
}

resource "azapi_resource" "kv" {
  type      = "Microsoft.Web/connections@2018-07-01-preview"
  name      = "keyvault"
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id

  schema_validation_enabled = false

  body = jsonencode({
    "properties": {
      "api": {
        "id": "${data.azurerm_managed_api.this.id}"
      },
      "parameterValueSet": {
        "name": "oauthMI",
        "values": {
          "vaultName": {
            "value": "${azurerm_key_vault.kv.name}"
          }
        }
      },
      "displayName": "keyvault"
    }
  })

  depends_on = [ 
    azurerm_user_assigned_identity.uai,
    azurerm_key_vault_access_policy.uai_access
   ]
}


resource "azurerm_logic_app_workflow" "workflow1" {
  location = var.rg_location
  name     = "la-workflow1"
  parameters = {
    "$connections" = "{\"keyvault\":{\"connectionId\":\"${azapi_resource.kv.id}\",\"connectionName\":\"keyvault\",\"connectionProperties\":{\"authentication\":{\"identity\":\"${azurerm_user_assigned_identity.uai.id}\",\"type\":\"ManagedServiceIdentity\"}},\"id\":\"${data.azurerm_managed_api.this.id}\"}}"
  }
  resource_group_name = var.rg_name
  workflow_parameters = {
    "$connections" = "{\"defaultValue\":{},\"type\":\"Object\"}"
  }
  identity {
    identity_ids = [azurerm_user_assigned_identity.uai.id]
    type         = "UserAssigned"
  }
  depends_on = [
    azurerm_user_assigned_identity.uai,
    azapi_resource.kv
  ]
}

resource "azurerm_logic_app_trigger_custom" "trigger" {
  name         = "Recurrence"
  logic_app_id = azurerm_logic_app_workflow.workflow1.id
  body         = file("actions/trigger.json")

  depends_on = [ 
    azurerm_logic_app_workflow.workflow1
   ]

}

resource "azurerm_logic_app_action_custom" "getappid" {
  name         = "GetAppID"
  logic_app_id = azurerm_logic_app_workflow.workflow1.id
  #body         = file("actions/step100-get-appid.json")
  body         = data.template_file.init.rendered

  depends_on = [ 
    azurerm_logic_app_trigger_custom.trigger
   ]
}

data "template_file" "init" {
  template = file("actions/step100-get-appid-json.tpl")
  vars = {
    varConnType = "${var.api_type}",
    varAppId    = "${var.secret_app_id}"
  }
}


