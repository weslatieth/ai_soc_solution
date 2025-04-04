#!/bin/bash

# Script d'installation de la solution IA pour Cybersécurité SOC
# Ce script prépare l'environnement et déploie les composants via Docker

# Vérification des privilèges sudo
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec des privilèges sudo."
  exit 1
fi

echo "=== Préparation de l'environnement pour la solution IA de Cybersécurité SOC ==="

# Mise à jour du système
echo "[1/7] Mise à jour du système..."
apt update && apt upgrade -y

# Installation des dépendances
echo "[2/7] Installation des dépendances..."
apt install -y apt-transport-https ca-certificates curl software-properties-common git

# Installation de Docker
echo "[3/7] Installation de Docker et Docker Compose..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt install -y docker-ce docker-compose

# Création de la structure de répertoires
echo "[4/7] Création de la structure de répertoires..."
mkdir -p ~/soc-ai-solution/{suricata,zeek,wazuh,elastic,tensorflow,shuffle,thehive,cortex,grafana,caldera}/{config,data}
mkdir -p ~/soc-ai-solution/shared-data

# Copie des fichiers de configuration
echo "[5/7] Copie des fichiers de configuration..."
cp docker-compose.yml ~/soc-ai-solution/
cp -r config/* ~/soc-ai-solution/

# Configuration des permissions
echo "[6/7] Configuration des permissions..."
chown -R $(whoami):$(whoami) ~/soc-ai-solution
chmod -R 755 ~/soc-ai-solution

# Démarrage des services
echo "[7/7] Démarrage des services..."
cd ~/soc-ai-solution
docker-compose up -d

echo ""
echo "=== Installation terminée ==="
echo "La solution IA pour Cybersécurité SOC a été déployée avec succès."
echo ""
echo "Interfaces disponibles :"
echo "- Kibana: http://localhost:5601 (elastic/changeme)"
echo "- Grafana: http://localhost:3000 (admin/changeme)"
echo "- TheHive: http://localhost:9000 (admin@thehive.local/secret)"
echo "- Cortex: http://localhost:9001 (admin/changeme)"
echo "- Shuffle SOAR: http://localhost:3001"
echo "- Jupyter Notebook: http://localhost:8888"
echo "- MITRE Caldera: http://localhost:8888 (admin/admin)"
echo ""
echo "Pour vérifier l'état des services :"
echo "cd ~/soc-ai-solution && docker-compose ps"
echo ""
echo "Pour arrêter les services :"
echo "cd ~/soc-ai-solution && docker-compose down"
echo ""
echo "Consultez le guide d'implémentation pour les étapes de configuration détaillées."
