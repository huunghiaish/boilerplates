#!/bin/bash
export IP_ADDRESS=10.0.0.72
docker swarm init --advertise-addr=$IP_ADDRESS

##BUILD TRAEFIK
export DOMAIN=t.huunghiaish.com

export NODE_ID=$(docker info -f '{{.Swarm.NodeID}}')
docker network create -d overlay --subnet=10.253.0.0/16 traefik-public
docker node update --label-add traefik-public.traefik-public-certificates=true $NODE_ID
export EMAIL=huunghiaish@gmail.com
export USERNAME=admin
export PASSWORD=Password@123
export HASHED_PASSWORD=$(openssl passwd -apr1 $PASSWORD)
docker stack deploy -c traefik.yml traefik

##BUILD PORTAINER
export DOMAIN=port.t.huunghiaish.com

docker network create --driver=overlay agent_network
docker stack deploy -c port.yml portainer