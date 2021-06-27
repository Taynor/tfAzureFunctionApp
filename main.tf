#The var.value references can be found in the variables.tf file
#Declare the terraform procider
terraform {
required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.57.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

#Create the Azure resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.azure_location
}

#Create the VNET for the resources to be contained in
resource "azurerm_virtual_network" "functionapp_vnet" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  address_space       = ["10.10.10.0/24"]
  depends_on          = [azurerm_resource_group.rg]
}

#Create the subnet for the function app
resource "azurerm_subnet" "functionapp_subnet" {
    name                 = "functionappsubnet"
    address_prefixes     = ["10.10.10.0/25"]
    resource_group_name  = var.resource_group_name
    virtual_network_name = azurerm_virtual_network.functionapp_vnet.name
    delegation {
      name               = "exampleappdelegation"
    service_delegation {
      name               = "Microsoft.Web/serverFarms"
      actions            = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
    depends_on           = [azurerm_resource_group.rg, azurerm_virtual_network.functionapp_vnet]
}

#Create the Gateway public IP
resource "azurerm_public_ip" "gateway_public_ip" {
  name                = "gatewaypublicip"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

#Create the NAT Gateway
resource "azurerm_nat_gateway" "example_nat_gateway" {
  name                = "examplenatgateway"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  depends_on          = [azurerm_resource_group.rg]
}

#Associate the Gateway public IP with the NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "example_nat_public_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.example_nat_gateway.id
  public_ip_address_id = azurerm_public_ip.gateway_public_ip.id  
  depends_on           = [azurerm_public_ip.gateway_public_ip, azurerm_nat_gateway.example_nat_gateway]
}

#Associate the function app subnet with the NAT Gateway
resource "azurerm_subnet_nat_gateway_association" "example_nat_gateway_ip_assoc" {
  subnet_id      = azurerm_subnet.functionapp_subnet.id
  nat_gateway_id = azurerm_nat_gateway.example_nat_gateway.id
  depends_on     = [azurerm_nat_gateway.example_nat_gateway, azurerm_subnet.functionapp_subnet]
}

#Create the storage account
resource "azurerm_storage_account" "functionapp_storage" {
  name                      = var.functionapp_storage_account_name
  resource_group_name       = var.resource_group_name
  location                  = var.azure_location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  min_tls_version           = "TLS1_2"
  enable_https_traffic_only = true
  network_rules {
    default_action="Deny"
  }
  depends_on               = [azurerm_resource_group.rg]
}

#Create the shared access signature (sas) for storage account access
data "azurerm_storage_account_sas" "functionapp_storage_sas" {
  connection_string = azurerm_storage_account.functionapp_storage.primary_connection_string
  https_only        = true
  signed_version    = "2017-07-29"
  resource_types {
    service   = true
    container = false
    object    = false
  }
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  start  = "2021-06-27T00:00:00Z"
  expiry = "2022-06-28T00:00:00Z"
  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}

#Create premium app service plan to use VNET integration
resource "azurerm_app_service_plan" "exampleappplan" {
  name                = "azurefunctionserviceplan"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  sku {
    tier = "Premium"
    size = "S1"
  }
  depends_on = [azurerm_resource_group.rg]
}

#Create the function app
resource "azurerm_function_app" "exampleapp_functionapp" {
  name                       = var.functionapp_name
  location                   = var.azure_location
  resource_group_name        = var.resource_group_name
  app_service_plan_id        = azurerm_app_service_plan.exampleappplan.id
  storage_account_name       = var.functionapp_storage_account_name
  storage_account_access_key = data.azurerm_storage_account_sas.functionapp_storage_sas.id
  https_only                 = true
  app_settings               = var.app_settings
  auth_settings {
    enabled = true
  }
  site_config {
    http2_enabled = true
  } 
  depends_on                 = [azurerm_resource_group.rg, azurerm_storage_account.functionapp_storage, azurerm_app_service_plan.exampleappplan]
}

#Create the function app public IP VNET integration
resource "azurerm_app_service_virtual_network_swift_connection" "exampleapp_function_vnet_integration" {
  app_service_id = azurerm_function_app.exampleapp_functionapp.id
  subnet_id      = azurerm_subnet.functionapp_subnet.id
  depends_on     = [azurerm_function_app.exampleapp_functionapp, azurerm_subnet.functionapp_subnet]
}