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

resource "azurerm_container_registry" "acr" {

    name = "trwkshpacr"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    sku = "Premium"
    admin_enabled = "false"
    network_rule_set {

        default_action = "Deny"
        ip_rule {

            action = "Allow"
            ip_range = module.network.acr-subnet-ip
        }
    }
}