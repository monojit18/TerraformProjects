

# Codify Infrastructure on Azure - terraform

Let us see how to deploy a **Storage** resource on Azure. <br>But before delving into this, let us have a look at the high level view of the terraform components:

![](./Assets/Terraform-basic.png)

## Storage

### Providers

```
provider "azurerm" {

    version = "=2.11.0"
    features {}
    subscription_id = "<subscription_id>"
    tenant_id = "<tenant_id>"

}
```

This sets teh Azure Provider version and other details like subsrion_id and tenant_id

*terrqform init* command will act uppn thsi first qnd downalods the necessary plugin of desired version and its dependencies.

form init* command will act uppn thsi first qnd downalods the necessary plugin of desired version and its dependencies.

### Resource Group

```
resource "azurerm_resource_group" "rg" {

    name = "terraform-workshop-rg"
    location = "eastus"
    tags = { // (Optional)

        Primary_Owner = "<email_id>"
        Purpose = "workshop"

    }
}
```

*azurerm_resource_group* is the resource Type and *rg* is the name of the resource in terraform context i.e. the name by which terraform internally refers to it. This also brings a degree of object orientation or structured approach while accessing the resource and its properties e.g. *azurerm_resource_group.rg.localtion*.

Terraform follows idempotent approach i.e. if the resource does not exist then it will be created or else it will be either updated or ignored, based on the current state and desired state

### Storage Account

```
resource "azurerm_storage_account" "storage" {

    name = "terrwkshpstg"    
    resource_group_name = azurerm_resource_group.rg.name // Ref1
    location = azurerm_resource_group.rg.location // Ref2
    account_kind = "StorageV2"
    account_tier = "Premium"
    access_tier = "Hot"
    account_replication_type = "LRS"
}
```

This is quite self-explanatory so won't spend much time on this! Note the *Ref1* and *Ref2* comments - these are values coming from previous block of *azurerm_resource_group*

### Steps

- terraform init
- terraform plan -out="storage-plan"
- terraform apply "storage-plan"

So, that is it...with the simple steps you have your first Storage account using terraform is deployed and ready to be used! <br>Now obviously there are plenty of more parameters...to configure a Storage account creation; please refer here: https://www.terraform.io/docs/providers/azurerm/r/storage_account.html 

### Modules and Dependencies

As usual, as we completed the first step, next endeavour is to make the Storage resource more secured - either using IP Restrictions Or integrating with a Virtual Network (*aka Subnet of VNET*) through Service Endpoint.

So let us see how to achieve this in terraform...the trick is to use the concept of terraform Modules<br>Let us create a Azure VNET first with corresponding Subnet to be integrated with the above Storage resource.<br>This would ensure that all communication that Storage resource would be accessed only from within the mapped Subnet i.e. resources which sits within that Subnet or themselves integrated with that Subnet. On Azure this is achieved using Service Endpoint - which is secured endpoint created for a particular type of Resource - Microsoft.Storage in this case.

Terraform makes this entire mapping process very automated in a very simple way; let us see that in action:

```
resource "azurerm_virtual_network" "vnet" {

    name = "terraform-workshop-vnet"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    address_space = ["173.0.0.0/16"]    
  
}
```

This will snippet will ensure the creation of the virtual network on Azure with the address space - *173.0.0.0/16*

```
resource "azurerm_subnet" "storage-subnet" {

    name = "terraform-workshop-storage-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.0.0/24"]
    service_endpoints = ["Microsoft.Storage"] // extremely important
  
}
```

```
output "storage-subnet-id" {    // extremely important
  value = azurerm_subnet.storage-subnet.id
}
```

The line - ***service_endpoints = ["Microsoft.Storage"]*** is responsible for creating the Service Endpoint for any Storage resource.<br Similarly, the *output* section ensure the subnet id is exposed for use by the other config modules i.e. Storage module in thsi case!

Then in the Storage config file -

```
resource "azurerm_storage_account" "storage" {

    name = "terrwkshpstg"    
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    account_kind = "StorageV2"
    account_tier = "Premium"
    access_tier = "Hot"
    account_replication_type = "LRS"

    network_rules {

        default_action = "Deny"
        virtual_network_subnet_ids = ["module.network.storage-subnet-id"]
        bypass = ["Metrics"]

    }
  
}
```

***network_rules*** is the key where the Storage is mapped with he above Subnet having exposed a *Service Endpoint*.This ensure that all communication between the resources own the above subnet and the Storage is over Microsoft Backbone network.<br>Only thing that still remains a mystery is the *virtual_network_subnet_ids = ["**module.network.storage-subnet-id**"]*

How is this thing being mapped? Very simple -

```
module "network" {
  source = "../Network/"
  
}
```

With this at the top of the storage config file - ensures that the module is referred and the objects that are output from that module can be referred!

This is how, with the help of terraform config, an automated deployment of  Storage onto Azure can happen, integrated with Network rules

#### Refs:

- **Storage Accoun**t - https://www.terraform.io/docs/providers/azurerm/r/storage_account.html

