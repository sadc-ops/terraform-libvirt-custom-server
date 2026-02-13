terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "=0.8.3"
    }
  }
  required_version = ">= 1.14.0"
}