module "network" {
  source = "../Network/"
  
}

provider "azurerm" {

    version = "=2.11.0"
    features {}   
    subscription_id = "<subscription_id>"       

}

resource "azurerm_resource_group" "rg" {

    name = "terraform-workshop-rg"    
    location = "eastus"    
    tags = {

        Primary_Owner = "monojit.datta@outlook.com"
        Purpose = "workshop"

    }
}

resource "azurerm_key_vault" "kv" {

    name = "terraform-workshop-kv"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    tenant_id = "<tenant_id>"
    enabled_for_disk_encryption = true
    enabled_for_template_deployment = true
    sku_name = "premium"
    
    # network_acls {

    #     bypass = "AzureServices"
    #     default_action = "Deny"
    #     virtual_network_subnet_ids = ["${module.network.kv-subnet-id}"]

    # } 
}

resource "azurerm_key_vault_access_policy" "kvpolicy" {
  
    key_vault_id = azurerm_key_vault.kv.id
    tenant_id = "<tenant_id>"
    object_id = "<object_id>"
    secret_permissions = [
        "get", "list", "delete", "set"
    ]

}
