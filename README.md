# Infrastructure OVHcloud - Network (Production)

Ce dépôt Terraform gère la couche réseau de l'infrastructure de production sur OVHcloud. Il s'appuie sur le vRack pour créer des réseaux privés isolés et raccordés à une Gateway Internet.

## 🏗️ Architecture Réseau

Le projet déploie une topologie multi-VLAN segmentée par usage :

| VLAN | Nom | CIDR | Rôle |
| :--- | :--- | :--- | :--- |
| **100** | `fwfe_front` | `10.11.0.0/24` | Frontal public (DMZ Front) |
| **110** | `vrack_vpn` | `10.11.10.0/24` | Accès VPN / Administration |
| **130** | `dmz_exposed`| `10.11.30.0/24` | Services exposés |
| **160** | `k8s_front` | `10.11.60.0/24` | Kubernetes Workers (Front) |
| **300+**| `app_*` | `10.13.x.0/24` | Couches applicatives (Front/Mid/Back) |

## 🛠️ Composants Techniques

* **Provider OVH** : Utilisé pour la création des réseaux privés (`ovh_cloud_project_network_private`) au sein du vRack.
* **Provider OpenStack** : Utilisé pour la configuration des sous-réseaux (Subnets), des pools d'allocation IP et des serveurs DNS.
* **Public Cloud Gateway** : Une Gateway de taille **S** est rattachée au VLAN 100 (`fwfe_front`) pour permettre la sortie Internet via NAT.

## 🔐 Gestion des Secrets (Vault)

Le projet utilise des **données éphémères** (`ephemeral`) pour récupérer les identifiants de connexion depuis Vault sans les stocker dans le state :
* `iacrunner-prod/ovh_key` : Clés d'API OVH.
* `iacrunner-prod/openstack_key` : Application Credentials OpenStack (ID/Secret).

## 🚀 Déploiement

### Pré-requis
Charger les identifiants S3 pour le backend (stockés dans Vault par le module storage) :
```bash
export AWS_ACCESS_KEY_ID=$(vault kv get -field=AWS_ACCESS_KEY_ID iacrunner-prod/aws_key)
export AWS_SECRET_ACCESS_KEY=$(vault kv get -field=AWS_SECRET_ACCESS_KEY iacrunner-prod/aws_key)
