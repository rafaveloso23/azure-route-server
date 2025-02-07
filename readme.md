backup config:
!
router bgp $asn_quagga
 bgp router-id $bgp_routerId
 network $bgp_network2
 neighbor $routeserver_IP1 remote-as 65515
 neighbor $routeserver_IP1 soft-reconfiguration inbound
 neighbor $routeserver_IP2 remote-as 65515
 neighbor $routeserver_IP2 soft-reconfiguration inbound

 neighbor $neighbor_IP remote-as $neighbor_remote_as
 neighbor $neighbor_IP ebgp-multihop
 neighbor $neighbor_IP soft-reconfiguration inbound
!
 address-family ipv6
 exit-address-family
 exit
!
line vty
!

####
nic routes

az network nic show-effective-route-table -g rg-spoke-data2 -n vm-teste-0-nic --output table

az network nic show-effective-route-table -g rg-spoke-data -n vm-teste-0-nic --output table

az network nic show-effective-route-table -g rg-hub-data -n vm-nva-0-nic --output table

az network nic show-effective-route-table -g rg-hub-data2 -n vm-nva-0-nic --output table



 network $bgp_network1
az network routeserver peering list -g rg-hub-data --routeserver example-routerserver

az network routeserver peering list-advertised-routes --name quagga --routeserver example-routerserver --resource-group rg-hub-data

az network routeserver peering list-learned-routes -n quagga \
   --routeserver example-routerserver -g rg-hub-data --query 'RouteServiceRole_IN_0' -o table
vm-nva-0-nic
az network nic show-effective-route-table -g rg-spoke-data -n vm-teste-0-nic --output table
az network nic show-effective-route-table -g rg-hub-data -n vm-nva-0-nic --output table

https://rcs.is/knowledgebase/1627/Configuring-BGP-using-Quagga.html

run as sudo su
sudo systemctl restart zebra
sudo systemctl restart bgpd

show ip bgp summary
show ip bgp
show ip route bgp


router bgp 65001
 neighbor 10.2.2.4 remote-as 65002


router bgp 65002
 neighbor 10.1.2.4 remote-as 65001



on A:

configure terminal
router bgp 65001
neighbor 10.2.2.4 remote-as 65002
exit
exit
write


on B:

configure terminal
router bgp 65002
neighbor 10.1.2.4 remote-as 65001
exit
exit
write
