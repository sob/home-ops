# Cilium

## UniFi BGP

```sh
router bgp 64512
  bgp router-id 10.1.100.1
  no bgp ebgp-requires-policy

  neighbor k8s peer-group
  neighbor k8s remote-as 65534

  neighbor 10.1.100.104 peer-group k8s
  neighbor 10.1.100.105 peer-group k8s
  neighbor 10.1.100.106 peer-group k8s
  neighbor 10.1.100.107 peer-group k8s

  address-family ipv4 unicast
    neighbor k8s next-hop-self
    neighbor k8s soft-reconfiguration inbound
  exit-address-family
```
