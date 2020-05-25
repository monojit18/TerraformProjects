provider "azurerm" {

    version = "=2.11.0"
    features {}
    subscription_id = "<subscription_id>"
    tenant_id = "<tenant_id>"

}

resource "azurerm_resource_group" "rg" {

    name = "terraform-workshop-rg"
    location = "eastus"
    tags = {

        Primary_Owner = "monojit.datta@outlook.com"
        Purpose = "workshop"

    }
}

data "azurerm_key_vault" "existing" {

    name = "terraform-workshop-kv"
    resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_key_vault_secret" "existing" {

    name = "stgpkey"
    key_vault_id = data.azurerm_key_vault.existing.id
}

variable "env" {
  
    type = list(string)
    default = ["DEV", "QA"]
    
}

resource "azurerm_app_service_plan" "appplan" {

    name = "webapp-standard-plan"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    sku {

        tier = "Standard"
        size = "S1"

    }
}

resource "azurerm_app_service" "appservice" {
  
    name = "terraform-app-service"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }

    storage_account {

        name = "PrimaryKey"
        access_key = data.azurerm_key_vault_secret.existing.key_vault_id
        type = "AzureBlob"
        account_name = "terrwkshpstg"
        share_name = "webappcntr"

    }
}

resource "azurerm_app_service_slot" "devslot" {
  
    name = join("", [azurerm_app_service.appservice.name, "-", var.env[0], "-slot"])
    app_service_name = azurerm_app_service.appservice.name
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }
}

resource "azurerm_app_service_slot" "qaslot" {
  
    name = join("", [azurerm_app_service.appservice.name, "-", var.env[1], "-slot"])
    app_service_name = azurerm_app_service.appservice.name
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }
}



