output "domain_network_interfaces" {
  description = "domain network interfaces"
  value = libvirt_domain.vm.network_interface
}