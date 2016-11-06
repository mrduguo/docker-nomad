# docker-nomad

Based on https://github.com/kurron/docker-nomad with additional configuration capability via `NOMAD_LOCAL_CONFIG` environment variable.

## hub.docker.io

https://hub.docker.com/r/mrduguo/docker-nomad/


## Run In docker-machine Environment

### Bring Up Consul

        
    docker rm -f dev-nomad
    docker rm -f dev-consul
    docker run -d -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 --name dev-consul consul:v0.7.0 agent -dev -client 0.0.0.0
    docker logs dev-consul
    # open http://192.168.99.100:8500

### Bring Up Nomad
    
    docker rm -f dev-nomad
    docker run -d -p 4646:4646 -p 4647:4647 -p 4648:4648 --name dev-nomad -e 'NOMAD_LOCAL_CONFIG={"bind_addr":"0.0.0.0","advertise":{"http":"192.168.99.100:4646","rpc":"192.168.99.100:4647","serf":"192.168.99.100:4648"},"consul": { "address": "192.168.99.100:8500"}}' mrduguo/docker-nomad:0.4.1 agent -dev
    docker logs dev-nomad
    # open http://192.168.99.100:4646/v1/agent/servers


## Build

    docker build -t mrduguo/docker-nomad:latest .
    
    docker tag mrduguo/docker-nomad:latest mrduguo/docker-nomad:0.4.1
    
    docker push mrduguo/docker-nomad