# Dockerfile pour la Solution IA de Cybersécurité SOC

# Image de base pour la démonstration de l'architecture
FROM ubuntu:22.04

# Éviter les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installation des dépendances de base
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    docker.io \
    docker-compose \
    nano \
    vim \
    sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installation des bibliothèques Python pour TensorFlow et l'intégration Elastic
RUN pip3 install --no-cache-dir \
    tensorflow \
    elasticsearch \
    pandas \
    numpy \
    scikit-learn \
    matplotlib \
    jupyter

# Création des répertoires pour la solution
RUN mkdir -p /opt/soc-ai-solution/{suricata,zeek,wazuh,elastic,tensorflow,shuffle,thehive,cortex,grafana,caldera}/{config,data} \
    && mkdir -p /opt/soc-ai-solution/shared-data

# Copie des fichiers de configuration et scripts
COPY docker-compose.yml /opt/soc-ai-solution/
COPY scripts/ /opt/soc-ai-solution/scripts/
COPY config/ /opt/soc-ai-solution/config/

# Rendre les scripts exécutables
RUN chmod +x /opt/soc-ai-solution/scripts/*.sh

# Définir le répertoire de travail
WORKDIR /opt/soc-ai-solution

# Commande par défaut
CMD ["/bin/bash"]