- **Storage with Network Rules** - https://www.terraform.io/docs/providers/azurerm/r/storage_account_network_rules.html

- **Terraform Modules** - https://www.terraform.io/docs/configuration/modules.html

- **Source Code**: https://github.com/monojit18/TerraformProjects.git

  

## ACR

```
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
```

The type of the resource is *azurerm_container_registry* and terraform specific name of the resource is *acr*.

Most of the parameters are self-explanatory but few needs some explanation -

***admin_enabled*** - This ensures that you do not allow everyone to access ACR; this is first level of defence. So, it is forced that a *Service Principal* is created and used that a s reds for accessing the ACR

***network_rule_set*** - This is 2nd line of defence; making sure that the individual or process/script can access ACR only from designated network - this can be a VM or another process/program/service running in that subnet.

*Note: The newest offering is Private Endpoint support for ACR where a Private IP range is- WIP*

###  Module Dependencies

```
module "network" {
  source = "../Network/"
  
}
```

This ensures that the SubnetId poured out by Network module can be referred by the ACR resource

On the other hand, in the Network module -

```
output "acr-subnet-ip" {    
  value = azurerm_subnet.acr-subnet.address_prefixes[0]
}
```

This is responsible to output the subnet id for ACR

#### Refs:

- **ACR** - https://www.terraform.io/docs/providers/azurerm/r/container_registry.html

- **ACR with Network Rules** - https://www.terraform.io/docs/providers/azurerm/r/container_registry.html#network_rule_set

- **Source Code**: https://github.com/monojit18/TerraformProjects.git 

  
## KeyVault

```
resource "azurerm_key_vault" "kv" {

    name = "terraform-workshop-kv"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    tenant_id = "<tenant_id>"
    enabled_for_disk_encryption = true
    enabled_for_template_deployment = true
    sku_name = "premium"
    
}
```

All parameters are self-explanatory here in this case and quite straight-forward. This is primarily creating a *KeyVault* resource on Azure.

```
resource "azurerm_key_vault_access_policy" "kvpolicy" {
  
    key_vault_id = azurerm_key_vault.kv.id
    tenant_id = "<tenant_id>"
    object_id = "<object_id>"
    secret_permissions = [
        "get", "list", "delete", "set"
    ]

}
```

This is to define KeyVault access policy

Now KeyVault being the most critical resource on Azure, it is of utmost importance that maximum security is maintained in terms of accessing the KeyVault resource!

The process is same as ACR or Storage scenarios - either use VNET integration, IP Ranges OR the newest offering is to use Private Endpoint. Te last option us not discussed here and terraform, most probably, does not have that option yet. So, you might beed to do it manually in portal if you want go ahead with Private Endpoint approach. Rest two are quite possible -

```
resource "azurerm_key_vault" "kv" {

    name = "terraform-workshop-kv"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    tenant_id = "<tenant_id>"
    enabled_for_disk_encryption = true
    enabled_for_template_deployment = true
    sku_name = "premium"
    
    network_acls {

        bypass = "AzureServices"
        default_action = "Deny"
        virtual_network_subnet_ids = ["module.network.kv-subnet-id"]

    } 
}
```

As can be seen  ***network_acls*** is the key - this links to the id of the subnet resource created by Network module; same as it was done for Storage and ACR above!

Let us see the network module section -

```
output "kv-subnet-id" {    
  value = azurerm_subnet.kv-subnet.id
}
```

#### Refs:

- **KeyVault** - https://www.terraform.io/docs/providers/azurerm/r/key_vault.html
- **KeyVault with Access Policies** - https://www.terraform.io/docs/providers/azurerm/r/key_vault_access_policy.html
- **KeyVault with Network Rules** - https://www.terraform.io/docs/providers/azurerm/r/key_vault.html#network_acls
- **Source Code**: https://github.com/monojit18/TerraformProjects.git 



## WebApp

```
resource "azurerm_app_service_plan" "appplan" {

    name = "webapp-standard-plan"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    sku {

        tier = "Standard"
        size = "S1"

    }
}
```

App Service Plan is created first which would hold multiple app services inside it. The cost for the app services are actually tagged with the corresponding plan; Scaling and Performance parameters are also linked with the plan only and shared across all app services  within the same plan!

```
resource "azurerm_app_service" "appservice" {
  
    name = "terraform-app-service"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id // referring the Plan created earlier!

    site_config {

        dotnet_framework_version = "v4.0"

    }
}
```

App service refers to the App Service Plan created in earlier step (*dependency*).<br>***site_config*** - primarily defines the tech stack and vision for the app service. There are many other parameters and you need to refer to the docs (*links below*).

### Storage Account for WebApp

WebApp like many other resources on Azure needs a Storage account to maintain state and other such information. If not specified during creation process in the above scripts - it would create a default one. To avoid this, ***storage_account*** block would help to create a custom storage account..like below -

