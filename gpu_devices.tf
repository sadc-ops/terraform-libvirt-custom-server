data "libvirt_node_device_info" "gpu_info" {
  for_each = { for idx, value in var.gpus_pci : value => value }
  name = each.value
}

locals {
  gpu_devices = concat(
    [for gpu in data.libvirt_node_device_info.gpu_info: {
      domain   = gpu.capability[0].iommu_group[0].addresses[0]["domain"],
      bus      = gpu.capability[0].iommu_group[0].addresses[0]["bus"],
      slot     = gpu.capability[0].iommu_group[0].addresses[0]["slot"],
      function = gpu.capability[0].iommu_group[0].addresses[0]["function"]
    }],
    var.gpus
  )
}