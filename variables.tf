#resource group name
variable "resource_group_name" {
    type    = string
    default = "exampleapprg"
}

#azure location
variable "azure_location" {
    type    = string
    default = "uksouth"
}

#storage account name for function app
variable "functionapp_storage_account_name" {
    type    = string
    default = "exampleappstorageaccount"
}

#function app name
variable "functionapp_name" {
    type    = string
    default = "exampleappfunctionapp"
}

#vnet name 
variable "vnet_name" {
    type    = string
    default = "functionappvnet"
}

#app setting for the function app to route traffic through the VNET integration with the NAT Gateway
variable "app_settings" {
    description = "Key value pair of app settings"
    default = {
        WEBSITE_VNET_ROUTE_ALL = "1"
    }
}