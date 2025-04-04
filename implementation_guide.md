# Guide d'Implémentation de la Solution IA pour Cybersécurité SOC
## Basé sur des Outils Open Source

Ce guide détaille les étapes d'installation, de configuration et d'intégration des différents composants open source pour mettre en place une solution complète de SOC augmentée par l'IA.

## Table des Matières

1. [Prérequis et Infrastructure](#1-prérequis-et-infrastructure)
2. [Mise en Place de l'Environnement Docker](#2-mise-en-place-de-lenvironnement-docker)
3. [Couche de Collecte de Données](#3-couche-de-collecte-de-données)
   - [Installation et Configuration de Suricata](#31-installation-et-configuration-de-suricata)
   - [Installation et Configuration de Zeek](#32-installation-et-configuration-de-zeek)
   - [Installation et Configuration de Wazuh Agents](#33-installation-et-configuration-de-wazuh-agents)
4. [Couche d'Ingestion et Normalisation](#4-couche-dingestion-et-normalisation)
   - [Installation et Configuration d'Elastic Stack](#41-installation-et-configuration-delastic-stack)
   - [Configuration de Filebeat](#42-configuration-de-filebeat)
   - [Configuration de Logstash](#43-configuration-de-logstash)
5. [Couche d'Analyse et Détection IA](#5-couche-danalyse-et-détection-ia)
   - [Installation et Configuration de Wazuh Manager](#51-installation-et-configuration-de-wazuh-manager)
   - [Configuration d'Elastic SIEM](#52-configuration-delastic-siem)
   - [Intégration de TensorFlow](#53-intégration-de-tensorflow)
6. [Couche SOC N0 (Triage Automatisé)](#6-couche-soc-n0-triage-automatisé)
   - [Installation et Configuration de Shuffle SOAR](#61-installation-et-configuration-de-shuffle-soar)
   - [Création des Workflows de Triage](#62-création-des-workflows-de-triage)
7. [Couche d'Orchestration et Réponse](#7-couche-dorchestration-et-réponse)
   - [Installation et Configuration de TheHive](#71-installation-et-configuration-de-thehive)
   - [Installation et Configuration de Cortex](#72-installation-et-configuration-de-cortex)
   - [Création des Workflows de Réponse](#73-création-des-workflows-de-réponse)
8. [Couche Interface et Collaboration](#8-couche-interface-et-collaboration)
   - [Configuration de Kibana](#81-configuration-de-kibana)
   - [Installation et Configuration de Grafana](#82-installation-et-configuration-de-grafana)
9. [Couche Simulation et Tests](#9-couche-simulation-et-tests)
   - [Installation et Configuration de MITRE Caldera](#91-installation-et-configuration-de-mitre-caldera)
10. [Intégration et Tests de l'Ensemble](#10-intégration-et-tests-de-lensemble)
11. [Maintenance et Mise à Jour](#11-maintenance-et-mise-à-jour)

## 1. Prérequis et Infrastructure

### Spécifications Matérielles Recommandées

Pour un environnement de production, nous recommandons au minimum :

- **3 serveurs** avec les spécifications suivantes :
  - **Serveur de Collecte** : 8 cœurs CPU, 16 Go RAM, 500 Go stockage
  - **Serveur d'Analyse** : 16 cœurs CPU, 32 Go RAM, 1 To stockage
  - **Serveur d'Interface** : 8 cœurs CPU, 16 Go RAM, 250 Go stockage

Pour un environnement de test ou de démonstration, un seul serveur puissant peut suffire :
- 16 cœurs CPU, 64 Go RAM, 1 To stockage

### Prérequis Logiciels

- Système d'exploitation : Ubuntu Server 22.04 LTS
- Docker et Docker Compose
- Git

### Installation des Prérequis

```bash
# Mise à jour du système
sudo apt update && sudo apt upgrade -y

# Installation de Docker
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-compose

# Vérification de l'installation de Docker
sudo systemctl status docker

# Ajout de l'utilisateur courant au groupe docker
sudo usermod -aG docker ${USER}
newgrp docker

# Installation de Git
sudo apt install -y git
```

## 2. Mise en Place de l'Environnement Docker

Nous utiliserons Docker et Docker Compose pour faciliter le déploiement et la gestion des différents composants.

### Création de la Structure de Répertoires

```bash
# Création du répertoire principal
mkdir -p ~/soc-ai-solution
cd ~/soc-ai-solution

# Création des sous-répertoires pour chaque composant
mkdir -p {suricata,zeek,wazuh,elastic,tensorflow,shuffle,thehive,cortex,grafana,caldera}/config
mkdir -p {suricata,zeek,wazuh,elastic,tensorflow,shuffle,thehive,cortex,grafana,caldera}/data
mkdir -p shared-data
```

### Création du Fichier Docker Compose Principal

Créez un fichier `docker-compose.yml` à la racine du répertoire :

```yaml
version: '3.8'

networks:
  soc_network:
    driver: bridge

volumes:
  elasticsearch_data:
  wazuh_data:
  thehive_data:
  cortex_data:
  grafana_data:
  shuffle_data:

services:
  # Les services seront ajoutés dans les sections suivantes
```

## 3. Couche de Collecte de Données

### 3.1 Installation et Configuration de Suricata

Ajoutez le service Suricata au fichier `docker-compose.yml` :

```yaml
  suricata:
    image: jasonish/suricata:latest
    container_name: suricata
    restart: unless-stopped
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - SYS_NICE
      - NET_RAW
    volumes:
      - ./suricata/config:/etc/suricata
      - ./suricata/data:/var/log/suricata
      - ./shared-data:/shared-data
    command: -i eth0 -v
```

Créez un fichier de configuration de base pour Suricata dans `suricata/config/suricata.yaml` :

```yaml
# Suricata configuration
vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - http
        - dns
        - tls
        - files
        - ssh
        - flow
```

### 3.2 Installation et Configuration de Zeek

Ajoutez le service Zeek au fichier `docker-compose.yml` :

```yaml
  zeek:
    image: zeekurity/zeek:latest
    container_name: zeek
    restart: unless-stopped
    network_mode: "host"
    volumes:
      - ./zeek/config:/opt/zeek/etc
      - ./zeek/data:/opt/zeek/logs
      - ./shared-data:/shared-data
    command: -i eth0
```

Créez un fichier de configuration de base pour Zeek dans `zeek/config/local.zeek` :

```
# Zeek local configuration
@load base/protocols/conn
@load base/protocols/dns
@load base/protocols/http
@load base/protocols/ssl
@load base/protocols/ssh
@load base/frameworks/files
@load base/frameworks/notice
@load policy/tuning/json-logs

# Export logs in JSON format
redef LogAscii::use_json = T;
```

### 3.3 Installation et Configuration de Wazuh Agents

Ajoutez le service Wazuh Manager au fichier `docker-compose.yml` (les agents seront installés sur les endpoints) :

```yaml
  wazuh-manager:
    image: wazuh/wazuh-manager:latest
    container_name: wazuh-manager
    restart: unless-stopped
    ports:
      - "1514:1514/udp"
      - "1515:1515"
      - "514:514/udp"
      - "55000:55000"
    volumes:
      - wazuh_data:/var/ossec/data
      - ./wazuh/config:/var/ossec/etc
      - ./shared-data:/shared-data
    networks:
      - soc_network
```

Pour installer les agents Wazuh sur les endpoints Windows :

```powershell
# Téléchargement de l'agent Wazuh pour Windows
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.7.3-1.msi -OutFile wazuh-agent.msi

# Installation de l'agent avec l'adresse IP du manager Wazuh
msiexec.exe /i wazuh-agent.msi /q WAZUH_MANAGER="<IP_WAZUH_MANAGER>" WAZUH_REGISTRATION_SERVER="<IP_WAZUH_MANAGER>"

# Démarrage du service Wazuh
Start-Service -Name wazuhsvc
```

Pour installer les agents Wazuh sur les endpoints Linux :

```bash
# Ajout du référentiel Wazuh
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list

# Installation de l'agent
apt-get update
apt-get install wazuh-agent

# Configuration de l'agent
sed -i "s/MANAGER_IP/<IP_WAZUH_MANAGER>/" /var/ossec/etc/ossec.conf

# Démarrage du service
systemctl start wazuh-agent
systemctl enable wazuh-agent
```

## 4. Couche d'Ingestion et Normalisation

### 4.1 Installation et Configuration d'Elastic Stack

Ajoutez les services Elasticsearch et Kibana au fichier `docker-compose.yml` :

```yaml
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: elasticsearch
    restart: unless-stopped
    environment:
      - node.name=elasticsearch
      - cluster.name=soc-elastic
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
      - xpack.security.enabled=true
      - xpack.security.authc.api_key.enabled=true
      - ELASTIC_PASSWORD=changeme
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
      - ./elastic/config/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml
    ports:
      - "9200:9200"
    networks:
      - soc_network

  kibana:
    image: docker.elastic.co/kibana/kibana:8.12.0
    container_name: kibana
    restart: unless-stopped
    depends_on:
      - elasticsearch
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme
    volumes:
      - ./elastic/config/kibana.yml:/usr/share/kibana/config/kibana.yml
    ports:
      - "5601:5601"
    networks:
      - soc_network
```

Créez un fichier de configuration pour Elasticsearch dans `elastic/config/elasticsearch.yml` :

```yaml
cluster.name: "soc-elastic"
node.name: "elasticsearch"
network.host: 0.0.0.0
discovery.type: single-node
xpack.security.enabled: true
xpack.security.authc.api_key.enabled: true
```

Créez un fichier de configuration pour Kibana dans `elastic/config/kibana.yml` :

```yaml
server.name: kibana
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.username: elastic
elasticsearch.password: changeme
xpack.security.enabled: true
```

### 4.2 Configuration de Filebeat

Ajoutez le service Filebeat au fichier `docker-compose.yml` :

```yaml
  filebeat:
    image: docker.elastic.co/beats/filebeat:8.12.0
    container_name: filebeat
    restart: unless-stopped
    user: root
    volumes:
      - ./elastic/config/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - ./suricata/data:/suricata_logs:ro
      - ./zeek/data:/zeek_logs:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: filebeat -e -strict.perms=false
    depends_on:
      - elasticsearch
      - kibana
    networks:
      - soc_network
```

Créez un fichier de configuration pour Filebeat dans `elastic/config/filebeat.yml` :

```yaml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /suricata_logs/eve.json
  json.keys_under_root: true
  json.add_error_key: true
  tags: ["suricata"]

- type: log
  enabled: true
  paths:
    - /zeek_logs/conn.log
    - /zeek_logs/dns.log
    - /zeek_logs/http.log
    - /zeek_logs/ssl.log
    - /zeek_logs/x509.log
  json.keys_under_root: true
  json.add_error_key: true
  tags: ["zeek"]

filebeat.modules:
- module: elasticsearch
  server:
    enabled: true
  gc:
    enabled: true
  audit:
    enabled: true
  slowlog:
    enabled: true

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  username: "elastic"
  password: "changeme"
  indices:
    - index: "suricata-%{+yyyy.MM.dd}"
      when.contains:
        tags: "suricata"
    - index: "zeek-%{+yyyy.MM.dd}"
      when.contains:
        tags: "zeek"

setup.kibana:
  host: "kibana:5601"
  username: "elastic"
  password: "changeme"

setup.dashboards.enabled: true
setup.template.enabled: true
```

### 4.3 Configuration de Logstash

Ajoutez le service Logstash au fichier `docker-compose.yml` :

```yaml
  logstash:
    image: docker.elastic.co/logstash/logstash:8.12.0
    container_name: logstash
    restart: unless-stopped
    volumes:
      - ./elastic/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./elastic/config/pipelines:/usr/share/logstash/config/pipelines:ro
    ports:
      - "5044:5044"
    environment:
      LS_JAVA_OPTS: "-Xmx512m -Xms512m"
    depends_on:
      - elasticsearch
    networks:
      - soc_network
```

Créez un fichier de configuration pour Logstash dans `elastic/config/logstash.yml` :

```yaml
http.host: "0.0.0.0"
path.config: /usr/share/logstash/config/pipelines
```

Créez un pipeline pour normaliser les données Suricata dans `elastic/config/pipelines/suricata.conf` :

```
input {
  beats {
    port => 5044
    tags => ["suricata"]
  }
}

filter {
  if "suricata" in [tags] {
    date {
      match => [ "timestamp", "ISO8601" ]
      target => "@timestamp"
    }
    
    if [alert] {
      mutate {
        add_field => { "event_type" => "alert" }
      }
    }
  }
}

output {
  if "suricata" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      user => "elastic"
      password => "changeme"
      index => "suricata-enriched-%{+YYYY.MM.dd}"
    }
  }
}
```

Créez un pipeline pour normaliser les données Zeek dans `elastic/config/pipelines/zeek.conf` :

```
input {
  beats {
    port => 5044
    tags => ["zeek"]
  }
}

filter {
  if "zeek" in [tags] {
    date {
      match => [ "ts", "UNIX" ]
      target => "@timestamp"
    }
    
    # Enrichissement spécifique à Zeek
    if [_path] == "conn" {
      mutate {
        add_field => { "event_type" => "connection" }
      }
    } else if [_path] == "dns" {
      mutate {
        add_field => { "event_type" => "dns_query" }
      }
    }
  }
}

output {
  if "zeek" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      user => "elastic"
      password => "changeme"
      index => "zeek-enriched-%{+YYYY.MM.dd}"
    }
  }
}
```

## 5. Couche d'Analyse et Détection IA

### 5.1 Installation et Configuration de Wazuh Manager

Le service Wazuh Manager a déjà été ajouté dans la section 3.3. Configurez maintenant l'intégration avec Elasticsearch.

Créez un fichier de configuration pour l'intégration Wazuh-Elasticsearch dans `wazuh/config/ossec.conf` :

```xml
<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>no</logall>
    <logall_json>no</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>smtp.example.wazuh.com</smtp_server>
    <email_from>wazuh@example.wazuh.com</email_from>
    <email_to>recipient@example.wazuh.com</email_to>
    <email_maxperhour>12</email_maxperhour>
    <email_log_source>alerts.log</email_log_source>
    <queue_size>131072</queue_size>
  </global>

  <integration>
    <name>elasticsearch</name>
    <hook_url>http://elasticsearch:9200</hook_url>
    <api_key>changeme</api_key>
    <rule_id>1</rule_id>
    <alert_format>json</alert_format>
  </integration>
</ossec_config>
```

### 5.2 Configuration d'Elastic SIEM

Elastic SIEM est intégré à Kibana. Pour l'activer, ajoutez les configurations suivantes au fichier `elastic/config/kibana.yml` :

```yaml
xpack.siem.enabled: true
xpack.securitySolution.enabled: true
xpack.securitySolution.enableExperimental: ["alertingEventAction"]
```

### 5.3 Intégration de TensorFlow

Ajoutez le service TensorFlow au fichier `docker-compose.yml` :

```yaml
  tensorflow-serving:
    image: tensorflow/serving:latest
    container_name: tensorflow-serving
    restart: unless-stopped
    ports:
      - "8501:8501"
    volumes:
      - ./tensorflow/models:/models
    environment:
      - MODEL_NAME=anomaly_detection
    networks:
      - soc_network

  jupyter-tensorflow:
    image: jupyter/tensorflow-notebook:latest
    container_name: jupyter-tensorflow
    restart: unless-stopped
    ports:
      - "8888:8888"
    volumes:
      - ./tensorflow/notebooks:/home/jovyan/work
      - ./shared-data:/shared-data
    networks:
      - soc_network
```

Créez un script Python pour l'entraînement d'un modèle de détection d'anomalies dans `tensorflow/notebooks/anomaly_detection_model.ipynb` :

```python
# Exemple de notebook pour la détection d'anomalies avec TensorFlow
import tensorflow as tf
from tensorflow import keras
import numpy as np
import pandas as pd
import elasticsearch
from elasticsearch import Elasticsearch
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split

# Connexion à Elasticsearch
es = Elasticsearch(
    ['elasticsearch'],
    http_auth=('elastic', 'changeme'),
    scheme="http",
    port=9200
)

# Récupération des données depuis Elasticsearch
def get_data_from_elasticsearch():
    query = {
        "query": {
            "match_all": {}
        },
        "size": 10000
    }
    
    response = es.search(index="suricata-*", body=query)
    data = [hit["_source"] for hit in response["hits"]["hits"]]
    df = pd.DataFrame(data)
    return df

# Prétraitement des données
def preprocess_data(df):
    # Sélection des caractéristiques pertinentes
    features = ['src_ip', 'dest_ip', 'src_port', 'dest_port', 'proto', 'event_type']
    
    # Conversion des caractéristiques catégorielles en numériques
    df_encoded = pd.get_dummies(df[features])
    
    # Normalisation des données
    scaler = StandardScaler()
    df_scaled = scaler.fit_transform(df_encoded)
    
    return df_scaled, scaler

# Création du modèle d'autoencoder pour la détection d'anomalies
def create_autoencoder(input_dim):
    # Encodeur
    input_layer = keras.layers.Input(shape=(input_dim,))
    encoder = keras.layers.Dense(64, activation="relu")(input_layer)
    encoder = keras.layers.Dense(32, activation="relu")(encoder)
    encoder = keras.layers.Dense(16, activation="relu")(encoder)
    
    # Décodeur
    decoder = keras.layers.Dense(32, activation="relu")(encoder)
    decoder = keras.layers.Dense(64, activation="relu")(decoder)
    decoder = keras.layers.Dense(input_dim, activation="sigmoid")(decoder)
    
    # Autoencoder
    autoencoder = keras.Model(inputs=input_layer, outputs=decoder)
    autoencoder.compile(optimizer='adam', loss='mse')
    
    return autoencoder

# Entraînement du modèle
def train_model():
    # Récupération et prétraitement des données
    df = get_data_from_elasticsearch()
    df_scaled, scaler = preprocess_data(df)
    
    # Division des données en ensembles d'entraînement et de test
    X_train, X_test = train_test_split(df_scaled, test_size=0.2, random_state=42)
    
    # Création et entraînement du modèle
    autoencoder = create_autoencoder(X_train.shape[1])
    history = autoencoder.fit(
        X_train, X_train,
        epochs=50,
        batch_size=32,
        validation_data=(X_test, X_test),
        shuffle=True
    )
    
    # Sauvegarde du modèle
    autoencoder.save('/models/anomaly_detection/1')
    
    # Calcul des erreurs de reconstruction
    X_pred = autoencoder.predict(X_test)
    mse = np.mean(np.power(X_test - X_pred, 2), axis=1)
    
    # Détermination du seuil d'anomalie
    threshold = np.percentile(mse, 95)
    
    return autoencoder, threshold, history, mse

# Exécution de l'entraînement
autoencoder, threshold, history, mse = train_model()

# Affichage des résultats
plt.figure(figsize=(10, 6))
plt.hist(mse, bins=50)
plt.axvline(threshold, color='r', linestyle='--')
plt.title('Distribution des erreurs de reconstruction')
plt.xlabel('Erreur de reconstruction (MSE)')
plt.ylabel('Nombre d'échantillons')
plt.show()

# Affichage de la courbe d'apprentissage
plt.figure(figsize=(10, 6))
plt.plot(history.history['loss'], label='Perte (entraînement)')
plt.plot(history.history['val_loss'], label='Perte (validation)')
plt.title('Courbe d'apprentissage')
plt.xlabel('Époque')
plt.ylabel('Perte (MSE)')
plt.legend()
plt.show()
```

## 6. Couche SOC N0 (Triage Automatisé)

### 6.1 Installation et Configuration de Shuffle SOAR

Ajoutez le service Shuffle SOAR au fichier `docker-compose.yml` :

```yaml
  shuffle-backend:
    image: ghcr.io/shuffle/shuffle-backend:latest
    container_name: shuffle-backend
    restart: unless-stopped
    environment:
      - DATASTORE_EMULATOR_HOST=shuffle-database:8000
      - SHUFFLE_APP_HOTLOAD_FOLDER=./shuffle/apps
      - SHUFFLE_FILE_LOCATION=./shuffle/files
    volumes:
      - ./shuffle/config:/shuffle-config
      - ./shuffle/data:/shuffle-data
      - shuffle_data:/shuffle
    ports:
      - "5001:5001"
    networks:
      - soc_network

  shuffle-frontend:
    image: ghcr.io/shuffle/shuffle-frontend:latest
    container_name: shuffle-frontend
    restart: unless-stopped
    environment:
      - BACKEND_HOSTNAME=shuffle-backend
    ports:
      - "3001:3001"
    networks:
      - soc_network
    depends_on:
      - shuffle-backend

  shuffle-database:
    image: ghcr.io/shuffle/shuffle-database:latest
    container_name: shuffle-database
    restart: unless-stopped
    volumes:
      - ./shuffle/data/database:/shuffle-database
    networks:
      - soc_network
```

### 6.2 Création des Workflows de Triage

Une fois Shuffle SOAR installé, vous pourrez créer des workflows de triage via l'interface web. Voici un exemple de workflow de triage automatisé à implémenter :

1. **Workflow de Triage des Alertes Suricata**

```
Déclencheur: Nouvelle alerte Suricata dans Elasticsearch
Actions:
1. Récupérer les détails de l'alerte
2. Vérifier la signature de l'alerte
3. Si score de sévérité < 3, marquer comme faux positif
4. Si score de sévérité >= 3 et < 7, enrichir avec VirusTotal et AbuseIPDB
5. Si score de sévérité >= 7, créer un incident dans TheHive
6. Envoyer notification selon la sévérité
```

2. **Workflow de Triage des Anomalies IA**

```
Déclencheur: Détection d'anomalie par le modèle TensorFlow
Actions:
1. Récupérer les détails de l'anomalie
2. Enrichir avec contexte (utilisateur, machine, historique)
3. Calculer un score de risque basé sur le contexte
4. Si score de risque > seuil, créer un incident dans TheHive
5. Envoyer notification à l'équipe SOC
```

## 7. Couche d'Orchestration et Réponse

### 7.1 Installation et Configuration de TheHive

Ajoutez les services TheHive et Cassandra au fichier `docker-compose.yml` :

```yaml
  cassandra:
    image: cassandra:4
    container_name: cassandra
    restart: unless-stopped
    environment:
      - MAX_HEAP_SIZE=1G
      - HEAP_NEWSIZE=300M
    volumes:
      - ./thehive/data/cassandra:/var/lib/cassandra
    networks:
      - soc_network

  thehive:
    image: strangebee/thehive:latest
    container_name: thehive
    restart: unless-stopped
    depends_on:
      - cassandra
      - elasticsearch
    ports:
      - "9000:9000"
    environment:
      - CQL_HOSTNAMES=cassandra
      - ELASTICSEARCH_HOSTNAMES=elasticsearch
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme
    volumes:
      - ./thehive/config:/etc/thehive
      - thehive_data:/opt/thp/thehive/data
    networks:
      - soc_network
```

Créez un fichier de configuration pour TheHive dans `thehive/config/application.conf` :

```conf
play.http.secret.key="changeme"

# Database configuration
db {
  provider: janusgraph
  janusgraph {
    storage {
      backend: cql
      hostname: ["cassandra"]
      cql {
        cluster-name: thp
        keyspace: thehive
      }
    }
  }
}

# Elasticsearch configuration
search {
  index {
    name: thehive
    shards: 5
    replicas: 0
  }
  elasticsearch {
    hosts: ["http://elasticsearch:9200"]
    username: "elastic"
    password: "changeme"
  }
}

# Authentication configuration
auth {
  providers: [
    {
      name: local
      type: local
      order: 1
    }
  ]
}

# Default user configuration
user {
  initialUsers: [
    {
      login: "admin"
      password: "changeme"
      profile: "admin"
    }
  ]
}
```

### 7.2 Installation et Configuration de Cortex

Ajoutez le service Cortex au fichier `docker-compose.yml` :

```yaml
  cortex:
    image: thehiveproject/cortex:latest
    container_name: cortex
    restart: unless-stopped
    depends_on:
      - elasticsearch
    ports:
      - "9001:9001"
    volumes:
      - ./cortex/config:/etc/cortex
      - cortex_data:/opt/cortex/data
    networks:
      - soc_network
```

Créez un fichier de configuration pour Cortex dans `cortex/config/application.conf` :

```conf
play.http.secret.key="changeme"

# Elasticsearch configuration
search {
  index {
    name: cortex
    shards: 5
    replicas: 0
  }
  elasticsearch {
    hosts: ["http://elasticsearch:9200"]
    username: "elastic"
    password: "changeme"
  }
}

# Authentication configuration
auth {
  providers: [
    {
      name: local
      type: local
      order: 1
    }
  ]
}

# Default user configuration
user {
  initialUsers: [
    {
      login: "admin"
      password: "changeme"
      profile: "admin"
    }
  ]
}

# Analyzer configuration
analyzer {
  urls: [
    "https://download.thehive-project.org/analyzers.json"
  ]
}
```

### 7.3 Création des Workflows de Réponse

Une fois Shuffle SOAR, TheHive et Cortex installés, vous pourrez créer des workflows de réponse via l'interface web de Shuffle. Voici un exemple de workflow de réponse automatisée à implémenter :

1. **Workflow de Réponse aux Incidents de Malware**

```
Déclencheur: Nouvel incident de type "malware" dans TheHive
Actions:
1. Récupérer les détails de l'incident
2. Analyser les fichiers suspects avec Cortex
3. Isoler la machine infectée via l'API de l'EDR
4. Bloquer les domaines malveillants sur le pare-feu
5. Créer une tâche de nettoyage dans TheHive
6. Envoyer un rapport à l'équipe SOC
```

2. **Workflow de Réponse aux Attaques par Force Brute**

```
Déclencheur: Nouvel incident de type "brute force" dans TheHive
Actions:
1. Récupérer les détails de l'incident
2. Bloquer l'adresse IP source sur le pare-feu
3. Vérifier si d'autres systèmes ont été ciblés
4. Réinitialiser les mots de passe des comptes compromis
5. Créer une tâche de vérification dans TheHive
6. Envoyer un rapport à l'équipe SOC
```

## 8. Couche Interface et Collaboration

### 8.1 Configuration de Kibana

Kibana a déjà été configuré dans la section 4.1. Pour configurer les tableaux de bord SIEM, connectez-vous à l'interface Kibana et suivez ces étapes :

1. Accédez à "Security" dans le menu principal
2. Cliquez sur "Add data" pour configurer les sources de données
3. Sélectionnez "Suricata" et suivez les instructions
4. Sélectionnez "Zeek" et suivez les instructions
5. Accédez à "Overview" pour voir les tableaux de bord prédéfinis

### 8.2 Installation et Configuration de Grafana

Ajoutez le service Grafana au fichier `docker-compose.yml` :

```yaml
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=changeme
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/config:/etc/grafana
      - grafana_data:/var/lib/grafana
    networks:
      - soc_network
```

Créez un fichier de configuration pour Grafana dans `grafana/config/grafana.ini` :

```ini
[server]
protocol = http
http_port = 3000
domain = localhost

[security]
admin_user = admin
admin_password = changeme
disable_gravatar = true

[auth.anonymous]
enabled = false

[analytics]
reporting_enabled = false
check_for_updates = true

[dashboards]
default_home_dashboard_path = /etc/grafana/dashboards/soc_overview.json
```

Une fois Grafana installé, configurez une source de données Elasticsearch :

1. Connectez-vous à l'interface Grafana
2. Accédez à "Configuration" > "Data Sources"
3. Cliquez sur "Add data source"
4. Sélectionnez "Elasticsearch"
5. Configurez les paramètres suivants :
   - Name: Elasticsearch
   - URL: http://elasticsearch:9200
   - Access: Server (default)
   - Basic Auth: Enabled
   - User: elastic
   - Password: changeme
   - Index name: suricata-*
   - Time field name: @timestamp
6. Cliquez sur "Save & Test"

## 9. Couche Simulation et Tests

### 9.1 Installation et Configuration de MITRE Caldera

Ajoutez le service MITRE Caldera au fichier `docker-compose.yml` :

```yaml
  caldera:
    image: mitre/caldera:latest
    container_name: caldera
    restart: unless-stopped
    ports:
      - "8888:8888"
    volumes:
      - ./caldera/config:/opt/caldera/conf
      - ./caldera/data:/opt/caldera/data
    networks:
      - soc_network
```

Créez un fichier de configuration pour MITRE Caldera dans `caldera/config/default.yml` :

```yaml
api_key: ADMIN123
crypto_type: local
encryption_key: ADMIN123
exfil_dir: /tmp
host: 0.0.0.0
port: 8888
plugins:
  - access
  - atomic
  - compass
  - debrief
  - fieldmanual
  - gameboard
  - manx
  - response
  - sandcat
  - stockpile
  - training
users:
  admin:
    password: admin
    permissions:
      - red
      - blue
      - app
```

## 10. Intégration et Tests de l'Ensemble

Une fois tous les composants installés et configurés, lancez l'ensemble de la solution :

```bash
cd ~/soc-ai-solution
docker-compose up -d
```

Vérifiez que tous les services sont en cours d'exécution :

```bash
docker-compose ps
```

### Tests d'Intégration

1. **Test de la Collecte de Données**
   - Générez du trafic réseau suspect (par exemple, avec Nmap)
   - Vérifiez que Suricata et Zeek génèrent des logs
   - Vérifiez que les logs sont envoyés à Elasticsearch

2. **Test de la Détection**
   - Vérifiez les alertes dans Kibana SIEM
   - Vérifiez que le modèle TensorFlow détecte les anomalies

3. **Test du Triage Automatisé**
   - Vérifiez que les workflows Shuffle sont déclenchés
   - Vérifiez que les alertes sont correctement triées

4. **Test de la Réponse aux Incidents**
   - Créez un incident de test dans TheHive
   - Vérifiez que les workflows de réponse sont déclenchés
   - Vérifiez que les actions de remédiation sont exécutées

## 11. Maintenance et Mise à Jour

### Sauvegarde des Données

Configurez des sauvegardes régulières pour les données critiques :

```bash
# Création d'un script de sauvegarde
cat > ~/soc-ai-solution/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/path/to/backups/$(date +%Y-%m-%d)"
mkdir -p $BACKUP_DIR

# Sauvegarde Elasticsearch
docker exec elasticsearch elasticsearch-backup snapshot -r backup-repo -s snapshot-$(date +%Y-%m-%d)

# Sauvegarde TheHive
docker exec thehive thehive-backup -o $BACKUP_DIR/thehive-backup.zip

# Sauvegarde des configurations
cp -r ~/soc-ai-solution/*/config $BACKUP_DIR/configs/

# Compression des sauvegardes
tar -czf $BACKUP_DIR.tar.gz $BACKUP_DIR
rm -rf $BACKUP_DIR
EOF

chmod +x ~/soc-ai-solution/backup.sh

# Ajout d'une tâche cron pour les sauvegardes quotidiennes
(crontab -l 2>/dev/null; echo "0 2 * * * ~/soc-ai-solution/backup.sh") | crontab -
```

### Mise à Jour des Composants

Pour mettre à jour les composants, suivez ces étapes :

```bash
cd ~/soc-ai-solution

# Sauvegarde des configurations
mkdir -p backup
cp -r */config backup/

# Mise à jour des images Docker
docker-compose pull

# Redémarrage des services
docker-compose down
docker-compose up -d

# Vérification des services
docker-compose ps
```

### Maintenance des Règles et Modèles

1. **Mise à jour des règles Suricata**

```bash
# Mise à jour des règles Suricata
docker exec suricata suricata-update
```

2. **Réentraînement des modèles TensorFlow**

Accédez au notebook Jupyter et exécutez le script d'entraînement périodiquement pour maintenir la précision du modèle.

## Conclusion

Ce guide d'implémentation vous a fourni les étapes détaillées pour déployer une solution complète de SOC augmentée par l'IA en utilisant exclusivement des outils open source. En suivant ces instructions, vous pourrez mettre en place une infrastructure de cybersécurité robuste, évolutive et adaptée à vos besoins spécifiques.

N'hésitez pas à adapter les configurations en fonction de votre environnement et de vos exigences particulières. La nature modulaire de cette architecture vous permet d'ajouter, de remplacer ou de personnaliser des composants selon vos besoins.
