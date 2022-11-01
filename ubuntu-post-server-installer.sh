#!/bin/bash

apt-get update
apt upgrade -y

apt-get install vim

vim --version

apt-get install install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release -y

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version

docker network create findyspaceservices

mkdir server-tools && cd server-tools

mkdir nginx-proxy-manager && cd nginx-proxy-manager

cat > docker-compose.yml <<EOF
version: '3'
services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm"
      DB_MYSQL_NAME: "npm"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db

  db:
    image: 'jc21/mariadb-aria:latest'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
    volumes:
      - ./data/mysql:/var/lib/mysql
networks:
  default:
    external:
      name: findyspaceservices
EOF

docker-compose up -d

cd ..

mkdir portainer && cd portainer

cat > docker-compose.yml <<EOF
version: '3'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./portainer-data:/data
    ports:
      - '9000:9000'

networks:
  default:
    external:
      name: findyspaceservices

EOF

docker-compose up -d

cd ..

mkdir postgres && cd postgres

cat > postgis.sql <<EOF
CREATE EXTENSION IF NOT EXISTS POSTGIS;
CREATE EXTENSION IF NOT EXISTS POSTGIS_TOPOLOGY;
EOF

cat > Dockerfile <<EOF
FROM postgres:14

RUN apt-get update \
    && apt-get install wget -y \
    && apt-get install postgresql-14-postgis-3 -y \
    && apt-get install postgis -y

COPY ./postgis.sql /docker-entrypoint-initdb.d/

EXPOSE 5432

EOF

cat > docker-compose.yml <<EOF
version: '3'

services:
  db:
    container_name: db
    image: postgres:latest
    build:
      context: .
      dockerfile: Dockerfile
    ports:
    - '5432:5432'
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    env_file:
      - .env
  
  pgadmin:
    links:
      - db
    container_name: pgadmin
    image: dpage/pgadmin4
    ports:
      - '8080:80'
    volumes:
      - /data/pgadmin:/root/.pgadmin
    env_file:
      - .env

networks:
  default:
    external:
      name: findyspaceservices

EOF

cat > .env <<EOF
POSTGRES_USER=$1
POSTGRES_PASSWORD=$2
PGADMIN_DEFAULT_EMAIL=$3
PGADMIN_DEFAULT_PASSWORD=$4
POSTGRES_DB=$5
POSTGRES_PORT=$6

EOF


docker-compose --env-file .env up -d

cat .env

# how to run
# ./installer.sh "DB_USERNAME" "DB_PASSWORD" "PG_ADMIN_EAMIL" "PG_ADMIN_PASSWORD"  "DB_NAME" "DB_PORT"
