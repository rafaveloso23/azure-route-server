######################### RG ######################################
###################################################################
resource "azurerm_resource_group" "rg_hub_data2" {
  name     = "rg-hub-data2"
  location = "eastus"
}

resource "azurerm_resource_group" "rg_spoke_data2" {
  name     = "rg-spoke-data2"
  location = "eastus"
}

######################### VNET HUB ################################
###################################################################

resource "azurerm_virtual_network" "vnet_hub_data2" {
  name                = "vnet-hub-data-2"
  location            = azurerm_resource_group.rg_hub_data2.location
  resource_group_name = azurerm_resource_group.rg_hub_data2.name
  address_space       = ["10.2.0.0/16"]

}

resource "azurerm_subnet" "snet_routeserver2" {
  name                 = "RouteServerSubnet"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data2.name
  resource_group_name  = azurerm_resource_group.rg_hub_data2.name
  address_prefixes     = ["10.2.1.0/27"]
}

resource "azurerm_subnet" "snet_nva2" {
  name                 = "snet-nva"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data2.name
  resource_group_name  = azurerm_resource_group.rg_hub_data2.name
  address_prefixes     = ["10.2.2.0/27"]
}

resource "azurerm_subnet" "AzureBastionSubnet2" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = azurerm_virtual_network.vnet_hub_data2.name
  resource_group_name  = azurerm_resource_group.rg_hub_data2.name
  address_prefixes     = ["10.2.3.0/27"]
}

resource "azurerm_virtual_network" "vnet_spoke_data2" {
  name                = "vnet-spoke-data"
  location            = azurerm_resource_group.rg_spoke_data2.location
  resource_group_name = azurerm_resource_group.rg_spoke_data2.name
  address_space       = ["10.3.0.0/16"]

}

resource "azurerm_subnet" "snet_workload2" {
  name                 = "sub-workload"
  virtual_network_name = azurerm_virtual_network.vnet_spoke_data2.name
  resource_group_name  = azurerm_resource_group.rg_spoke_data2.name
  address_prefixes     = ["10.3.1.0/27"]
}

######################### Azure Route Server ################################
#############################################################################

resource "azurerm_public_ip" "pub_ip_routeserver2" {
  name                = "example-pip"
  resource_group_name = azurerm_resource_group.rg_hub_data2.name
  location            = azurerm_resource_group.rg_hub_data2.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "route_server2" {
  name                             = "rts-hub2"
  resource_group_name              = azurerm_resource_group.rg_hub_data2.name
  location                         = azurerm_resource_group.rg_hub_data2.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.pub_ip_routeserver2.id
  subnet_id                        = azurerm_subnet.snet_routeserver2.id
  branch_to_branch_traffic_enabled = true
}

resource "azurerm_virtual_network_peering" "example_12" {
  name                         = "peer1to2"
  resource_group_name          = azurerm_resource_group.rg_spoke_data2.name
  virtual_network_name         = azurerm_virtual_network.vnet_spoke_data2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub_data2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true

  depends_on = [azurerm_route_server.route_server2]

}

resource "azurerm_virtual_network_peering" "example_22" {
  name                         = "peer2to1"
  resource_group_name          = azurerm_resource_group.rg_hub_data2.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub_data2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_spoke_data2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true

  depends_on = [azurerm_route_server.route_server2]
}

resource "azurerm_route_server_bgp_connection" "example2" {
  name            = "quagga2"
  route_server_id = azurerm_route_server.route_server2.id
  peer_asn        = 65002
  peer_ip         = "10.2.2.4"
}

########################### Route Table ####################################
############################################################################
resource "azurerm_route_table" "rt_02" {
  name                = "rt-02"
  location            = azurerm_resource_group.rg_hub_data2.location
  resource_group_name = azurerm_resource_group.rg_hub_data2.name

  route {
    name                   = "route1"
    address_prefix         = "10.4.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.1.2.4"
  }
}

resource "azurerm_subnet_route_table_association" "assco02" {
  subnet_id      = azurerm_subnet.snet_nva2.id
  route_table_id = azurerm_route_table.rt_02.id
}

######################### Azure Bastion #####################################
#############################################################################
resource "azurerm_public_ip" "example2" {
  name                = "bastion-ip"
  location            = azurerm_resource_group.rg_hub_data2.location
  resource_group_name = azurerm_resource_group.rg_hub_data2.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "example2" {
  name                = "examplebastion"
  location            = azurerm_resource_group.rg_hub_data2.location
  resource_group_name = azurerm_resource_group.rg_hub_data2.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureBastionSubnet2.id
    public_ip_address_id = azurerm_public_ip.example2.id
  }
}

######################### Azure Virtual Machine NVA #############################
#################################################################################

resource "azurerm_network_interface" "nva2" {
  count = 1

  name                 = "vm-nva-${count.index}-nic"
  location             = azurerm_resource_group.rg_hub_data2.location
  resource_group_name  = azurerm_resource_group.rg_hub_data2.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_nva2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.2.2.4"
  }
}

resource "azurerm_linux_virtual_machine" "vm_nva2" {
  count = 1

  name                = "vm-nva-hub-2"
  resource_group_name = azurerm_resource_group.rg_hub_data2.name
  location            = azurerm_resource_group.rg_hub_data2.location
  size                = "Standard_B2s"
  custom_data         = base64encode(file("./bash_nva_2.sh"))
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.nva2[count.index].id,
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
resource "azurerm_network_interface" "vm_teste2" {
  count = 1

  name                = "vm-teste-${count.index}-nic"
  location            = azurerm_resource_group.rg_spoke_data2.location
  resource_group_name = azurerm_resource_group.rg_spoke_data2.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet_workload2.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vm_teste2" {
  count = 1

  name                = "vm-teste-spoke-2"
  resource_group_name = azurerm_resource_group.rg_spoke_data2.name
  location            = azurerm_resource_group.rg_spoke_data2.location
  size                = "Standard_B2s"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm_teste2[count.index].id,
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
resource "azurerm_virtual_network_peering" "example_hub" {
  name                         = "hubtohub1"
  resource_group_name          = azurerm_resource_group.rg_hub_data2.name
  virtual_network_name         = azurerm_virtual_network.vnet_hub_data2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet_hub_data.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

########################## NSG Rules ####################################
#########################################################################
resource "azurerm_network_security_group" "sg_2" {
  name                = "nsg-1"
  location            = azurerm_resource_group.rg_spoke_data2.location
  resource_group_name = azurerm_resource_group.rg_spoke_data2.name
}

resource "azurerm_network_security_rule" "sg_2" {
  name                        = "test223"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_spoke_data2.name
  network_security_group_name = azurerm_network_security_group.sg_2.name
}

resource "azurerm_network_security_rule" "sg_out_2" {
  name                        = "test1w"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_spoke_data2.name
  network_security_group_name = azurerm_network_security_group.sg_2.name
}

resource "azurerm_subnet_network_security_group_association" "associate_2" {
  subnet_id                 = azurerm_subnet.snet_workload2.id
  network_security_group_id = azurerm_network_security_group.sg_2.id
}

resource "azurerm_subnet_network_security_group_association" "associate_nva_2" {
  subnet_id                 = azurerm_subnet.snet_nva2.id
  network_security_group_id = azurerm_network_security_group.sg_2.id
}