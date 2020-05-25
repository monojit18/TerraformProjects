module "network" {
  source = "../Network/"
  
}

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

resource "azurerm_storage_account" "storage" {

    name = "terrwkshpstg"    
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    account_kind = "StorageV2"
    account_tier = "Premium"
    access_tier = "Hot"
    account_replication_type = "LRS"

    # network_rules {

    #     default_action = "Deny"
    #     virtual_network_subnet_ids = ["${module.network.storage-subnet-id}"]
    #     bypass = ["Metrics"]

    # }
  
}
