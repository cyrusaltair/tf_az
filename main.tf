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

  tags = local.tags
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-network-security-group"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  tags = local.tags
}

resource "azurerm_network_security_rule" "nsr" {
    name                   = "${var.prefix}-NSG-security-rule"
    access                 = "Allow"
    description            = "security rule for the mailer network security group"
    destination_address_prefix = "*"
    destination_port_range = "*"
    source_address_prefix = "*"
    source_port_range      = "*"
    direction              = "Outbound"
    priority               = 100
    protocol               = "Tcp"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  }

resource "azurerm_virtual_network" "vn" {
  name                        = "${var.prefix}-virtual-network"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  address_space               = var.address_space

  tags = local.tags
}

resource "azurerm_subnet" "subnet" {
  name                        = "${var.prefix}-subnet1"
  resource_group_name         = azurerm_resource_group.rg.name
  virtual_network_name        = azurerm_virtual_network.vn.name
  address_prefixes            = var.subnet_prefix
}

resource "azurerm_network_interface" "ni" {
    name = "${var.prefix}-network-interface"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location

    ip_configuration {
      name = "${var.prefix}-ni-ip-config"
      subnet_id = azurerm_subnet.subnet.id
      private_ip_address_allocation = "Dynamic"
    }

    tags = local.tags
}

resource "azurerm_linux_virtual_machine_scale_set" "asg" {
  name = "${var.prefix}-linux-scaling-set"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  sku = var.vm_size
  instances = 3
  admin_username = var.adminuser

  admin_ssh_key {
    username = var.adminuser
    public_key = local.pubkey
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

    source_image_reference {
  publisher = "Canonical"
  offer     = "UbuntuServer"
  sku       = "16.04-LTS"
  version   = "latest"
  }

  network_interface {
    name = "${var.prefix}-linux-scaling-set-ni"
    primary = true
    
    ip_configuration {
      name = "${var.prefix}-linux-scaling-set-ni-ipconfig"
      primary = true
      subnet_id = azurerm_subnet.subnet.id
    }
  }
  tags = local.tags
}

resource "azurerm_public_ip" "lb_ip" {
  name = "${var.prefix}-load-balancer-publicIP"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
}

resource "azurerm_lb" "lb" {
  name = "${var.prefix}-load-balancer"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku = "Basic"

  frontend_ip_configuration {
    name = "lb_PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}
 
resource "azurerm_linux_virtual_machine" "dns_vm" {
    name = "${var.prefix}-dns-vm-1"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    size = var.vm_size
    admin_username = var.adminuser
    network_interface_ids = [azurerm_network_interface.ni.id]

    admin_ssh_key {
      username = var.adminuser
      public_key = local.pubkey
    }

    os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }

      source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
    
    tags = local.tags
}

