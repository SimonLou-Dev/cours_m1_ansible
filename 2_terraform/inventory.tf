locals {
  all_groups = toset(flatten([for vm in local.vms : vm.groups]))

  # IP résolue (priorité décroissante) :
  #  1. vm.ip explicite dans infra.yaml (pas de masque)
  #  2. vm.network.ip statique cloud-init (CIDR → on enlève le masque)
  #  3. guest-agent (qemu-ga) : DHCP ou pas de cloud-init
  vm_ips = {
    for name, vm in local.vms : name => (
      try(vm.ip, null) != null
        ? vm.ip
        : try(vm.network.ip, "dhcp") != "dhcp"
          ? split("/", vm.network.ip)[0]
          : try(
              flatten([
                for idx, iface in proxmox_virtual_environment_vm.vms[name].network_interface_names :
                proxmox_virtual_environment_vm.vms[name].ipv4_addresses[idx]
                if iface != "lo"
              ])[0],
              "unknown"
            )
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
              ansible_host            = local.vm_ips[name]
              ansible_user            = var.ssh_user
              ansible_password        = var.ssh_password
              ansible_become_password = var.ssh_password
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
