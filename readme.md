# Proxmox : Packer → Terraform → Ansible

Pipeline d'automatisation complète pour déployer et configurer des VMs sur Proxmox.

```
1_packer/     → Build des templates VM (Alpine, Ubuntu, Fedora)
2_terraform/  → Provisioning des VMs depuis les templates (à venir)
3_ansible/    → Configuration des VMs (à venir)
```

---

## Prérequis Proxmox

### Création du rôle et du token Packer

```bash
# Création du rôle avec les permissions nécessaires
pveum role add Packer -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt VM.Snapshot VM.GuestAgent Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit"

# Création de l'utilisateur
pveum user add packer@pve --password <password>

# Assignation du rôle
pveum aclmod / -user packer@pve -role Packer

# Création du token
pveum user token add packer@pve packer -expire 0 -privsep 0 -comment "Packer token"
```

### ISOs requis (à uploader dans `local:iso/` sur le nœud Proxmox)

| Template | ISO |
|----------|-----|
| Alpine   | `alpine-virt-3.21.2-x86_64.iso` |
| Ubuntu   | `ubuntu-22.04.3-live-server-amd64.iso` |
| Fedora   | `Fedora-Server-dvd-x86_64-41-1.4.iso` |

```bash
# Depuis le nœud Proxmox
wget -P /var/lib/vz/template/iso/ https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.2-x86_64.iso
wget -P /var/lib/vz/template/iso/ https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso
wget -P /var/lib/vz/template/iso/ https://download.fedoraproject.org/pub/fedora/linux/releases/41/Server/x86_64/iso/Fedora-Server-dvd-x86_64-41-1.4.iso
```

---

## 1. Packer — Build des templates

### Structure

```
1_packer/
├── versions.pkr.hcl       # Plugin proxmox requis
├── variables.pkr.hcl      # Variables partagées (credentials, user)
├── alpine.pkr.hcl         # Template Alpine 3.21 (VM ID 90101)
├── ubuntu.pkr.hcl         # Template Ubuntu 22.04 (VM ID 90102)
├── fedora.pkr.hcl         # Template Fedora 41   (VM ID 90103)
└── http/
    └── alpine/
        └── answers        # Fichier de réponses setup-alpine
```

### Variables

| Variable | Défaut | Description |
|----------|--------|-------------|
| `proxmox_api_url` | `https://172.16.0.111:8006/api2/json` | URL de l'API Proxmox |
| `proxmox_api_token_id` | `packer@pve!packer` | ID du token API |
| `proxmox_api_token_secret` | *(requis)* | Secret du token API |
| `root_password` | `password` | Mot de passe root (Alpine) |
| `custom_user` | `esgi` | Utilisateur créé dans les templates |
| `custom_password` | `esgi` | Mot de passe de cet utilisateur |

### Build

```bash
cd 1_packer/
packer init .

# Build d'un seul template
packer build -only "alpine.*" -var "proxmox_api_token_secret=<token>" .
packer build -only "ubuntu.*" -var "proxmox_api_token_secret=<token>" .
packer build -only "fedora.*" -var "proxmox_api_token_secret=<token>" .

# Build de tous les templates
packer build -var "proxmox_api_token_secret=<token>" .
```

> Si un build précédent a échoué et laissé une VM orpheline :
> ```bash
> qm destroy 90101  # Alpine
> qm destroy 90102  # Ubuntu
> qm destroy 90103  # Fedora
> ```

---

## 2. Terraform — Provisioning (à venir)

Le Terraform utilisera un fichier `infra.yaml` comme source de vérité pour cloner les templates et générer l'inventaire Ansible.

### Exemple `infra.yaml`

```yaml
proxmox:
  node: pve-a-2
  storage: local-lvm

vms:
  - name: web-01
    template: pkr-ubuntu-22.04.3
    cores: 2
    memory: 2048
    disk: 20G
    network:
      ip: 172.16.0.10/24
      gateway: 172.16.0.1
    groups:
      - nginx
      - monitoring

  - name: web-02
    template: pkr-ubuntu-22.04.3
    cores: 2
    memory: 2048
    disk: 20G
    network:
      ip: dhcp
    groups:
      - nginx

  - name: db-01
    template: pkr-fedora-41-1.4
    cores: 4
    memory: 4096
    disk: 50G
    network:
      ip: 172.16.0.20/24
      gateway: 172.16.0.1
    groups:
      - mysql

  - name: proxy-01
    template: pkr-alpine-3.21.2
    cores: 1
    memory: 512
    disk: 5G
    network:
      ip: 172.16.0.5/24
      gateway: 172.16.0.1
    groups:
      - nginx
      - haproxy
```

Les groupes définis dans `infra.yaml` sont automatiquement repris comme groupes Ansible dans l'inventaire généré.

---

## 3. Ansible — Configuration (à venir)

```bash
cd 3_ansible/
ansible-playbook playbook.yaml
```
