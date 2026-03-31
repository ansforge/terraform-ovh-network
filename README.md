Infrastructure OVHcloud - Network (Production)

Ce dépôt Terraform gère l’ensemble de la couche réseau OVHcloud :
- création des réseaux privés (vRack / VLANs)
- création des subnets OpenStack
- configuration DHCP / Gateway
- structuration réseau pour les environnements (DMZ, K8s, Infra, App)

🏗️ Structure du Projet

modules/network/ : Module principal gérant :
- création des VLANs OVH (réseaux privés)
- création des subnets OpenStack
- configuration IP (CIDR, pool, gateway, DHCP)

backend.tf : Configuration du backend distant (S3 OVH Object Storage).

main.tf : Point d’entrée Terraform appelant le module réseau.

variables.tf : Déclaration des variables globales.

network.tfvars : Définition complète des VLANs et des plages IP.

🔐 Intégration Vault

Les credentials sont récupérés dynamiquement depuis Vault via des secrets éphémères :

iacrunner-prod/ovh_key :
- OVH_APPLICATION_KEY
- OVH_APPLICATION_SECRET
- OVH_CONSUMER_KEY

iacrunner-prod/openstack_key :
- OS_AUTH_URL
- OS_APPLICATION_CREDENTIAL_ID
- OS_APPLICATION_CREDENTIAL_SECRET

👉 Utilisation d’ephemeral secrets :
- aucun secret persistant dans Terraform
- aucune exposition dans le state
- sécurité renforcée

🌐 Architecture Réseau

L’infrastructure repose sur un découpage réseau clair et segmenté :

Types de réseaux :

- vrack_vpn → interconnexion VPN
- fwfe_admin / fwbe_admin → administration firewall
- fwfe_ha → haute disponibilité firewall
- fw_interco → interconnexion firewall
- infra_admin → administration infrastructure
- infra_app → réseau applicatif interne infra
- dmz_admin → DMZ avec DHCP
- dmz_exposed → DMZ exposée (sans DHCP)
- dmz_transit → transit DMZ
- k8s_front / k8s_back → cluster Kubernetes
- app_front / app_middle / app_back → architecture applicative 3-tiers
- fw_front → réseau public (VLAN 0 OVH)

👉 Chaque réseau est isolé via VLAN + subnet dédié.

⚙️ Fonctionnement technique

1. Création des VLANs (OVH)

resource : ovh_cloud_project_network_private

- 1 VLAN par entrée dans var.vlans
- attaché à la région (RBX-A)
- ID VLAN configurable (ex: 100, 150, 300…)

---

2. Création des Subnets (OpenStack)

resource : openstack_networking_subnet_v2

Pour chaque VLAN :

- CIDR défini (ex: 10.11.50.0/24)
- Pool IP (start → end)
- DHCP activable
- Gateway optionnelle

---

3. Gestion dynamique Gateway

- Si gateway_ip défini → utilisé
- Sinon → no_gateway = true

👉 évite les conflits Terraform/OpenStack

---

4. Gestion DHCP

- enable_dhcp = true → DHCP actif + DNS
- enable_dhcp = false → réseau statique

DNS configurés automatiquement :
- 213.186.33.99 (OVH)
- 8.8.8.8 (Google)

---

🪣 Backend Terraform

- Bucket : infra-prod-sto-object-tf01
- Région : RBX
- Endpoint : https://s3.rbx.io.cloud.ovh.net/

👉 Permet :
- centralisation du state
- travail en équipe
- sécurisation

---

🚀 Utilisation

Pré-requis

1. Vault accessible :

export VAULT_ADDR=https://vault.xxx

2. Secrets présents :

- iacrunner-prod/ovh_key
- iacrunner-prod/openstack_key

3. Permissions Vault :
- lecture des secrets

---

Déploiement

terraform init  
terraform plan -var-file="network.tfvars"  
terraform apply -var-file="network.tfvars"

---

🔧 Variables

network.tfvars :

service_name = "2b264defd5244f52b8edbd6c9239a325"
region       = "RBX-A"

vlans = {
  vrack_vpn   = { vlan_id = 110, cidr = "10.11.10.0/24", ... }
  fwfe_admin  = { vlan_id = 120, cidr = "10.11.20.0/24", ... }
  k8s_front   = { vlan_id = 160, cidr = "10.11.60.0/24", ... }
  app_front   = { vlan_id = 300, cidr = "10.13.0.0/24", ... }
}

👉 Chaque entrée définit :
- VLAN ID
- Nom réseau
- CIDR
- plage IP
- DHCP (optionnel)
- Gateway (optionnel)

---

📤 Outputs Terraform

network_uuids :
- UUID OpenStack des réseaux

subnet_ids :
- IDs des subnets

ovh_vlan_ids :
- IDs OVH des VLANs

👉 Utilisables pour :
- provisioning VM
- security groups
- load balancer
- Kubernetes

---

🛡️ Sécurité

- Secrets dynamiques (Vault ephemeral)
- Aucun secret dans le code ou state
- Segmentation réseau stricte (VLAN)
- Isolation par environnement (DMZ / APP / INFRA)
- Contrôle DHCP / Gateway fin

---

⚠️ Points d’attention

- Bien vérifier les CIDR (pas de chevauchement)
- VLAN ID unique par réseau
- Gateway cohérente avec CIDR
- DHCP uniquement si nécessaire
- VLAN 0 = réseau public OVH (cas spécifique)

---

🧪 Vérifications post-déploiement

Lister réseaux :
openstack network list

Lister subnets :
openstack subnet list

Vérifier OVH :
ovh network list

---

🔄 Améliorations possibles

- Ajout de security groups automatisés
- Ajout de routing avancé (router OpenStack)
- Intégration firewall (pfSense / Fortinet)
- Automatisation des ACL réseau
- Multi-régions (SBG / GRA / RBX)

---

👨‍💻 Auteur

Infrastructure Terraform OVHcloud – Layer réseau industrialisé et sécurisé pour production.
