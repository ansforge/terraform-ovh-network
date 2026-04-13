# 🛡️ terraform-ovh-security

**Déploiement des firewalls Stormshield sur OVH Cloud via Terraform — ANS Forge**

Ce dépôt Terraform provisionne et gère les instances de firewalls **Stormshield** (appliance virtuelle) sur OVH Public Cloud / OpenStack. Il gère la création dynamique des clés SSH, des ports réseau multi-interfaces, et des instances avec attachement automatique aux VLANs vRack.

---

## 📑 Table des matières

- [Architecture](#-architecture)
- [Prérequis](#-prérequis)
- [Arborescence du projet](#-arborescence-du-projet)
- [Branches et environnements](#-branches-et-environnements)
- [Providers utilisés](#-providers-utilisés)
- [Module security](#-module-security)
- [Variables](#-variables)
- [Inventaire des firewalls](#-inventaire-des-firewalls)
- [Backend S3 (state distant)](#-backend-s3-state-distant)
- [Commandes de lancement](#-commandes-de-lancement)
- [Commandes de test et vérification](#-commandes-de-test-et-vérification)
- [Gestion des secrets (Vault)](#-gestion-des-secrets-vault)
- [Ajouter / modifier un firewall](#-ajouter--modifier-un-firewall)
- [Récupérer la clé SSH d'un firewall](#-récupérer-la-clé-ssh-dun-firewall)
- [Dépannage](#-dépannage)
- [Contribution](#-contribution)

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HashiCorp Vault                               │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │ iacrunner-*/openstack_key                                    │   │
│  │ (OS_AUTH_URL, OS_APPLICATION_CREDENTIAL_ID/SECRET)           │   │
│  ���──────────────────────────────────────────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ lecture (ephemeral)
                                 ▼
┌────────────────────────────────────────────────────────────────────┐
│                     Terraform (ce repo)                            │
│                                                                    │
│  main.tf ──► module "stormshield_cluster" (for_each = firewalls)   │
│               └── modules/security/                                │
│                    ├── tls_private_key (RSA 4096)                  │
│                    ├── openstack_compute_keypair_v2                 │
│                    ├── data openstack_networking_network_v2         │
│                    ├── openstack_networking_port_v2 (multi-NIC)    │
│                    └── openstack_compute_instance_v2 (Stormshield) │
└────────────────────────────────┬───────────────────────────────────┘
                                 │
                                 ▼
┌────────────────────────────────────────────────────────────────────┐
│                     OVH Public Cloud / OpenStack                   │
│                                                                    │
│  ┌──────────────┐  ┌──────────────────┐  ┌─────────────────────┐  │
│  │ Stormshield  │  │ Stormshield      │  │ Ports réseau        │  │
│  │ fwfe01       │  │ fwfe02 (slave)   │  │ (multi-interface)   │  │
│  │ (master)     │  │                  │  │ port_security=false │  │
│  └──────┬───────┘  └──────┬───────────┘  └─────────────────────┘  │
│         │                  │                                       │
│    ┌────▼──────────────────▼────────┐                              │
│    │         VLANs vRack            │                              │
│    │  front / admin / dmz / interco │                              │
│    │  vpn / k8s / infra / app       │                              │
│    └────────────────────────────────┘                              │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📋 Prérequis

| Outil | Version | Description |
|---|---|---|
| **Terraform** | ≥ 1.10 | Infrastructure as Code (support `ephemeral` resources) |
| **HashiCorp Vault** | Accès actif | Credentials OpenStack |
| **OVH Public Cloud** | Projet actif | Avec vRack et réseaux déjà créés (`terraform-ovh-network`) |
| **Image Stormshield** | Uploadée dans OpenStack | Image QCOW2 du firewall virtuel |

### Variables d'environnement requises

```bash
# Vault
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="hvs.xxxxx"

# Backend S3 (pour le state Terraform)
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"
```

> ⚠️ Les credentials OpenStack sont lus depuis **Vault** via des `ephemeral` resources. Aucune variable d'environnement OpenStack n'est nécessaire.

---

## 🗂️ Arborescence du projet

```
terraform-ovh-security/
├── main.tf                          # Providers, appel module stormshield_cluster, outputs
├── backend.tf                       # Configuration backend S3 distant (tfstate)
├── variables.tf                     # Variables racine (region, firewalls)
├── security.tfvars                  # Définition des firewalls et de leurs interfaces réseau
├── .gitignore                       # Exclusion .terraform/, *.tfstate*, *.pem
├── modules/
│   └── security/
│       ├── main.tf                  # Ressources : clé SSH, keypair, ports, instance
│       ├── variables.tf             # Variables du module (name, flavor, image, networks, tags)
│       └── output.tf                # Outputs : private_key_pem, instance_id
└── README.md
```

---

## 🌿 Branches et environnements

| Branche | Environnement | Vault Mount | Région OVH | Firewalls | Bucket tfstate |
|---|---|---|---|---|---|
| `amont` | Pré-production | `iacrunner-amont` | `SBG5` | 1 FW (master) | `infra-amont-sto-object-tf01` |
| `prod` | Production | `iacrunner-prod` | `RBX-A` | 2 FW (master + slave HA) | `infra-prod-sto-object-tf01` |
| `main` | — | — | — | — | Branche par défaut (documentation) |

### Différences clés entre branches

| Paramètre | `amont` | `prod` |
|---|---|---|
| `region` | `SBG5` | `RBX-A` |
| Nombre de firewalls | 1 (`fwfe01` master) | 2 (`fwfe01` master + `fwfe02` slave) |
| Réseau HA | Non | Oui (`fwfe-ha` VLAN 121) |
| Réseau public | `10.12.0.0/24` (front privé) | `5.135.49.0/25` (IP publiques) |
| Préfixe nommage | `infra-amont-*` | `infra-prod-*` |
| Préfixe réseaux | `preprod-amont-*` | `prod-production-*` |

---

## 🔌 Providers utilisés

| Provider | Source | Version | Usage |
|---|---|---|---|
| **openstack** | `terraform-provider-openstack/openstack` | `>= 1.53.0` | Instances, ports, keypairs, réseaux |
| **vault** | `hashicorp/vault` | `>= 3.25.0` | Lecture des credentials OpenStack (ephemeral) |
| **ovh** | `ovh/ovh` | `>= 0.40.0` | Déclaré pour compatibilité |
| **tls** | `hashicorp/tls` | latest | Génération dynamique des clés SSH RSA 4096 |

---

## 📦 Module security

### `modules/security/`

Module qui provisionne une instance firewall Stormshield complète avec toutes ses interfaces réseau.

#### Ressources créées (par firewall)

| # | Ressource | Type | Description |
|---|---|---|---|
| 1 | `tls_private_key.instance_key` | Clé SSH | Génération RSA 4096 bits (dynamique, pas de fichier PEM sur disque) |
| 2 | `openstack_compute_keypair_v2.instance_kp` | Keypair OpenStack | Enregistrement de la clé publique dans OpenStack |
| 3 | `openstack_networking_network_v2.networks` | Data source | Résolution des réseaux par nom → UUID OpenStack |
| 4 | `openstack_networking_port_v2.ports` | Port réseau | Création d'un port par interface avec IP fixe et `port_security_enabled = false` |
| 5 | `openstack_compute_instance_v2.fw` | Instance | VM Stormshield avec injection dynamique des ports réseau |

#### Points techniques importants

- **`port_security_enabled = false`** : Obligatoire pour Stormshield — le firewall doit pouvoir router/NAT du trafic avec des IP sources différentes de l'IP du port
- **Clé SSH dynamique** : Chaque firewall reçoit sa propre clé RSA 4096 générée par Terraform (pas de clé partagée)
- **Multi-NIC** : Les interfaces réseau sont injectées via un bloc `dynamic "network"` qui itère sur les ports créés
- **Filtrage `enabled`** : Seuls les réseaux avec `enabled = true` sont attachés — permet de désactiver une interface sans la supprimer

#### Variables du module

| Variable | Type | Description |
|---|---|---|
| `name` | `string` | Nom de l'instance firewall |
| `flavor` | `string` | UUID du flavor OpenStack (taille de la VM) |
| `image` | `string` | UUID de l'image Stormshield (QCOW2) |
| `region` | `string` | Région OVH (SBG5, RBX-A) |
| `networks` | `list(object)` | Liste des interfaces réseau (voir structure ci-dessous) |
| `tags` | `map(string)` | Métadonnées de l'instance (Owner, Env, Role) |

#### Structure d'une interface réseau

```hcl
networks = [
  {
    name    = "prod-production-dmz-exposed-10.11.30.0-24"  # Nom du réseau OpenStack
    ip      = "10.11.30.251"                                # IP fixe du firewall
    enabled = true                                          # Interface active
  }
]
```

#### Outputs du module

| Output | Sensible | Description |
|---|---|---|
| `private_key_pem` | **Oui** | Clé privée SSH RSA du firewall (format PEM) |
| `instance_id` | Non | UUID OpenStack de l'instance |

---

## 📝 Variables

### Variables racine (`variables.tf`)

| Variable | Type | Description |
|---|---|---|
| `region` | `string` | Région OVH Public Cloud |
| `firewalls` | `map(object)` | Map des firewalls à déployer |

### Structure d'un firewall

```hcl
variable "firewalls" {
  type = map(object({
    name     = string                # Nom de l'instance
    flavor   = string                # UUID du flavor
    image    = string                # UUID de l'image Stormshield
    networks = list(object({         # Interfaces réseau
      name    = string
      ip      = string
      enabled = bool
    }))
    tags = map(string)               # Métadonnées (Owner, Env, Role)
  }))
}
```

---

## 🔥 Inventaire des firewalls

### Production (`prod` — `RBX-A`) : Cluster HA Master/Slave

#### fwfe01 — Master

| Interface | Réseau | VLAN | IP | Usage |
|---|---|---|---|---|
| eth0 | app-front | 300 | `10.13.0.251` | Front applicatif |
| eth1 | k8s-front | 160 | `10.11.60.251` | Kubernetes front |
| eth2 | dmz-transit | 170 | `10.11.70.251` | Transit DMZ (proxy Squid) |
| eth3 | dmz-exposed | 130 | `10.11.30.251` | DMZ exposée (SSH proxy) |
| eth4 | vrack-vpn | 110 | `10.11.10.251` | VPN vRack |
| eth5 | fw-interco | 140 | `172.16.21.29` | Interconnexion firewalls |
| eth6 | fwfe-ha | 121 | `172.16.21.45` | Haute disponibilité |
| eth7 | fwfe-admin | 120 | `10.11.20.251` | Administration firewall |
| eth8 | fw-front | 0 | `5.135.49.96` | Interface publique |

**Tags** : `Owner=infra-team`, `Env=prod`, `Role=master`

#### fwfe02 — Slave

| Interface | Réseau | VLAN | IP | Usage |
|---|---|---|---|---|
| eth0 | app-front | 300 | `10.13.0.252` | Front applicatif |
| eth1 | k8s-front | 160 | `10.11.60.252` | Kubernetes front |
| eth2 | dmz-transit | 170 | `10.11.70.252` | Transit DMZ |
| eth3 | dmz-exposed | 130 | `10.11.30.252` | DMZ exposée |
| eth4 | vrack-vpn | 110 | `10.11.10.252` | VPN vRack |
| eth5 | fw-interco | 140 | `172.16.21.28` | Interconnexion firewalls |
| eth6 | fwfe-ha | 121 | `172.16.21.44` | Haute disponibilité |
| eth7 | fwfe-admin | 120 | `10.11.20.252` | Administration firewall |
| eth8 | fw-front | 0 | `5.135.49.97` | Interface publique |

**Tags** : `Owner=infra-team`, `Env=prod`, `Role=slave`

### Pré-production (`amont` — `SBG5`) : Instance unique

#### fwfe01 — Master

| Interface | Réseau | VLAN | IP | Usage |
|---|---|---|---|---|
| eth0 | fwfe-front | 0 | `10.12.0.251` | Front firewall |
| eth1 | fwfe-admin | 220 | `10.12.20.251` | Administration |
| eth2 | dmz-exposed | 230 | `10.12.30.251` | DMZ exposée |
| eth3 | dmz-transit | 270 | `10.12.70.251` | Transit DMZ |
| eth4 | infra-app | 290 | `10.12.90.251` | Infrastructure applicative |
| eth5 | k8s-front | 260 | `10.12.60.251` | Kubernetes front |
| eth6 | vrack-vpn | 210 | `10.12.10.251` | VPN vRack |
| eth7 | fw-interco | 240 | `172.16.31.29` | Interconnexion firewalls |

**Tags** : `Owner=infra-team`, `Env=amont`, `Role=master`

---

## 💾 Backend S3 (state distant)

### Branche `amont`

```hcl
terraform {
  backend "s3" {
    bucket = "infra-amont-sto-object-tf01"
    key    = "infra-amont-security.tfstate"
    region = "sbg"
    endpoints = { s3 = "https://s3.sbg.io.cloud.ovh.net/" }
  }
}
```

### Branche `prod`

```hcl
terraform {
  backend "s3" {
    bucket = "infra-prod-sto-object-tf01"
    key    = "infra-production-security.tfstate"
    region = "rbx"
    endpoints = { s3 = "https://s3.rbx.io.cloud.ovh.net/" }
  }
}
```

---

## 🚀 Commandes de lancement

### Déploiement standard

```bash
# 1. Se positionner sur la branche de l'environnement
git checkout amont   # ou prod

# 2. Configurer les variables d'environnement
export VAULT_ADDR="https://vault.example.com"
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"

# 3. Initialiser Terraform
terraform init

# 4. Planifier les changements
terraform plan -var-file="security.tfvars"

# 5. Appliquer les changements
terraform apply -var-file="security.tfvars"
```

### Cibler un firewall spécifique

```bash
# Planifier uniquement le firewall master
terraform plan -var-file="security.tfvars" \
  -target='module.stormshield_cluster["fwfe01"]'

# Appliquer uniquement le firewall slave
terraform apply -var-file="security.tfvars" \
  -target='module.stormshield_cluster["fwfe02"]'
```

### Destruction

```bash
# Détruire un firewall spécifique
terraform destroy -var-file="security.tfvars" \
  -target='module.stormshield_cluster["fwfe02"]'

# Détruire tout (⚠️ DANGER — coupe le réseau)
terraform destroy -var-file="security.tfvars"
```

> ⚠️ **ATTENTION** : La destruction d'un firewall en production coupe tout le routage inter-VLAN et l'accès Internet. Toujours tester sur `amont` avant.

---

## 🧪 Commandes de test et vérification

```bash
# Valider la syntaxe
terraform validate

# Formater le code
terraform fmt -check -recursive
terraform fmt -recursive

# Lister les ressources dans le state
terraform state list

# Afficher le détail d'un firewall
terraform state show 'module.stormshield_cluster["fwfe01"].openstack_compute_instance_v2.fw'

# Afficher les ports réseau d'un firewall
terraform state list | grep 'fwfe01.*port'

# Afficher les outputs
terraform output
terraform output fw_instance_ids

# Planifier en mode détaillé
terraform plan -var-file="security.tfvars" -detailed-exitcode
# Exit code 0 = pas de changement
# Exit code 2 = changements détectés

# Graphe de dépendances
terraform graph | dot -Tpng > security-graph.png
```

### Vérification côté OpenStack

```bash
# Lister les instances
openstack server list

# Détail d'un firewall
openstack server show infra-prod-fwfe01

# Lister les ports d'un firewall
openstack port list --server infra-prod-fwfe01

# Vérifier les interfaces réseau
openstack server show infra-prod-fwfe01 -f json | jq '.addresses'
```

---

## 🔐 Gestion des secrets (Vault)

### Secrets consommés (en lecture)

| Chemin Vault | Clés | Provenance |
|---|---|---|
| `iacrunner-*/openstack_key` | `OS_AUTH_URL`, `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET` | Créé par `terraform-ovh-storage` |

> **Note** : Ce repo n'utilise **pas** les credentials OVH API (`ovh_key`). Seul le provider OpenStack est utilisé pour créer les instances.

### Vérification Vault

```bash
vault kv get iacrunner-amont/openstack_key
vault kv get iacrunner-prod/openstack_key
```

---

## 🔑 Récupérer la clé SSH d'un firewall

Les clés SSH sont générées dynamiquement par Terraform et stockées dans le state (marquées `sensitive`).

```bash
# Afficher la clé privée du firewall master
terraform output -raw fw_private_keys | jq -r '.fwfe01'

# Sauvegarder dans un fichier
terraform output -json fw_private_keys | jq -r '.fwfe01' > fwfe01.pem
chmod 600 fwfe01.pem

# Se connecter au firewall (via le réseau admin)
ssh -i fwfe01.pem admin@10.11.20.251
```

> ⚠️ Ne jamais commiter les fichiers `.pem`. Ils sont exclus par le `.gitignore`.

---

## ➕ Ajouter / modifier un firewall

### Ajouter un nouveau firewall

1. Éditer `security.tfvars` et ajouter une entrée dans la map `firewalls` :

```hcl
firewalls = {
  # ... firewalls existants ...

  "fwbe01" = {
    name   = "infra-prod-fwbe01"
    flavor = "58a6c33c-8c3d-4a94-8d03-2153139832b8"   # UUID du flavor
    image  = "042e000e-55b0-4c3c-8398-60d853d886f5"   # UUID image Stormshield

    networks = [
      { name = "prod-production-fwbe-admin-10.11.50.0-24",   ip = "10.11.50.251", enabled = true },
      { name = "prod-production-fw-interco-172.16.21.16-28", ip = "172.16.21.27", enabled = true },
      { name = "prod-production-infra-app-10.11.90.0-24",    ip = "10.11.90.251", enabled = true },
    ]

    tags = { Owner = "infra-team", Env = "prod", Role = "backend-fw" }
  }
}
```

2. Planifier et vérifier :
```bash
terraform plan -var-file="security.tfvars"
```

3. Appliquer :
```bash
terraform apply -var-file="security.tfvars"
```

### Ajouter une interface réseau à un firewall existant

Ajouter une entrée dans la liste `networks` du firewall concerné :

```hcl
{ name = "prod-production-app-back-10.13.2.0-24", ip = "10.13.2.251", enabled = true },
```

### Désactiver une interface sans la supprimer

Passer `enabled = false` :

```hcl
{ name = "prod-production-vrack-vpn-10.11.10.0-24", ip = "10.11.10.251", enabled = false },
```

---

## 🔧 Dépannage

### Problèmes courants

| Problème | Cause probable | Solution |
|---|---|---|
| `Error: ephemeral resource not supported` | Terraform < 1.10 | Mettre à jour Terraform ≥ 1.10 |
| `Error: 409 Multiple possible networks found` | Ports non injectés correctement | Vérifier que tous les `networks` ont `enabled = true` |
| `Error: No network found with name` | Réseau pas encore créé | Déployer d'abord `terraform-ovh-network` |
| `Error: Unable to create port` | IP déjà utilisée par un autre port | Vérifier les IPs dans `security.tfvars` |
| `Error: port_security_enabled conflict` | Conflit security group / port | S'assurer que `port_security_enabled = false` est bien défini |
| `Error: Quota exceeded` | Plus assez de ressources OVH | Augmenter les quotas dans le Manager OVH |
| Clé SSH perdue | State détruit ou corrompu | Re-créer le firewall (la clé sera régénérée) |

### Commandes de diagnostic

```bash
# Debug complet
TF_LOG=DEBUG terraform plan -var-file="security.tfvars" 2>&1 | tee debug.log

# Vérifier le state
terraform state pull | jq '.resources[] | .type + "." + .name'

# Importer une instance existante
terraform import \
  'module.stormshield_cluster["fwfe01"].openstack_compute_instance_v2.fw' \
  <instance_uuid>

# Importer un port existant
terraform import \
  'module.stormshield_cluster["fwfe01"].openstack_networking_port_v2.ports["prod-production-dmz-exposed-10.11.30.0-24"]' \
  <port_uuid>

# Taint pour forcer la re-création
terraform taint 'module.stormshield_cluster["fwfe01"].openstack_compute_instance_v2.fw'
```

---

## 🤝 Contribution

1. Se positionner sur la branche de l'environnement :
   ```bash
   git checkout amont  # pré-production
   git checkout prod   # production
   ```
2. Créer une branche feature si nécessaire :
   ```bash
   git checkout -b feature/ajout-fwbe amont
   ```
3. Valider avec `terraform validate` et `terraform fmt`
4. Planifier avec `terraform plan` pour vérifier l'impact
5. Créer une Pull Request vers la branche cible

### Conventions

- **Nommage des firewalls** : `infra-<env>-fw<zone><num>` (ex: `infra-prod-fwfe01`)
- **IPs firewall** : `.251` (master), `.252` (slave), `.253` (VIP HA)
- **Clés de map** : `fw<zone><num>` (ex: `fwfe01`, `fwbe01`)
- **Tags obligatoires** : `Owner`, `Env`, `Role`

---

## 🔗 Dépendances et projets liés

| Repo | Relation | Description |
|---|---|---|
| [`terraform-ovh-network`](https://github.com/ansforge/terraform-ovh-network) | **Pré-requis** | Les VLANs/subnets doivent exister avant de déployer les firewalls |
| [`terraform-ovh-storage`](https://github.com/ansforge/terraform-ovh-storage) | **Pré-requis** | Crée les credentials OpenStack utilisés par ce repo |
| [`ansible-ovh`](https://github.com/ansforge/ansible-ovh) | **Post-déploiement** | Configuration des VMs derrière les firewalls |

### Ordre de déploiement global

```
1. terraform-ovh-storage   → Credentials + bucket tfstate
2. terraform-ovh-network   → VLANs et subnets vRack
3. terraform-ovh-security  → Firewalls Stormshield    ← CE REPO
4. terraform-ovh-infra     → VMs (serveurs Linux)
5. ansible-ovh             → Configuration des VMs
```

---

## 📄 Licence

*Non spécifiée — Consulter l'organisation [ANS Forge](https://github.com/ansforge) pour plus d'informations.*

---

> **Maintenu par l'équipe Infrastructure ANS Forge** — Déploiement des firewalls Stormshield sur OVH Cloud avec Terraform + Vault
