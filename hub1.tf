######################### RG ######################################
###################################################################
resource "azurerm_resource_group" "rg_hub_data" {
  name     = "rg-hub-data"
  location = "eastus"
}

resource "azurerm_resource_group" "rg_spoke_data" {
  name     = "rg-spoke-data"
  location = "eastus"
}

######################### VNET HUB ################################
###################################################################

resource "azurerm_virtual_network" "vnet_hub_data" {
  name                = "vnet-hub-data"
  location            = azurerm_resource_group.rg_hub_data.location
  resource_group_name = azurerm_resource_group.rg_hub_data.name
  address_space       = ["10.1.0.0/16"]

}

resource "azurerm_subnet" "snet_routeserver" {
  name                 = "RouteServerSubnet"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data.name
  resource_group_name  = azurerm_resource_group.rg_hub_data.name
  address_prefixes     = ["10.1.1.0/27"]
}

resource "azurerm_subnet" "snet_nva" {
  name                 = "snet-nva"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data.name
  resource_group_name  = azurerm_resource_group.rg_hub_data.name
  address_prefixes     = ["10.1.2.0/27"]
}

resource "azurerm_subnet" "AzureBastionSubnet" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data.name
  resource_group_name  = azurerm_resource_group.rg_hub_data.name
  address_prefixes     = ["10.1.3.0/27"]
}

resource "azurerm_virtual_network" "vnet_spoke_data" {
  name                = "vnet-spoke-data"
  location            = azurerm_resource_group.rg_spoke_data.location
  resource_group_name = azurerm_resource_group.rg_spoke_data.name
  address_space       = ["10.4.0.0/16"]

}

resource "azurerm_subnet" "snet_workload" {
  name                 = "sub-workload"
  virtual_network_name = azurerm_virtual_network.vnet_spoke_data.name
  resource_group_name  = azurerm_resource_group.rg_spoke_data.name
  address_prefixes     = ["10.4.1.0/27"]
}

######################### Azure Route Server ################################
#############################################################################

resource "azurerm_public_ip" "pub_ip_routeserver" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.rg_hub_data.name
  location            = azurerm_resource_group.rg_hub_data.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "route_server" {
  name                             = "rts-hub1"
  resource_group_name              = azurerm_resource_group.rg_hub_data.name
  location                         = azurerm_resource_group.rg_hub_data.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.pub_ip_routeserver.id
  subnet_id                        = azurerm_subnet.snet_routeserver.id
  branch_to_branch_traffic_enabled = true
}

resource "azurerm_virtual_network_peering" "example_1" {
  name                         = "peer1to2"
  resource_group_name          = azurerm_resource_group.rg_spoke_data.name
  virtual_network_name         = azurerm_virtual_network.vnet_spoke_data.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub_data.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true

  depends_on = [azurerm_route_server.route_server]

}

resource "azurerm_virtual_network_peering" "example_2" {
  name                         = "peer2to1"
  resource_group_name          = azurerm_resource_group.rg_hub_data.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub_data.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_spoke_data.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = [azurerm_route_server.route_server]
}

resource "azurerm_route_server_bgp_connection" "example" {
  name            = "quagga"
  route_server_id = azurerm_route_server.route_server.id
  peer_asn        = 65001
  peer_ip         = "10.1.2.4"
}

########################### Route Table ####################################
############################################################################
resource "azurerm_route_table" "rt_01" {
  name                = "rt-01"
  location            = azurerm_resource_group.rg_hub_data.location
  resource_group_name = azurerm_resource_group.rg_hub_data.name

  route {
    name                   = "route1"
    address_prefix         = "10.3.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.2.2.4"
  }
}

resource "azurerm_subnet_route_table_association" "assco01" {
  subnet_id      = azurerm_subnet.snet_nva.id
  route_table_id = azurerm_route_table.rt_01.id
}

######################### Azure Bastion #####################################
#############################################################################
resource "azurerm_public_ip" "example" {
  name                = "bastion-ip"
  location            = azurerm_resource_group.rg_hub_data.location
  resource_group_name = azurerm_resource_group.rg_hub_data.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "example" {
  name                = "examplebastion"
  location            = azurerm_resource_group.rg_hub_data.location
  resource_group_name = azurerm_resource_group.rg_hub_data.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet.id
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

######################### Azure Virtual Machine NVA #############################
#################################################################################

resource "azurerm_network_interface" "nva" {
  count = 1

  name                  = "vm-nva-${count.index}-nic"
  location              = azurerm_resource_group.rg_hub_data.location
  resource_group_name   = azurerm_resource_group.rg_hub_data.name
  ip_forwarding_enabled = true


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_nva.id
    private_ip_address_allocation = "Static"

    private_ip_address = "10.1.2.4"
  }
}

resource "azurerm_linux_virtual_machine" "vm_nva" {
  count = 1

  name                = "vm-nva-hub-1"
  resource_group_name = azurerm_resource_group.rg_hub_data.name
  location            = azurerm_resource_group.rg_hub_data.location
  size                = "Standard_B2s"
  custom_data         = base64encode(file("./bash_nva.sh"))
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nva[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202201040"
  }

}

######################### Azure Virtual Machine Teste Spoke #############################
#########################################################################################
resource "azurerm_network_interface" "vm_teste" {
  count = 1

  name                = "vm-teste-${count.index}-nic"
  location            = azurerm_resource_group.rg_spoke_data.location
  resource_group_name = azurerm_resource_group.rg_spoke_data.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_teste" {
  count = 1

  name                = "vm-teste-spoke-1"
  resource_group_name = azurerm_resource_group.rg_spoke_data.name
  location            = azurerm_resource_group.rg_spoke_data.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm_teste[count.index].id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202201040"
  }

}

######################### Peering hub to hub #########################
######################################################################
resource "azurerm_virtual_network_peering" "example_hub2" {
  name                         = "hubtohub2"
  resource_group_name          = azurerm_resource_group.rg_hub_data.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub_data.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub_data2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

########################## NSG Rules ####################################
#########################################################################
resource "azurerm_network_security_group" "sg_1" {
  name                = "nsg-1"
  location            = azurerm_resource_group.rg_spoke_data.location
  resource_group_name = azurerm_resource_group.rg_spoke_data.name
}

resource "azurerm_network_security_rule" "sg_1" {
  name                        = "test123"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_spoke_data.name
  network_security_group_name = azurerm_network_security_group.sg_1.name
}

resource "azurerm_network_security_rule" "sg_out_1" {
  name                        = "test1w23"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_spoke_data.name
  network_security_group_name = azurerm_network_security_group.sg_1.name
}

resource "azurerm_subnet_network_security_group_association" "associate_1" {
  subnet_id                 = azurerm_subnet.snet_workload.id
  network_security_group_id = azurerm_network_security_group.sg_1.id
}

resource "azurerm_subnet_network_security_group_association" "associate_nva_1" {
  subnet_id                 = azurerm_subnet.snet_nva.id
  network_security_group_id = azurerm_network_security_group.sg_1.id
}