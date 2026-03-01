locals {
  infra = yamldecode(file("${path.module}/../infra.yaml"))
  vms   = { for vm in local.infra.vms : vm.name => vm }

  # Mapping nom du template → VM ID Proxmox (défini dans Packer)
  template_ids = {
    "pkr-alpine-3.21.2"  = 90101
    "pkr-ubuntu-22.04.3" = 90102
    "pkr-fedora-41-1.4"  = 90103
  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each = local.vms

  name      = each.key
  node_name = try(each.value.node, local.infra.proxmox.node)
  vm_id     = each.value.vmid

  clone {
    vm_id = local.template_ids[each.value.template]
    full  = true
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = try(each.value.storage, local.infra.proxmox.storage)
    interface    = "virtio0"
    size         = tonumber(replace(each.value.disk, "G", ""))
    discard      = "on"
  }

  network_device {
    model  = "virtio"
    bridge = "vmbr0"
  }

  agent {
    enabled = true
  }

  # Bloc cloud-init uniquement pour les templates qui le supportent (Ubuntu)
  dynamic "initialization" {
    for_each = try(each.value.cloudinit, false) ? [1] : []

    content {
      ip_config {
        ipv4 {
          address = each.value.network.ip == "dhcp" ? "dhcp" : each.value.network.ip
          gateway = each.value.network.ip == "dhcp" ? null : try(each.value.network.gateway, null)
        }
      }
      user_account {
        username = var.ssh_user
        password = var.ssh_password
      }
    }
  }
}
