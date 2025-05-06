#!/bin/bash

# Setzen des Oracle-Passworts
ORACLE_PWD="AP3xpreSS"

# Schritt 1: Verzeichnisse erstellen und Berechtigungen setzen
echo "Erstelle Verzeichnisse und setze Berechtigungen..."
sudo bash -c "
  mkdir -p ./express/{oradata,cfgtoollogs,scripts/startup,scripts/setup} && 
  chown -R 54321:54321 ./express/{oradata,cfgtoollogs} &&
  mkdir -p ./ORDS/{variables,config} &&
  chown -R 54321:54321 ./ORDS/{config,variables} &&
  chmod -R 777 ./ORDS/config
"

# Schritt 2: .env-Datei erstellen
echo "ORACLE_PWD=$ORACLE_PWD" > ./.env

# Schritt 3: APEX herunterladen und entpacken
echo "Lade APEX herunter..."
curl -o apex.zip https://download.oracle.com/otn_software/apex/apex-latest.zip && \
unzip -o apex.zip
rm apex.zip

# Schritt 4: Docker-Images herunterladen
echo "Lade Docker-Images herunter..."
docker pull container-registry.oracle.com/database/express:latest
docker pull container-registry.oracle.com/database/ords:latest

# Schritt 5: Docker-Netzwerk erstellen
echo "Erstelle Docker-Netzwerk..."
docker network create rad-oracle-apex-temp

# Schritt 6: Temporären Express-Container starten
echo "Starte temporären Oracle Express Container..."
docker run -d \
    --name rad-oracle-apex-express-temp \
    --network rad-oracle-apex-temp \
    --hostname express \
    --env-file ./.env \
    -p 1521:1521 \
    -v "$(pwd)/express/oradata:/opt/oracle/oradata" \
    -v "$(pwd)/express/cfgtoollogs:/opt/oracle/cfgtoollogs" \
    -v "$(pwd)/apex:/opt/oracle/oradata/apex" \
    container-registry.oracle.com/database/express:latest

# Warten auf Datenbankbereitschaft
echo "Warte auf Oracle Express Datenbank..."
while ! docker exec rad-oracle-apex-express-temp /opt/oracle/checkDBStatus.sh > /dev/null; do
  sleep 10
  echo "Datenbank wird noch initialisiert..."
done

# Schritt 7: APEX installieren
echo "Installiere APEX..."
docker exec -i rad-oracle-apex-express-temp bash -c '
cd /opt/oracle/oradata/apex
sqlplus sys/$ORACLE_PWD@express:1521/XEPDB1 AS SYSDBA <<EOF
@apexins.sql SYSAUX SYSAUX TEMP /i/
@apxchpwd.sql
$ORACLE_PWD
$ORACLE_PWD
admin@example.com
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY $ORACLE_PWD;
CREATE PROFILE apex_public LIMIT PASSWORD_LIFE_TIME UNLIMITED;
ALTER USER APEX_PUBLIC_USER PROFILE apex_public;
quit
EOF
'

# Schritt 8: ORDS konfigurieren
echo "Konfiguriere ORDS..."
docker run -i \
  --rm \
  --network rad-oracle-apex-temp \
  --name rad-oracle-apex-ords-temp \
  -v "$(pwd)/ORDS/config:/etc/ords/config" \
  -v "$(pwd)/apex:/opt/oracle/apex" \
  container-registry.oracle.com/database/ords:latest \
  install \
    --admin-user SYS \
    --db-hostname express \
    --db-port 1521 \
    --db-servicename XEPDB1 \
    --feature-sdw true \
    --password-stdin <<< "$ORACLE_PWD"

# Schritt 9: Temporäre Container entfernen
echo "Entferne temporäre Container..."
docker rm -f rad-oracle-apex-express-temp rad-oracle-apex-ords-temp
docker network rm rad-oracle-apex-temp

# Schritt 10: Docker-Compose-Datei erstellen
echo "Erstelle docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
version: '3'

services:
  express:
    image: container-registry.oracle.com/database/express:latest
    container_name: rad-oracle-apex-express
    restart: unless-stopped
    env_file:
      - ./.env
    networks:
      - apex
    volumes:
      - ./express/oradata:/opt/oracle/oradata
      - ./express/scripts/setup:/opt/oracle/scripts/setup
      - ./express/scripts/startup:/opt/oracle/scripts/startup
      - ./apex:/opt/oracle/oradata/apex
    healthcheck:
      test: ["CMD", "/opt/oracle/checkDBStatus.sh"]
      interval: 30s
      timeout: 30s
      retries: 100
      start_period: 600s

  ords:
    image: container-registry.oracle.com/database/ords:latest
    container_name: rad-oracle-apex-ords
    restart: unless-stopped
    volumes:
      - ./ORDS/variables:/opt/oracle/variables
      - ./ORDS/config:/etc/ords/config
      - ./apex:/opt/oracle/apex
    networks:
      - apex
    ports:
      - 8080:8080
    depends_on:
      express:
        condition: service_healthy

networks:
  apex:
    name: rad-oracle-apex
EOF

# Schritt 11: Docker-Compose starten
echo "Starte Docker Compose..."
docker-compose up -d

echo "Oracle APEX Installation abgeschlossen. Zugriff unter http://localhost:8080/ords"
