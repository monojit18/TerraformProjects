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

resource "azurerm_virtual_network" "vnet" {

    name = "terraform-workshop-vnet"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    address_space = ["173.0.0.0/16"]    
  
}

resource "azurerm_subnet" "storage-subnet" {

    name = "terraform-workshop-storage-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.0.0/24"]
    service_endpoints = ["Microsoft.Storage"]
  
}

resource "azurerm_subnet" "acr-subnet" {

    name = "terraform-workshop-acr-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.1.0/24"]
    service_endpoints = ["Microsoft.ContainerRegistry"]
  
}

resource "azurerm_subnet" "kv-subnet" {

    name = "terraform-workshop-kv-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.2.0/24"]
    service_endpoints = ["Microsoft.KeyVault"]
  
}

# resource "azurerm_role_assignment" "nwroles" {
#   scope                = azurerm_virtual_network.vnet.id
#   role_definition_name = "Network Contributor"
#   principal_id         = "93ae9028-6282-4535-95cf-a1820a49d91a"
  
# }

output "storage-subnet-id" {    
  value = azurerm_subnet.storage-subnet.id
}

output "acr-subnet-ip" {    
  value = azurerm_subnet.acr-subnet.address_prefixes[0]
}

output "acr-subnet-id" {    
  value = azurerm_subnet.acr-subnet.id
}

output "kv-subnet-id" {    
  value = azurerm_subnet.kv-subnet.id
}