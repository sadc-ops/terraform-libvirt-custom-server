variable "name" {
  description = "Name to give to the vm"
  type = string
}

variable "vcpus" {
  description = "Number of vcpus to assign to the vm"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MiB"
  type        = number
  default     = 8192
}

variable "volume_ids" {
  description = "Id of disk volumes to attach to the vm"
  type        = list(string)
}

variable "libvirt_networks" {
  description = "Parameters of libvirt network connections if a libvirt networks are used."
  type = list(object({
    network_name = string
    network_id = string
    prefix_length   = optional(number)
    ip              = optional(string)
    mac             = optional(string)
    gateway         = optional(string)
    dns_servers = optional(list(string), [])
    search_domains = optional(list(string), [])
    dhcp_identifier = optional(string,"duid")
    dhcp4_overrides = optional(object({
      use_dns     = optional(bool)
      use_mtu     = optional(bool)
      use_domains = optional(string)
    }))
    wait_for_lease = optional(bool,false)
  }))
  default = []
}

variable "macvtap_interfaces" {
  description = "List of macvtap interfaces."
  type        = list(object({
    interface = string,
    prefix_length = optional(number),
    ip  = optional(string),
    mac = optional(string),
    gateway = optional(string),
    dns_servers = optional(list(string), [])
    search_domains = optional(list(string), [])
    dhcp_identifier = optional(string,"duid")
    dhcp4_overrides = optional(object({
      use_dns     = optional(bool)
      use_mtu     = optional(bool)
      use_domains = optional(string)
    }))
    wait_for_lease = optional(bool,false)
  }))
  default = []
}

variable "cloud_init_volume_pool" {
  description = "Name of the volume pool that will contain the cloud init volume"
  type        = string
}

variable "cloud_init_volume_name" {
  description = "Name of the cloud init volume"
  type        = string
  default = ""
}

variable "ssh_admin_user" { 
  description = "Pre-existing ssh admin user of the image"
  type        = string
  default     = "ubuntu"
}

variable "admin_user_password" { 
  description = "Optional password for admin user"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_admin_public_key" {
  description = "Public ssh part of the ssh key the admin will be able to login as"
  type        = string
}

variable "cloud_init_configurations" {
  description = "List of cloud-init configurations to add to the vm"
  type        = list(object({
    filename = string
    content  = string
  }))
  default = []
}

variable "hostname" {
  description = "Value to assign to the hostname. If left to empty (default), 'name' variable will be used."
  type        = object({
    hostname = string
    is_fqdn  = string
  })
  default = {
    hostname = ""
    is_fqdn  = false
  }
}

variable "qemu_agent" {
  description = "Whether to install and enable the use of qemu_agent in the vm"
  type        = bool
  default     = true
}

variable "running" {
  description = "Whether the vm should be running or stopped"
  type        = bool
  default     = true
}

variable "autostart" {
  description = "Whether the vm should start on host boot up"
  type        = bool
  default     = true
}

variable "gpus" {
  description = "List of host gpus to pass to the vm"
  type = list(object({
    domain   = string
    bus      = string
    slot     = string
    function = string
  }))
  default = []
}

variable "gpus_pci" {
  description = "List of gpus to pass to the vm by specifying their pci"
  type = list(string)
  default = []
}

variable "domain_graphics_type" {
  description = "Domain graphics type to use. It can be either vnc or spice. Default is vnc"
  type = string
  default = "vnc"
}

variable "network_perf_tuning" {
  description = "Parameters injected into the libvirt domain XSLT that tunes the network interface. Only interface type=network is supported."
  type = list(object({
    network_type = optional(string,"network")
    network_name  = string
    vhost_queues = optional(number)
  }))
  default = []
  # Only allow interface type=network (since your XSLT matches only that)
  validation {
    condition     = alltrue([for p in var.network_perf_tuning : lower(trimspace(p.network_type)) == "network"])
    error_message = "network_perf_tuning[*].network_type must be exactly \"network\"."
  }
  # vhost_queues: allow null/omitted, otherwise must be <= vCPU AND <= 8
  validation {
    condition = alltrue([
      for p in var.network_perf_tuning :
      p.vhost_queues == null || ( p.vhost_queues >= 1 && p.vhost_queues <= min(var.vcpus, 8))
    ])
    error_message = "network_perf_tuning[*].vhost_queues must be null/omitted, or between 1 and min(vcpu_count, 8)."
  }
}

variable "machine" {
  description = "The machine type, you normally won't need to set this unless you are running on a platform that defaults to the wrong machine type for your template"
  type = string
  validation {
    condition     = var.machine == "" || var.machine == "q35"
    error_message = "machine can only be empty or have q35 as value."
  }
  default = ""
}

variable "timeouts" {
  description = "Terraform resource timeouts defining how long terraform should wait for domain create operation to complete before failing."
  type = object({
    create = string
  })
  default = {
    create = "5m"
  }
}