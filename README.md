# 🌐 terraform-ovh-network

**Gestion de l'infrastructure réseau OVH Cloud (VLANs, subnets, vRack) via Terraform — ANS Forge**

Ce dépôt Terraform provisionne et gère l'ensemble des réseaux privés (VLANs vRack) et sous-réseaux (subnets OpenStack) sur OVH Public Cloud. Il utilise une approche déclarative basée sur une map de VLANs avec gestion dynamique du DHCP et des gateways.

---

## 📑 Table des matières

- [Architecture réseau](#-architecture-réseau)
- [Prérequis](#-prérequis)
- [Arborescence du projet](#-arborescence-du-projet)
- [Branches et environnements](#-branches-et-environnements)
- [Providers utilisés](#-providers-utilisés)
- [Module network](#-module-network)
- [Variables](#-variables)
- [Plan d'adressage](#-plan-dadressage)
- [Backend S3 (state distant)](#-backend-s3-state-distant)
- [Commandes de lancement](#-commandes-de-lancement)
- [Commandes de test et vérification](#-commandes-de-test-et-vérification)
- [Gestion des secrets (Vault)](#-gestion-des-secrets-vault)
- [Ajouter / modifier un VLAN](#-ajouter--modifier-un-vlan)
- [Dépannage](#-dépannage)
- [Contribution](#-contribution)

---

## 🏗️ Architecture réseau

```
                         ┌───────────────────────┐
                         │    OVH vRack           │
                         │  (Réseau privé L2)     │
                         └──────────┬────────────┘
                                    │
           ┌────────────────────────┼────────────────────────┐
           │                        │                        │
    ┌──────▼──────┐          ┌──────▼──────┐          ┌──────▼──────┐
    │  VLAN 0     │          │  VLAN 1xx   │          │  VLAN 3xx   │
    │  fw_front   │          │  Infra/DMZ  │          │  Applicatif │
    │  (Public)   │          │  (Privé)    │          │  (Privé)    │
    └─────────────┘          └─────────────┘          └─────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │                    Terraform (ce repo)                        │
    │                                                              │
    │  main.tf ──► module "network"                                │
    │               ├── ovh_cloud_project_network_private (VLANs)  │
    │               └── openstack_networking_subnet_v2 (Subnets)   │
    │                                                              │
    │  Secrets : Vault (ephemeral kv_secret_v2)                    │
    │  State   : S3 OVH (backend distant)                          │
    └──────────────────────────────────────────────────────────────┘
```

---

## 📋 Prérequis

| Outil | Version | Description |
|---|---|---|
| **Terraform** | ≥ 1.10 | Infrastructure as Code (support `ephemeral` resources) |
| **HashiCorp Vault** | Accès actif | Secrets OVH et OpenStack |
| **OVH Public Cloud** | Projet actif avec vRack | `service_name` (Project ID) |

### Variables d'environnement requises

```bash
# Vault
export VAULT_ADDR="https://vault.example.com"
export VAULT_TOKEN="hvs.xxxxx"

# Backend S3 (pour le state Terraform)
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"
```

> ⚠️ Les credentials OVH et OpenStack sont lus depuis **Vault** via des `ephemeral` resources (pas de variables d'environnement).

---

## 🗂️ Arborescence du projet

```
terraform-ovh-network/
├── main.tf                          # Point d'entrée : providers + appel module network
├── backend.tf                       # Configuration backend S3 distant (tfstate)
├── variables.tf                     # Variables racine (service_name, region, vlans)
├── network.tfvars                   # Valeurs des variables : définition de tous les VLANs
├── .terraform.lock.hcl              # Verrouillage des versions des providers
├── .gitignore                       # Exclusion .terraform/, *.tfstate*, *.pem
├── modules/
│   └── network/
│       ├── main.tf                  # Ressources : VLANs OVH + Subnets OpenStack
│       ├── variables.tf             # Variables du module
│       └── outputs.tf               # Outputs : UUIDs réseau, subnet IDs, VLAN IDs
└── README.md
```

---

## 🌿 Branches et environnements

| Branche | Environnement | Vault Mount | Région OVH | Adressage | Bucket tfstate |
|---|---|---|---|---|---|
| `amont` | Pré-production | `iacrunner-amont` | `SBG5` (Strasbourg) | `10.12.x.x` / `10.14.x.x` | `infra-amont-sto-object-tf01` |
| `prod` | Production | `iacrunner-prod` | `RBX-A` (Roubaix) | `10.11.x.x` / `10.13.x.x` | `infra-prod-sto-object-tf01` |
| `main` | — | — | — | — | Branche par défaut (documentation) |

### Différences clés entre branches

| Paramètre | `amont` | `prod` |
|---|---|---|
| `service_name` | `a5a3658023e146e78a22afd04601b813` | `2b264defd5244f52b8edbd6c9239a325` |
| `region` | `SBG5` | `RBX-A` |
| Préfixe VLAN | `preprod-amont-*` | `prod-production-*` |
| VLAN IDs infra | 210–290 | 110–190 |
| VLAN IDs app | 400–402 | 300–302 |
| Backend S3 endpoint | `s3.sbg.io.cloud.ovh.net` | `s3.rbx.io.cloud.ovh.net` |

---

## 🔌 Providers utilisés

| Provider | Source | Version | Usage |
|---|---|---|---|
| **ovh** | `ovh/ovh` | `>= 2.11.0` | Création des réseaux privés vRack (VLANs) |
| **openstack** | `terraform-provider-openstack/openstack` | `>= 1.53.0` | Création des subnets associés aux VLANs |
| **vault** | `hashicorp/vault` | `>= 3.25.0` | Lecture des secrets OVH et OpenStack (ephemeral) |

### Authentification Vault (ephemeral resources)

Ce repo utilise les **ephemeral resources** Vault (Terraform ≥ 1.10) pour injecter les secrets sans les stocker dans le state :

```hcl
ephemeral "vault_kv_secret_v2" "ovh" {
  mount = "iacrunner-amont"    # ou iacrunner-prod
  name  = "ovh_key"
}

ephemeral "vault_kv_secret_v2" "os" {
  mount = "iacrunner-amont"    # ou iacrunner-prod
  name  = "openstack_key"
}
```

---

## 📦 Module network

### `modules/network/`

Module unique qui crée l'ensemble de l'infrastructure réseau à partir d'une map de VLANs.

#### Ressources créées (par VLAN)

| # | Ressource | Type | Description |
|---|---|---|---|
| 1 | `ovh_cloud_project_network_private.vlan` | Réseau OVH | Réseau privé vRack avec VLAN ID et région |
| 2 | `openstack_networking_subnet_v2.subnet` | Subnet OpenStack | Sous-réseau avec CIDR, pool DHCP, gateway |

Les ressources utilisent `for_each` sur la map `var.vlans` pour créer dynamiquement tous les réseaux.

#### Logique dynamique Gateway / DHCP

Le module gère automatiquement 3 scénarios :

| Scénario | `gateway_ip` | `enable_dhcp` | Comportement |
|---|---|---|---|
| Réseau avec gateway + DHCP | `"10.11.90.254"` | `true` | Gateway définie, DHCP activé, DNS OVH configurés |
| Réseau sans gateway, sans DHCP | `null` (défaut) | `false` (défaut) | `no_gateway = true`, pas de DHCP, pas de DNS |
| Réseau avec gateway, sans DHCP | `"10.11.52.254"` | `true` | Gateway définie, DHCP activé, DNS OVH |

```hcl
# Gateway dynamique
gateway_ip = each.value.gateway_ip != null ? each.value.gateway_ip : null
no_gateway = each.value.gateway_ip == null ? true : null

# DHCP dynamique
enable_dhcp     = each.value.enable_dhcp
dns_nameservers = each.value.enable_dhcp ? ["213.186.33.99", "8.8.8.8"] : []
```

#### Variables du module

| Variable | Type | Description |
|---|---|---|
| `service_name` | `string` | ID du projet Public Cloud OVH |
| `region` | `string` | Région OVH (SBG5, RBX-A) |
| `vlans` | `map(object)` | Map de tous les VLANs à créer (voir structure ci-dessous) |

#### Structure d'un VLAN

```hcl
variable "vlans" {
  type = map(object({
    vlan_id     = number              # ID du VLAN dans le vRack (0 = public)
    name        = string              # Nom descriptif du réseau
    cidr        = string              # Plage CIDR du subnet
    start       = string              # Début du pool d'allocation
    end         = string              # Fin du pool d'allocation
    enable_dhcp = optional(bool, false)   # Activer le DHCP (défaut: false)
    gateway_ip  = optional(string, null)  # IP de la gateway (défaut: null = pas de gateway)
  }))
}
```

#### Outputs

| Output | Type | Description |
|---|---|---|
| `network_uuids` | `map(string)` | UUID OpenStack de chaque réseau (clé = nom du VLAN) |
| `subnet_ids` | `map(string)` | ID OpenStack de chaque subnet |
| `ovh_vlan_ids` | `map(string)` | ID OVH de chaque VLAN |

Ces outputs sont utilisés par les autres projets Terraform (ex: `terraform-ovh-infra`) pour attacher les VMs aux bons réseaux.

---

## 📝 Variables

### Variables racine (`variables.tf`)

| Variable | Type | Description |
|---|---|---|
| `service_name` | `string` | ID du projet Public Cloud OVH |
| `region` | `string` | Région OVH |
| `vlans` | `map(object)` | Définition de tous les réseaux |

---

## 🗺️ Plan d'adressage

### Environnement Production (`prod` — `RBX-A`)

| Clé | VLAN ID | Nom | CIDR | Gateway | DHCP | Usage |
|---|---|---|---|---|---|---|
| `fw_front` | 0 | prod-production-fw-front | `5.135.49.0/25` | — | Non | Interface publique firewall |
| `vrack_vpn` | 110 | prod-production-vrack-vpn | `10.11.10.0/24` | — | Non | VPN vRack |
| `fwfe_admin` | 120 | prod-production-fwfe-admin | `10.11.20.0/24` | — | Non | Administration firewall front-end |
| `fwfe_ha` | 121 | prod-production-fwfe-ha | `172.16.21.32/28` | — | Non | HA firewall front-end |
| `dmz_exposed` | 130 | prod-production-dmz-exposed | `10.11.30.0/24` | — | Non | DMZ exposée (proxy SSH) |
| `fw_interco` | 140 | prod-production-fw-interco | `172.16.21.16/28` | — | Non | Interconnexion firewalls |
| `fwbe_admin` | 150 | prod-production-fwbe-admin | `10.11.50.0/24` | — | Non | Administration firewall back-end |
| `infra_admin` | 151 | prod-production-infra-admin | `10.11.51.0/24` | — | Non | Administration infrastructure |
| `dmz_admin` | 152 | prod-production-dmz-admin | `10.11.52.0/24` | `10.11.52.254` | **Oui** | DMZ administration |
| `k8s_front` | 160 | prod-production-k8s-front | `10.11.60.0/24` | — | Non | Kubernetes front |
| `k8s_back` | 161 | prod-production-k8s-back | `10.11.61.0/24` | — | Non | Kubernetes back |
| `dmz_transit` | 170 | prod-production-dmz-transit | `10.11.70.0/24` | — | Non | DMZ transit (proxy Squid) |
| `infra_app` | 190 | prod-production-infra-app | `10.11.90.0/24` | `10.11.90.254` | **Oui** | Applications infrastructure (IPA, Repo, Ansible) |
| `app_front` | 300 | prod-production-app-front | `10.13.0.0/24` | — | Non | Applications front |
| `app_middle` | 301 | prod-production-app-middle | `10.13.1.0/24` | — | Non | Applications middle |
| `app_back` | 302 | prod-production-app-back | `10.13.2.0/24` | — | Non | Applications back |

### Environnement Pré-production (`amont` — `SBG5`)

| Clé | VLAN ID | Nom | CIDR | Gateway | DHCP | Usage |
|---|---|---|---|---|---|---|
| `fwfe_front` | 0 | preprod-amont-fwfe-front | `10.12.0.0/24` | — | Non | Interface front firewall |
| `vrack_vpn` | 210 | preprod-amont-vrack-vpn | `10.12.10.0/24` | — | Non | VPN vRack |
| `fwfe_admin` | 220 | preprod-amont-fwfe-admin | `10.12.20.0/24` | — | Non | Administration firewall front-end |
| `dmz_exposed` | 230 | preprod-amont-dmz-exposed | `10.12.30.0/24` | `10.12.30.254` | **Oui** | DMZ exposée |
| `fw_interco` | 240 | preprod-amont-fw-interco | `172.16.31.16/28` | — | Non | Interconnexion firewalls |
| `fwbe_admin` | 250 | preprod-amont-fwbe-admin | `10.12.50.0/24` | — | Non | Administration firewall back-end |
| `infra_admin` | 251 | preprod-amont-infra-admin | `10.12.51.0/24` | — | Non | Administration infrastructure |
| `dmz_admin` | 252 | preprod-amont-dmz-admin | `10.12.52.0/24` | `10.12.52.253` | **Oui** | DMZ administration |
| `k8s_front` | 260 | preprod-amont-k8s-front | `10.12.60.0/24` | — | Non | Kubernetes front |
| `k8s_back` | 261 | preprod-amont-k8s-back | `10.12.61.0/24` | — | Non | Kubernetes back |
| `dmz_transit` | 270 | preprod-amont-dmz-transit | `10.12.70.0/24` | `10.12.70.253` | **Oui** | DMZ transit |
| `fwbe_occ` | 280 | preprod-amont-fwbe-occ | `172.16.31.0/28` | — | Non | Firewall back-end OCC |
| `infra_app` | 290 | preprod-amont-infra-app | `10.12.90.0/24` | `10.12.90.253` | **Oui** | Applications infrastructure |
| `app_front` | 400 | preprod-amont-app-front | `10.14.0.0/24` | — | Non | Applications front |
| `app_middle` | 401 | preprod-amont-app-middle | `10.14.1.0/24` | — | Non | Applications middle |
| `app_back` | 402 | preprod-amont-app-back | `10.14.2.0/24` | — | Non | Applications back |

### Convention d'adressage

| Plage | Environnement | Usage |
|---|---|---|
| `10.11.x.x` | Production | Infrastructure + DMZ |
| `10.13.x.x` | Production | Applications |
| `10.12.x.x` | Pré-production | Infrastructure + DMZ |
| `10.14.x.x` | Pré-production | Applications |
| `172.16.21.x` | Production | Interconnexion firewalls / HA |
| `172.16.31.x` | Pré-production | Interconnexion firewalls / OCC |
| `5.135.49.x` | Production | IP publiques (front firewall) |

---

## 💾 Backend S3 (state distant)

### Branche `amont`

```hcl
terraform {
  backend "s3" {
    bucket = "infra-amont-sto-object-tf01"
    key    = "infra-amont-network.tfstate"
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
    key    = "infra-production-network.tfstate"
    region = "rbx"
    endpoints = { s3 = "https://s3.rbx.io.cloud.ovh.net/" }
  }
}
```

---

## 🚀 Commandes de lancement

### Déploiement standard

```bash
# 1. Se positionner sur la branche de l'environnement cible
git checkout amont   # ou prod

# 2. Configurer les variables d'environnement
export VAULT_ADDR="https://vault.example.com"
export AWS_ACCESS_KEY_ID="<s3_access_key>"
export AWS_SECRET_ACCESS_KEY="<s3_secret_key>"

# 3. Initialiser Terraform
terraform init

# 4. Planifier les changements
terraform plan -var-file="network.tfvars"

# 5. Appliquer les changements
terraform apply -var-file="network.tfvars"
```

### Cibler un VLAN spécifique

```bash
# Planifier uniquement le VLAN infra_app
terraform plan -var-file="network.tfvars" \
  -target='module.network.ovh_cloud_project_network_private.vlan["infra_app"]' \
  -target='module.network.openstack_networking_subnet_v2.subnet["infra_app"]'

# Appliquer uniquement le VLAN dmz_transit
terraform apply -var-file="network.tfvars" \
  -target='module.network.ovh_cloud_project_network_private.vlan["dmz_transit"]' \
  -target='module.network.openstack_networking_subnet_v2.subnet["dmz_transit"]'
```

### Destruction

```bash
# Détruire un VLAN spécifique
terraform destroy -var-file="network.tfvars" \
  -target='module.network.ovh_cloud_project_network_private.vlan["app_front"]'

# Détruire tout (⚠️ DANGER — coupe tout le réseau)
terraform destroy -var-file="network.tfvars"
```

> ⚠️ **ATTENTION** : La destruction des réseaux déconnectera toutes les VMs attachées. Ne jamais faire de `destroy` global en production.

---

## 🧪 Commandes de test et vérification

```bash
# Valider la syntaxe
terraform validate

# Formater le code (vérification)
terraform fmt -check -recursive

# Formater le code (correction)
terraform fmt -recursive

# Lister les ressources dans le state
terraform state list

# Afficher un VLAN spécifique dans le state
terraform state show 'module.network.ovh_cloud_project_network_private.vlan["infra_app"]'
terraform state show 'module.network.openstack_networking_subnet_v2.subnet["infra_app"]'

# Afficher les outputs (UUIDs réseau)
terraform output
terraform output -json

# Afficher les UUIDs réseau
terraform output -json | jq '.network_uuids'

# Planifier en mode détaillé
terraform plan -var-file="network.tfvars" -detailed-exitcode
# Exit code 0 = pas de changement
# Exit code 2 = changements détectés

# Rafraîchir le state
terraform refresh -var-file="network.tfvars"

# Graphe de dépendances
terraform graph | dot -Tpng > network-graph.png
```

### Vérification côté OVH / OpenStack

```bash
# Lister les réseaux via OpenStack CLI
openstack network list

# Lister les subnets
openstack subnet list

# Détail d'un subnet
openstack subnet show <subnet_id>

# Vérifier depuis une VM
ssh almalinux@<ip> "ip addr show && ip route show"
```

---

## 🔐 Gestion des secrets (Vault)

### Secrets consommés (en lecture)

| Chemin Vault | Clés | Provenance |
|---|---|---|
| `iacrunner-*/ovh_key` | `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY` | Créé par `terraform-ovh-storage` ou manuellement |
| `iacrunner-*/openstack_key` | `OS_AUTH_URL`, `OS_APPLICATION_CREDENTIAL_ID`, `OS_APPLICATION_CREDENTIAL_SECRET` | Créé par `terraform-ovh-storage` |

### Vérification Vault

```bash
# Vérifier les credentials OVH
vault kv get iacrunner-amont/ovh_key

# Vérifier les credentials OpenStack
vault kv get iacrunner-amont/openstack_key
```

---

## ➕ Ajouter / modifier un VLAN

### Ajouter un nouveau VLAN

1. Éditer `network.tfvars` et ajouter une entrée dans la map `vlans` :

```hcl
vlans = {
  # ... VLANs existants ...

  "mon_nouveau_vlan" = {
    vlan_id     = 500
    name        = "prod-production-mon-vlan-10.15.0.0-24"
    cidr        = "10.15.0.0/24"
    start       = "10.15.0.51"
    end         = "10.15.0.100"
    enable_dhcp = true           # Optionnel, défaut: false
    gateway_ip  = "10.15.0.254"  # Optionnel, défaut: null (pas de gateway)
  }
}
```

2. Planifier et vérifier :
```bash
terraform plan -var-file="network.tfvars"
```

3. Appliquer :
```bash
terraform apply -var-file="network.tfvars"
```

### Modifier un VLAN existant

Modifier les valeurs dans `network.tfvars`. Attention :
- **Changer le `vlan_id`** → force la re-création du réseau (destructif !)
- **Changer le `cidr`** → force la re-création du subnet (destructif !)
- **Changer `enable_dhcp` ou `gateway_ip`** → update in-place (non destructif)

### Supprimer un VLAN

1. Retirer l'entrée de la map `vlans` dans `network.tfvars`
2. `terraform plan` pour vérifier ce qui sera détruit
3. `terraform apply` pour supprimer

---

## 🔧 Dépannage

### Problèmes courants

| Problème | Cause probable | Solution |
|---|---|---|
| `Error: ephemeral "vault_kv_secret_v2" not supported` | Terraform < 1.10 | Mettre à jour Terraform vers ≥ 1.10 |
| `Error: Failed to get existing workspaces` | Backend S3 inaccessible | Vérifier `AWS_ACCESS_KEY_ID`/`SECRET` et l'endpoint |
| `Error: Conflict - no_gateway and gateway_ip` | Bug logique gateway | Vérifier que `gateway_ip` est bien `null` ou une IP valide |
| `Error: VLAN ID already in use` | VLAN déjà créé manuellement sur OVH | Importer : `terraform import 'module.network.ovh_cloud_project_network_private.vlan["key"]' <id>` |
| `Error: 409 Conflict subnet overlap` | CIDR en conflit avec un subnet existant | Vérifier le plan d'adressage, supprimer le subnet en doublon |
| VMs ne voient pas le réseau | VLAN pas attaché à la VM | Vérifier dans `terraform-ovh-infra` que le bon `network_uuid` est utilisé |
| Pas de connectivité inter-VLAN | Routage manquant | Configurer le routage sur les firewalls (hors scope Terraform) |

### Commandes de diagnostic

```bash
# Debug complet
TF_LOG=DEBUG terraform plan -var-file="network.tfvars" 2>&1 | tee debug.log

# Vérifier le state
terraform state pull | jq '.resources[] | .type + "." + .name'

# Importer une ressource existante
terraform import \
  'module.network.ovh_cloud_project_network_private.vlan["infra_app"]' \
  <service_name>/<network_id>

# Supprimer une ressource du state (sans détruire)
terraform state rm 'module.network.ovh_cloud_project_network_private.vlan["old_vlan"]'
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
   git checkout -b feature/ajout-vlan-monitoring amont
   ```
3. Valider avec `terraform validate` et `terraform fmt`
4. Planifier avec `terraform plan` pour vérifier l'impact
5. Créer une Pull Request vers la branche cible

### Conventions

- **Nommage des VLANs** : `<env>-<projet>-<zone>-<cidr>` (ex: `prod-production-infra-app-10.11.90.0-24`)
- **Clés de map** : snake_case descriptif (ex: `infra_app`, `dmz_transit`, `k8s_front`)
- **VLAN IDs** : Production `1xx`-`3xx`, Pré-prod `2xx`-`4xx`
- **Branche par défaut** : `main` (documentation), `amont` (preprod), `prod` (production)

---

## 🔗 Projets liés

| Repo | Description |
|---|---|
| [`terraform-ovh-storage`](https://github.com/ansforge/terraform-ovh-storage) | Gestion du stockage S3 OVH et credentials Vault |
| [`ansible-ovh`](https://github.com/ansforge/ansible-ovh) | Provisionnement et configuration des VMs via Ansible |

---

## 📄 Licence

*Non spécifiée — Consulter l'organisation [ANS Forge](https://github.com/ansforge) pour plus d'informations.*

---

> **Maintenu par l'équipe Infrastructure ANS Forge** — Gestion réseau OVH vRack avec Terraform + Vault
