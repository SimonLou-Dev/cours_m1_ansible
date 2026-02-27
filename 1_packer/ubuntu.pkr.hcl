source "proxmox-iso" "pkr-ubuntu-1" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                     = "pve-a-2"
  vm_id                    = "90102"
  vm_name                  = "pkr-ubuntu-22.04.3"
  template_description     = "Ubuntu Server 22.04 - built by Packer"

  iso_file                 = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
  iso_storage_pool         = "local"
  unmount_iso              = true
  qemu_agent               = true

  scsi_controller          = "virtio-scsi-pci"
  cores                    = "2"
  sockets                  = "1"
  memory                   = "2048"

  vga {
    type = "virtio"
  }

  disks {
    disk_size    = "10G"
    format       = "raw"
    storage_pool = "local-lvm"
    type         = "virtio"
  }

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    firewall = "false"
  }

  # Ubuntu live server : grub command line pour injecter autoinstall
  boot_command = [
    "<wait5>",
    "c<wait3>",
    "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ubuntu/ ---<enter><wait3>",
    "initrd /casper/initrd<enter><wait3>",
    "boot<enter>"
  ]

  boot                   = "c"
  boot_wait              = "5s"
  communicator           = "ssh"
  http_content = {
    "/ubuntu/user-data" = <<-EOF
      #cloud-config
      autoinstall:
        version: 1
        locale: fr_FR.UTF-8
        keyboard:
          layout: fr
        network:
          network:
            version: 2
            ethernets:
              ens18:
                dhcp4: true
        storage:
          layout:
            name: direct
        identity:
          hostname: ubuntu-server
          username: ${var.custom_user}
          password: "$6$packer$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        ssh:
          install-server: true
          allow-pw: true
        packages:
          - qemu-guest-agent
          - sudo
        late-commands:
          - echo '${var.custom_user}:${var.custom_password}' | chpasswd --root /target
          - echo '${var.custom_user} ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/${var.custom_user}
          - chmod 440 /target/etc/sudoers.d/${var.custom_user}
          - curtin in-target -- systemctl enable qemu-guest-agent
      EOF
    "/ubuntu/meta-data" = "instance-id: ubuntu-server\nlocal-hostname: ubuntu-server\n"
  }
  http_port_min          = 8098
  http_port_max          = 8108
  ssh_username           = var.custom_user
  ssh_password           = var.custom_password
  ssh_timeout            = "30m"
  ssh_pty                = true
  ssh_handshake_attempts = 30
}

build {
  name    = "ubuntu"
  sources = ["source.proxmox-iso.pkr-ubuntu-1"]

  provisioner "shell" {
    inline = [
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt-get -y autoremove --purge",
      "sudo apt-get -y clean",
      "sudo cloud-init clean",
      "sudo sync"
    ]
  }
}
