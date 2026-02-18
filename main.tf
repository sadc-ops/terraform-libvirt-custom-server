locals {
  cloud_init_volume_name = var.cloud_init_volume_name == "" ? "${var.name}-cloud-init.iso" : var.cloud_init_volume_name
  hostname = var.hostname.hostname != "" ? var.hostname.hostname : var.name
  network_interfaces = concat(
    [for libvirt_network in var.libvirt_networks: {
      network_name = libvirt_network.network_name != "" ? libvirt_network.network_name : null
      network_id = libvirt_network.network_id != "" ? libvirt_network.network_id : null
      macvtap = null
      addresses = null
      mac = libvirt_network.mac
      hostname = local.hostname
      wait_for_lease = libvirt_network.wait_for_lease
    }],
    [for macvtap_interface in var.macvtap_interfaces: {
      network_name = null
      network_id = null
      macvtap = macvtap_interface.interface
      addresses = null
      mac = macvtap_interface.mac
      hostname = null
      wait_for_lease = macvtap_interface.wait_for_lease
    }]
  )
  network_perf_tuning_effective = [
    for p in var.network_perf_tuning : {
      network_type = p.network_type
      network_name = p.network_name
      vhost_queues = coalesce(p.vhost_queues, min(var.vcpus, 8))
    }
  ]
  should_enable_xml = (length(local.gpu_devices) + length(local.network_perf_tuning_effective)) > 0
}

module "network_configs" {
  source = "git::https://github.com/sadc-ops/terraform-cloudinit-templates.git//network?ref=v0.50.1_miircic"
  machine= var.machine
  network_interfaces = concat(
    [for idx, libvirt_network in var.libvirt_networks: {
      ip = libvirt_network.ip
      gateway = libvirt_network.gateway
      prefix_length = libvirt_network.prefix_length
      interface = "libvirt${idx}"
      mac = libvirt_network.mac
      dns_servers = libvirt_network.dns_servers
      search_domains = libvirt_network.search_domains
      dhcp_identifier = libvirt_network.dhcp_identifier
      dhcp4_overrides = libvirt_network.dhcp4_overrides
    }],
    [for idx, macvtap_interface in var.macvtap_interfaces: {
      ip = macvtap_interface.ip
      gateway = macvtap_interface.gateway
      prefix_length = macvtap_interface.prefix_length
      interface = "macvtap${idx}"
      mac = macvtap_interface.mac
      dns_servers = macvtap_interface.dns_servers
      search_domains = macvtap_interface.search_domains
      dhcp_identifier = macvtap_interface.dhcp_identifier
      dhcp4_overrides = macvtap_interface.dhcp4_overrides
    }]
  )
}

locals {
  cloudinit_templates = concat([
      {
        filename     = "base.cfg"
        content_type = "text/cloud-config"
        content = templatefile(
          "${path.module}/files/user_data.yaml.tpl", 
          {
            hostname = local.hostname
            is_fqdn = var.hostname.is_fqdn
            ssh_admin_public_key = var.ssh_admin_public_key
            ssh_admin_user = var.ssh_admin_user
            admin_user_password = var.admin_user_password
            qemu_agent = var.qemu_agent
          }
        )
      }
    ],
    [for cloud_init_configuration in var.cloud_init_configurations: {
      filename     = cloud_init_configuration.filename
      content_type = "text/cloud-config"
      content      = cloud_init_configuration.content
    }]
  )
}

data "template_cloudinit_config" "user_data" {
  gzip = false
  base64_encode = false
  dynamic "part" {
    for_each = local.cloudinit_templates
    content {
      filename     = part.value["filename"]
      content_type = part.value["content_type"]
      content      = part.value["content"]
    }
  }
}

resource "libvirt_cloudinit_disk" "vm" {
  name           = local.cloud_init_volume_name
  user_data      = data.template_cloudinit_config.user_data.rendered
  network_config = module.network_configs.configuration
  pool           = var.cloud_init_volume_pool
}

resource "libvirt_domain" "vm" {
  timeouts {
    create = var.timeouts.create
  }
  name = var.name
  machine = var.machine != "" ? var.machine : null

  cpu {
    mode = "host-passthrough"
  }

  vcpu = var.vcpus
  memory = var.memory

  dynamic "disk" {
    for_each = var.volume_ids
    content {
      volume_id = disk.value
    }
  }

  dynamic "network_interface" {
    for_each = local.network_interfaces
    content {
      network_id = network_interface.value["network_id"]
      network_name = network_interface.value["network_name"]
      macvtap = network_interface.value["macvtap"]
      addresses = network_interface.value["addresses"]
      mac = network_interface.value["mac"]
      hostname = network_interface.value["hostname"]
      wait_for_lease = network_interface.value["wait_for_lease"]
    }
  }
  qemu_agent = var.qemu_agent
  running = var.running
  autostart = var.autostart

  cloudinit = libvirt_cloudinit_disk.vm.id

  //https://github.com/dmacvicar/terraform-provider-libvirt/blob/main/examples/v0.13/ubuntu/ubuntu-example.tf#L61
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = var.domain_graphics_type
    listen_type = "address"
    autoport    = true
  }


  dynamic "xml" {
    for_each = local.should_enable_xml ? [1] : []
    content {
      xslt = templatefile(
        "${path.module}/files/devices.xslt.tpl",
        {
          gpus = local.gpu_devices,
          nic_tuning =  local.network_perf_tuning_effective
          machine = var.machine
        }
      )
    }
  }
}
