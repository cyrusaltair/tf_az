terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.44.1"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-resource-group"
  location = var.location

  tags = locals.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-network-security-group"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  security_rule = {
    access                 = "Allow"
    description            = "security rule for the mailer network security group"
    destination_port_range = "*"
    direction              = "outbound"
    name                   = "${var.prefix}-NSG-security-rule"
    priority               = 1
    protocol               = "Tcp"
    source_port_range      = "*"

    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = azurerm_network_security_group.nsg.name

    tags = locals.tags
  }

  tags = locals.tags
}

resource "azurerm_virtual_network" "vn" {
  name                        = "${var.prefix}-virtual-network"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  location                    = azurerm_resource_group.rg.location
  address_space               = var.address_space

  tags = locals.tags
}

resource "azurerm_subnet" "subnet1" {
  name                        = "${var.prefix}-subnet1"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  virtual_network_name        = azurerm_virtual_network.vn.name
  address_prefixes            = var.address_prefixes

  tags = locals.tags
}

resource "azurerm_network_interface" "ni" {
    name = "${var.prefix}-network-interface"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location

    ip_configuration {
      name = "${var.prefix}-ni-ip-config"
      subnet_id = azurerm_subnet.subnet.id
      private_ip_address_allocation = "dynamic"
      tags = locals.tags
    }

    tags = locals.tags
}

resource "azurerm_virtual_machine" "vm1" 
    name = "${var.prefix}-virtual-machine1"




    tags = locals.tags
}
# VM, autoscaler, load balancer, internet gateway, 