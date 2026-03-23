# 🌐 Infrastructure OVHcloud – Network (Production)

Ce dépôt **Terraform** gère la couche réseau de l’infrastructure de production sur **OVHcloud**.  
Il s’appuie sur le **vRack** pour créer des réseaux privés isolés, interconnectés et sécurisés, avec une sortie vers Internet via une **Gateway / NAT**.

---

## 🏗️ Architecture Réseau

Le projet déploie une architecture multi-VLAN segmentée par usage :

| VLAN | Nom | Rôle |
|------|-----|------|
| 100 | `fwfe_front` | Frontal public (DMZ Front) |
| 110 | `vrack_vpn` | Accès VPN / Administration |
| 130 | `dmz_exposed` | Services exposés |
| 160 | `k8s_front` | Kubernetes Workers (Front) |
| 300+ | `app_*` | Couches applicatives (Front / Mid / Back) |

Chaque VLAN est configuré via **OpenStack** avec :
- un subnet dédié  
- un pool d’adresses IP  
- les DNS OVH  

👉 Les passerelles sont gérées par des **firewalls Stormshield** et ne sont pas exposées directement.

---

## 🛠️ Composants Techniques

- **Provider OVH**
  - Création des réseaux privés (`ovh_cloud_project_network_private`)
  - Intégration dans le **vRack**

- **Provider OpenStack**
  - Création et gestion des subnets
  - Allocation des adresses IP

- **Backend S3**
  - Stockage du state Terraform
  - Collaboration et versioning

- **Vault (ephemeral)**
  - Récupération sécurisée des credentials :
    - `iacrunner-prod/ovh_key`
    - `iacrunner-prod/openstack_key`

---

## 📦 Allocation des IPs

- Chaque subnet possède un **pool d’adresses IP** défini dans le fichier `network.tfvars`
- Les **IP fixes ne sont pas documentées** afin de préserver la simplicité et la sécurité de l’architecture

---

## 🚀 Déploiement

### 🔧 Prérequis

- Terraform >= 1.5  
- Backend S3 configuré (`backend.tf`)  
- Accès OpenStack via **Application Credentials**  
- Vault configuré pour récupérer les secrets OVH et OpenStack  

---

### ▶️ Initialisation

```bash
terraform plan "network.tfvars"
terraform apply "network.tfvars"

