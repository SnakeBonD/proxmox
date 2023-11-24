#!/bin/bash

# The Duke Of Puteaux
# Rejoins moi sur Youtube: https://www.youtube.com/channel/UCsJ-FHnCEvtV4m3-nTdR5QQ

# USAGE
# wget -q -O - https://raw.githubusercontent.com/SnakeBonD/proxmox/main/pve-no-subscription.sh | bash

# SOURCES
# https://pve.proxmox.com/wiki/Package_Repositories#sysadmin_no_subscription_repo
# https://github.com/Tontonjo/proxmox/

# VARIABLES
distribution=$(grep -F "VERSION_CODENAME=" /etc/os-release | cut -d= -f2)
timestamp=$(date +%s)

echo "----------------------------------------------------------------"
echo "Debut du script"
echo "----------------------------------------------------------------"

#1 Suppression / Ajouts de dépôts

# pve-enterprise.list
echo "- Sauvegarde pve-enterprise.list"
cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise-$timestamp.bak

echo "- Vérification pve-entreprise.list"
if grep -Fxq "#deb https://enterprise.proxmox.com/debian/pve $distribution pve-enterprise" /etc/apt/sources.list.d/pve-enterprise.list
  then
    echo "- Dépôt déja commenté"
  else
    echo "- Masquage du dépôt en ajoutant # à la première ligne"
    sed -i 's/^/#/' /etc/apt/sources.list.d/pve-enterprise.list
fi

# ceph.list
echo "- Sauvegarde ceph.list"
cp /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list-$timestamp.bak

echo "- Vérification ceph.list"
if grep -Fxq "#deb https://enterprise.proxmox.com/debian/ceph-quincy $distribution enterprise" /etc/apt/sources.list.d/ceph.list
  then
    echo "- Dépôt déja commenté"
  else
    echo "- Masquage du dépôt en ajoutant # à la première ligne"
    sed -i 's/^/#/' /etc/apt/sources.list.d/ceph.list
fi

# pve-no-subscription
echo "- Sauvegarde sources.list"
cp /etc/apt/sources.list /etc/apt/sources-$timestamp.bak

echo "- Vérification sources.list"
if grep -Fxq "deb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" /etc/apt/sources.list
  then
    echo "- Dépôt déja présent"
  else
    echo "- Ajout du dépôt pve-no-subscription"
    echo "deb http://download.proxmox.com/debian/pve $distribution pve-no-subscription" >> /etc/apt/sources.list
fi


#2: MAJ
echo "- MAJ OS"
apt update -y
apt full-upgrade -y


#3: Supprimer le pop-up de souscription
echo "- Sauvegarde Subscription.pm"
cp /usr/share/perl5/PVE/API2/Subscription.pm /usr/share/perl5/PVE/API2/Subscription-$timestamp.bak

echo "- Verificiation du fichier Subscription.pm"
if grep -q 'status => "notfound",' /usr/share/perl5/PVE/API2/Subscription.pm
  then
    sed -i 's/status => "notfound",/status => "active",/' /usr/share/perl5/PVE/API2/Subscription.pm
    echo "La ligne a été modifiée de 'status => \"notfound\"' à 'status => \"active\"'."
    systemctl restart pveproxy.service
else
    echo "La ligne 'status => \"notfound\"' n'a pas été trouvée dans le fichier."
fi

echo "- Sauvegarde proxmoxlib.js"
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib-$timestamp.bak

echo "- Verificiation pop-up souscription"
if [ $(grep -c "void({ //Ext.Msg.show({" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js) -gt 0 ]
  then
    echo "- Modification déja présente"
  else
    echo "- Application modification"
    sed -Ezi.bak "s/(Ext.Msg.show\(\{\s+title: gettext\('No valid subscription')/void\(\{ \/\/\1/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
    systemctl restart pveproxy.service
fi

#4: Optimisation SWAP
echo "- Paramatrage du SWAP pour qu'il ne s'active que lorsqu'il ne reste plus que 10% de RAM dispo"
sysctl vm.swappiness=10
echo "- Désactivation du SWAP"
swapoff -a
echo "- Activation du SWAP"
swapon -a

echo "----------------------------------------------------------------"
echo "Fin du script"
echo "----------------------------------------------------------------"