```
resource "azurerm_app_service" "appservice" {
  
    name = "terraform-app-service"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }

    storage_account { // custom storage account

        name = "PrimaryKey"
        access_key = "<access_key>"
        type = "AzureBlob"
        account_name = "terrwkshpstg"
        share_name = "webappcntr"

    }
}
```

One catch with this approach is that the Access Key of the storage account is exposed - which is risky. How do we solve that? Easiest way to achieve this is store that in a KeyVault (*like the one we just created in previous section!*). But how to refer to the KeyVault and also the secret at runtime without exposing it? Terraform has a nice config type called *data* that helps in here!

Let us quickly delve into this -

```
data "azurerm_key_vault" "existing" {

    name = "terraform-workshop-kv"
    resource_group_name = azurerm_resource_group.rg.name
}

data "azurerm_key_vault_secret" "existing" {

    name = "stgpkey"
    key_vault_id = data.azurerm_key_vault.existing.id // Referring the KeyVault retrieved
}
```

*azurerm_key_vault* is the type that we are referring with data; the name *existing* is just for convenience; to make it more meaningful, that refers to an existing KeyVault instance!

*azurerm_key_vault_secret* is the secret type from KeyVault which would return the secret value of the said key (i.e. *stgpkey* in this case).

```
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
        access_key = data.azurerm_key_vault_secret.existing.key_vault_id // Secret Value
        type = "AzureBlob"
        account_name = "terrwkshpstg"
        share_name = "webappcntr"

    }
}
```

### Slots

How to define slots for the app and specify while creating the App service? Simple in terraform...just specify a Slot block and define the config for the slot -

```
variable "env" {
  
    type = list(string)
    default = ["DEV", "QA"] // Array of environments
    
}
```



#### 	*DEV - Slot*

```
resource "azurerm_app_service_slot" "devslot" {
  
    name = join("", [azurerm_app_service.appservice.name, "-", var.env[0], "-slot"]) // DEV
    app_service_name = azurerm_app_service.appservice.name
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }
}
```

#### 	*QA - Slot*

```
	resource "azurerm_app_service_slot" "qaslot" {
  
    name = join("", [azurerm_app_service.appservice.name, "-", var.env[1], "-slot"]) // QA
    app_service_name = azurerm_app_service.appservice.name
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    app_service_plan_id = azurerm_app_service_plan.appplan.id

    site_config {

        dotnet_framework_version = "v4.0"

    }
}
```



#### Refs:

- ***WebApp*** - https://www.terraform.io/docs/providers/azurerm/r/app_service.html
- **WebApp with Slots** - https://www.terraform.io/docs/providers/azurerm/r/app_service_slot.html
- **Source Code**: https://github.com/monojit18/TerraformProjects.git 



### Virtual Network

```
provider "azurerm" {

    version = "=2.11.0"
    features {}
    subscription_id = "<subscription_id>"
    tenant_id = "<tenant_id>"

}
```

This is standard way of specifying Azure Provider. So that terraform can download necessary plugins and dependencies.

How to create the resource group on Azure? As previously described -

```
resource "azurerm_resource_group" "rg" {

    name = "terraform-workshop-rg"
    location = "eastus"
    tags = {

        Primary_Owner = "monojit.datta@outlook.com"
        Purpose = "workshop"

    }
}
```

Creating the Virtual Network (VNET) on Azure - nothing special

```
resource "azurerm_virtual_network" "vnet" {

    name = "terraform-workshop-vnet"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    address_space = ["173.0.0.0/16"]    
  
}
```

Creating subnet to hold/integrate with various resources - e.g. following is for Storage -

```
resource "azurerm_subnet" "storage-subnet" {

    name = "terraform-workshop-storage-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.0.0/24"]
    service_endpoints = ["Microsoft.Storage"]
  
}
```

Similarly ones for KeyVault and ACR respectively -

```
resource "azurerm_subnet" "kv-subnet" {

    name = "terraform-workshop-kv-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.2.0/24"]
    service_endpoints = ["Microsoft.KeyVault"]
  
}

```

```
resource "azurerm_subnet" "acr-subnet" {

    name = "terraform-workshop-acr-subnet"    
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["173.0.1.0/24"]
    service_endpoints = ["Microsoft.ContainerRegistry"]
  
}
```

#### Role Assignments

How to assign network specific roles to VNET - e.g. below is how you can assign *Network Contributor* role -

```
resource "azurerm_role_assignment" "nwroles" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = "<principal_id>"
  
}
```

***principal_id*** - is obtained by running - *az role assignment list <>* 

#### Module Output

What if other modules need the Subnet Ids or some other info for further use? Terraform can expose such desired values as *output*; e.g. Subnet Ids for Storage, ACR and KeyVault all are exposed as below -

```
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
```

For ACR, as can be seen, it exposes both ACR subnet address prefix as fellas Subnet Id

#### Refs:

- ***Virtual Network*** - https://www.terraform.io/docs/providers/azurerm/r/virtual_network.html
- **Subnet** - https://www.terraform.io/docs/providers/azurerm/r/subnet.html
- **Source Code**: https://github.com/monojit18/TerraformProjects.git 