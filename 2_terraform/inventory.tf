locals {
  all_groups = toset(flatten([for vm in local.vms : vm.groups]))

  # IP résolue : fixe depuis infra.yaml (sans le masque) ou DHCP via guest-agent
  vm_ips = {
    for name, vm in local.vms : name => (
      vm.network.ip == "dhcp"
        ? try(
            flatten([
              for idx, iface in proxmox_virtual_environment_vm.vms[name].network_interface_names :
              proxmox_virtual_environment_vm.vms[name].ipv4_addresses[idx]
              if iface != "lo"
            ])[0],
            "unknown"
          )
        : split("/", vm.network.ip)[0]
    )
  }
}

resource "local_file" "ansible_inventory" {
  content = yamlencode({
    all = {
      children = {
        for group in local.all_groups : group => {
          hosts = {
            for name, vm in local.vms : name => {
              ansible_host = local.vm_ips[name]
              ansible_user = var.ssh_user
            }
            if contains(vm.groups, group)
          }
        }
      }
    }
  })

  filename        = "${path.module}/../3_ansible/inventory.yaml"
  file_permission = "0644"
}
