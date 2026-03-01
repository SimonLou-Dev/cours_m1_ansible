# Proxmox : Packer → Terraform → Ansible

Pipeline d'automatisation complète pour déployer et configurer des VMs sur Proxmox.

```
1_packer/     → Build des templates VM (Alpine, Ubuntu, Fedora)
2_terraform/  → Provisioning des VMs depuis infra.yaml
3_ansible/    → Configuration post-déploiement
4_openwrt/    → Déploiement et configuration des VMs OpenWrt (proxmoxer)
scripts/      → Outils de préparation (template OpenWrt)
infra.yaml    → Source de vérité unique
```

---

## Prérequis Proxmox

### Rôle et token Packer

```bash
pveum role add Packer -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt VM.Snapshot VM.GuestAgent Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit"

pveum user add packer@pve --password <password>
pveum aclmod / -user packer@pve -role Packer
pveum user token add packer@pve packer -expire 0 -privsep 0 -comment "Packer token"
```

### Rôle et token Terraform

```bash
pveum role add Terraform -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"

pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Terraform
pveum user token add terraform@pve terraform -expire 0 -privsep 0 -comment "Terraform token"
```

### Credentials (`.secrets` — gitignored)

```bash
cp .secrets.example .secrets
# Remplir les tokens dans .secrets
```

```ini
PKR_VAR_proxmox_api_token_secret=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TF_VAR_proxmox_api_url=https://172.16.0.111:8006
TF_VAR_proxmox_token_secret=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
TF_VAR_ssh_user=esgi
TF_VAR_ssh_password=esgi
```

---

## 1. Packer — Build des templates VM

### Templates produits

| VM ID | Nom | OS |
|-------|-----|----|
| 90101 | `pkr-alpine-3.21.2` | Alpine Linux 3.21 |
| 90102 | `pkr-ubuntu-22.04.3` | Ubuntu Server 22.04 |
| 90103 | `pkr-fedora-41-1.4` | Fedora Server 41 |

### Structure

```
1_packer/
├── versions.pkr.hcl       # Plugin proxmox ~> 1.1.6
├── variables.pkr.hcl      # Variables partagées (credentials, user)
├── alpine.pkr.hcl         # Template Alpine  (VMID 90101)
├── ubuntu.pkr.hcl         # Template Ubuntu  (VMID 90102)
├── fedora.pkr.hcl         # Template Fedora  (VMID 90103)
└── http/alpine/answers    # Réponses automatisées setup-alpine
```

### ISOs requis dans `local:iso/` sur Proxmox

```bash
wget -P /var/lib/vz/template/iso/ https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.2-x86_64.iso
wget -P /var/lib/vz/template/iso/ https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso
wget -P /var/lib/vz/template/iso/ https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-dvd-x86_64-41-1.4.iso
```

### Build

```bash
cd 1_packer/
packer init .

# Un seul template
packer build -only "alpine.*" -var "proxmox_api_token_secret=<token>" .
packer build -only "ubuntu.*" -var "proxmox_api_token_secret=<token>" .
packer build -only "fedora.*" -var "proxmox_api_token_secret=<token>" .

# Tous les templates séquentiellement
packer build -only "alpine.*" -var "proxmox_api_token_secret=<token>" . && \
packer build -only "ubuntu.*" -var "proxmox_api_token_secret=<token>" . && \
packer build -only "fedora.*" -var "proxmox_api_token_secret=<token>" .
```

> VM orpheline après un build raté :
> ```bash
> qm destroy 90101 && qm destroy 90102 && qm destroy 90103
> ```

---

## 2. Terraform — Provisioning

### Source de vérité : `infra.yaml`

`infra.yaml` à la racine du projet définit toute l'infrastructure. Terraform le lit via `yamldecode()`.

```yaml
proxmox:
  node: pve-a-2       # nœud par défaut (surchargeable par VM)
  storage: local-lvm  # storage par défaut (surchargeable par VM)

vms:
  - name: web-01
    template: pkr-ubuntu-22.04.3
    vmid: 200
    cores: 2
    memory: 2048
    disk: 20G
    cloudinit: true         # active le bloc cloud-init Terraform
    node: pve-a-1           # optionnel : surcharge le nœud global
    storage: zfs-pool       # optionnel : surcharge le storage global
    network:
      ip: 172.16.0.10/24    # IP fixe ou "dhcp"
      gateway: 172.16.0.1
    groups:                 # groupes Ansible générés dans inventory.yaml
      - nginx

```

**Champs `vms` :**

| Champ | Requis | Description |
|-------|--------|-------------|
| `name` | ✅ | Nom de la VM |
| `template` | ✅ | Nom du template Packer |
| `vmid` | ✅ | VMID Proxmox unique |
| `cores` | ✅ | Nombre de vCPU |
| `memory` | ✅ | RAM en MB |
| `disk` | ✅ | Taille disque (ex: `20G`) |
| `cloudinit` | ✅ | `true` pour Ubuntu, `false` pour Alpine/Fedora |
| `network.ip` | ✅ | IP CIDR ou `dhcp` |
| `network.gateway` | si ip fixe | Gateway |
| `node` | ❌ | Override nœud Proxmox |
| `storage` | ❌ | Override storage Proxmox |
| `groups` | ❌ | Groupes Ansible dans l'inventaire |

### Structure Terraform

```
2_terraform/
├── versions.tf    # Provider bpg/proxmox ~> 0.66 + hashicorp/local
├── variables.tf   # URL, token, ssh user/password
├── main.tf        # VMs depuis infra.yaml → proxmox_virtual_environment_vm
└── inventory.tf   # Génère 3_ansible/inventory.yaml
```

> Les VMs OpenWrt sont gérées via `4_openwrt/deploy.py` (proxmoxer), pas via Terraform.

### Run

```bash
cd 2_terraform/
tofu init
tofu plan
tofu apply
```

### Inventaire Ansible généré automatiquement

`tofu apply` écrit `3_ansible/inventory.yaml` depuis les groupes définis dans `infra.yaml` :

```yaml
all:
  children:
    nginx:
      hosts:
        web-01:
          ansible_host: 172.16.0.10
          ansible_user: esgi
        web-02:
          ansible_host: 172.16.0.11
          ansible_user: esgi
    mysql:
      hosts:
        db-01:
          ansible_host: 172.16.0.20
          ansible_user: esgi
```

---

## 3. Ansible — Configuration

```bash
cd 3_ansible/
ansible-playbook playbook.yaml
```

L'inventaire `3_ansible/inventory.yaml` est généré par Terraform — ne pas l'éditer manuellement.

---

