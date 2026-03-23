Infrastructure OVHcloud - Network (Production)

Ce dépôt Terraform gère la couche réseau de l’infrastructure de production sur OVHcloud.
Il s’appuie sur le vRack pour créer des réseaux privés isolés et raccordés à une Gateway Internet.

🏗️ Architecture Réseau

Le projet déploie une topologie multi-VLAN segmentée par usage :

VLAN	Nom (OpenStack/OVH)	Rôle
100	fwfe_front	Frontal public (DMZ Front)
110	vrack_vpn	Accès VPN / Administration
130	dmz_exposed	Services exposés
160	k8s_front	Kubernetes Workers (Front)
300+	app_*	Couches applicatives (Front/Mid/Back)
Topologie simplifiée
       ┌───────────────┐
       │ Gateway / NAT │
       └──────┬────────┘
              │
   ┌──────────┴──────────┐
   │ Multi-VLAN vRack     │
   │---------------------│
   │ DMZ / VPN / Admin   │
   │ K8s / App Front/Mid/Back │
   └─────────────────────┘

Chaque VLAN est configuré sur OpenStack avec son subnet, son pool d’adresses IP et ses serveurs DNS OVH.
Les passerelles sont gérées via les firewalls Stormshield et non exposées directement.

🛠️ Composants Techniques

Provider OVH : création des réseaux privés (ovh_cloud_project_network_private) dans le vRack.

Provider OpenStack : configuration des subnets et allocation des IPs.

Backend S3 : stockage du state Terraform pour collaboration et versioning.

Vault Ephemeral : récupération des credentials OVH et OpenStack de manière sécurisée (iacrunner-prod/ovh_key et iacrunner-prod/openstack_key).

Allocation des IPs

Chaque subnet dispose d’un pool d’adresses IP défini dans le fichier network.tfvars.

Les IPs fixes ne sont pas visibles dans la documentation pour simplifier la topologie.

🚀 Déploiement
Pré-requis

Terraform >= 1.5

Backend S3 configuré (backend.tf)

Accès OpenStack via Application Credential

Vault configuré pour récupérer les secrets OVH et OpenStack

Exemple d’exécution
# Initialiser Terraform avec le backend S3
terraform init -backend-config=backend.tf

# Appliquer la configuration pour créer les VLANs et subnets
terraform apply -var-file=network.tfvars
Outputs Terraform
Output	Description
network_uuids	UUIDs OpenStack des réseaux créés
subnet_ids	IDs des subnets OpenStack
ovh_vlan_ids	IDs OVH des VLANs
🔐 Notes Sécurité

Les subnets OpenStack sont créés sans passerelle par défaut, gérée via les firewalls Stormshield.

Les secrets OVH et OpenStack ne sont jamais stockés dans le state Terraform.

Les pools d’adresses IP sont définis, mais non exposés dans la documentation pour éviter toute fuite.
