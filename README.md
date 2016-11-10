# https://hub.docker.com/_/consul/
# https://github.com/kurron/docker-nomad
docker run --rm -it consul:v0.7.0 agent --help
docker run --rm -it mrduguo/docker-nomad:0.4.1 agent --help

## Run Standalone Dev Environment

### Bring Up Consul

    # docker-machine ssh
    docker rm -f consul-standalone
    docker run -d --net=host --name consul-standalone consul:v0.7.0 agent -dev -client 0.0.0.0
    docker logs consul-standalone
    # open http://192.168.99.100:8500

### Bring Up Nomad

    docker rm -f nomad-standalone
    docker run -d --net=host --name nomad-standalone -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e 'NOMAD_LOCAL_CONFIG={"bind_addr":"0.0.0.0","advertise":{"http":"192.168.99.100:4646","rpc":"192.168.99.100:4647","serf":"192.168.99.100:4648"}}' mrduguo/docker-nomad:0.4.1 agent -dev -network-interface=eth1
    docker logs nomad-standalone
    # open http://192.168.99.100:4646/v1/status/peers
    # open http://192.168.99.100:4646/v1/agent/servers

### Bring Up API Gateway

    docker rm -f gateway-standalone
    docker run -d --net=host --name gateway-standalone mrduguo/docker-gateway
    docker logs gateway-standalone
    # open http://192.168.99.100/

### Run Applications

    docker run --rm -it --net=host mrduguo/docker-nomad:0.4.1 run /hello-world.hcl
    # open http://192.168.99.100/hello-group-hello/
    
    docker run --rm -it --net=host mrduguo/docker-nomad:0.4.1 stop helloworld-v1


## Run Clustering Environment

### Docker Machine Cluster

#### Bring Up Nodes

    # docker-machine rm -f nomad-master-01 nomad-master-02 nomad-master-03 nomad-slave-01 nomad-slave-02

    docker-machine create --driver virtualbox nomad-master-01
    docker-machine create --driver virtualbox nomad-master-02
    docker-machine create --driver virtualbox nomad-master-03
    docker-machine create --driver virtualbox nomad-slave-01
    docker-machine create --driver virtualbox nomad-slave-02

    docker -H $(docker-machine ip nomad-master-01):2376 ps
    docker -H $(docker-machine ip nomad-master-02):2376 ps
    docker -H $(docker-machine ip nomad-master-03):2376 ps
    docker -H $(docker-machine ip nomad-slave-01):2376 ps
    docker -H $(docker-machine ip nomad-slave-02):2376 ps

    docker-machine ssh nomad-master-01 sudo netstat -palnt | grep LISTEN

#### Bring Up Consul

    docker -H $(docker-machine ip nomad-master-01):2376 rm -f consul-master
    docker -H $(docker-machine ip nomad-master-02):2376 rm -f consul-master
    docker -H $(docker-machine ip nomad-master-03):2376 rm -f consul-master
    docker -H $(docker-machine ip nomad-slave-01):2376 rm -f consul-slave
    docker -H $(docker-machine ip nomad-slave-02):2376 rm -f consul-slave

    docker -H $(docker-machine ip nomad-master-01):2376 run -d --net=host -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' --name consul-master consul:v0.7.0 agent -server -ui -bind=$(docker-machine ip nomad-master-01) -retry-join=$(docker-machine ip nomad-master-01) -bootstrap-expect=3 -client 0.0.0.0
    docker -H $(docker-machine ip nomad-master-02):2376 run -d --net=host -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' --name consul-master consul:v0.7.0 agent -server -ui -bind=$(docker-machine ip nomad-master-02) -retry-join=$(docker-machine ip nomad-master-01) -bootstrap-expect=3 -client 0.0.0.0
    docker -H $(docker-machine ip nomad-master-03):2376 run -d --net=host -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' --name consul-master consul:v0.7.0 agent -server -ui -bind=$(docker-machine ip nomad-master-03) -retry-join=$(docker-machine ip nomad-master-01) -bootstrap-expect=3 -client 0.0.0.0
    docker -H $(docker-machine ip nomad-slave-01):2376 run -d --net=host -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' --name consul-slave consul:v0.7.0 agent -bind=$(docker-machine ip nomad-slave-01) -retry-join=$(docker-machine ip nomad-master-01) -client 0.0.0.0
    docker -H $(docker-machine ip nomad-slave-02):2376 run -d --net=host -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}' --name consul-slave consul:v0.7.0 agent -bind=$(docker-machine ip nomad-slave-02) -retry-join=$(docker-machine ip nomad-master-01) -client 0.0.0.0


    docker -H $(docker-machine ip nomad-master-01):2376 exec -it consul-master consul info
    docker -H $(docker-machine ip nomad-master-01):2376 exec -it consul-master consul members
    docker -H $(docker-machine ip nomad-master-01):2376 logs -f consul-master
    # open http://$(docker-machine ip nomad-master-01):8500


#### Bring Up Nomad

    # docker -H $(docker-machine ip nomad-master-01):2376 run --rm -it mrduguo/docker-nomad:0.4.1 agent --help

    docker -H $(docker-machine ip nomad-master-01):2376 rm -f nomad-master
    docker -H $(docker-machine ip nomad-master-02):2376 rm -f nomad-master
    docker -H $(docker-machine ip nomad-master-03):2376 rm -f nomad-master

    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-01)
    docker-machine ssh nomad-master-01 docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "'NOMAD_LOCAL_CONFIG={\"bind_addr\":\"$DOCKER_MACHINE_IP\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}'" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data

    docker -H $(docker-machine ip nomad-master-01):2376 logs nomad-master

    docker-machine ssh nomad-master-01 sudo netstat -palnt | grep LISTEN

    docker-machine ssh nomad-master-01 curl -v http://$DOCKER_MACHINE_IP:4646/v1/agent/servers


    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-02)
    docker-machine ssh nomad-master-02 docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "'NOMAD_LOCAL_CONFIG={\"bind_addr\":\"$DOCKER_MACHINE_IP\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}'" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data
    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-03)
    docker-machine ssh nomad-master-03 docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "'NOMAD_LOCAL_CONFIG={\"bind_addr\":\"$DOCKER_MACHINE_IP\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}'" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data


    docker -H $(docker-machine ip nomad-master-01):2376 logs nomad-master
    # open http://192.168.99.100:4646/v1/agent/servers

#### Bring Up Nomad Windows

    # docker -H $(docker-machine ip nomad-master-01):2376 run --rm -it mrduguo/docker-nomad:0.4.1 agent --help

    docker -H $(docker-machine ip nomad-master-01):2376 rm -f nomad-master
    docker -H $(docker-machine ip nomad-master-02):2376 rm -f nomad-master
    docker -H $(docker-machine ip nomad-master-03):2376 rm -f nomad-master

    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-01)
    export DOCKER_MACHINE_IP=192.168.99.101
    export DOCKER_MACHINE_IP=192.168.99.102
    export DOCKER_MACHINE_IP=192.168.99.103
    docker rm -f nomad-master
    docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "NOMAD_LOCAL_CONFIG={\"bind_addr\":\"0.0.0.0\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data
    docker inspect nomad-master
    netstat -palnt | grep LISTEN
    docker logs -f nomad-master

    docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e 'NOMAD_LOCAL_CONFIG={"bind_addr":"0.0.0.0","advertise":{"http":"192.168.99.101:4646","rpc":"192.168.99.101:4647","serf":"192.168.99.101:4648"},"consul": { "address": "192.168.99.101:8500"}}' mrduguo/docker-nomad:0.4.1 agent -dev  -network-interface eth1

    docker run --rm  -it mrduguo/docker-nomad:0.4.1 run -address=http://192.168.99.101:4646 /hello-world.hcl
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 stop -address=http://192.168.99.101:4646  helloworld-v1


    docker-machine ssh nomad-master-01 sudo netstat -palnt | grep LISTEN

    docker-machine ssh nomad-master-01 curl -v http://$DOCKER_MACHINE_IP:4646/v1/agent/servers


    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-02)
    export DOCKER_MACHINE_IP=192.168.99.103
    docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "'NOMAD_LOCAL_CONFIG={\"bind_addr\":\"$DOCKER_MACHINE_IP\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}'" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data
    export DOCKER_MACHINE_IP=$(docker-machine ip nomad-master-03)
     docker run -d --net=host --name nomad-master -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "'NOMAD_LOCAL_CONFIG={\"bind_addr\":\"$DOCKER_MACHINE_IP\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}'" mrduguo/docker-nomad:0.4.1 agent -server -bootstrap-expect=3 -network-interface=eth1 -data-dir=/nomad-data


    docker -H $(docker-machine ip nomad-master-01):2376 logs nomad-master
    # open http://192.168.99.100:4646/v1/agent/servers



    export DOCKER_MACHINE_IP=192.168.99.104
        docker rm -f nomad-slave
        docker run -d --net=host --name nomad-slave -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e "NOMAD_LOCAL_CONFIG={\"bind_addr\":\"0.0.0.0\",\"advertise\":{\"http\":\"$DOCKER_MACHINE_IP:4646\",\"rpc\":\"$DOCKER_MACHINE_IP:4647\",\"serf\":\"$DOCKER_MACHINE_IP:4648\"},\"consul\": { \"address\": \"$DOCKER_MACHINE_IP:8500\"}}" mrduguo/docker-nomad:0.4.1 agent -client -network-interface=eth1 -data-dir=/nomad-data
        docker inspect nomad-master
        netstat -palnt | grep LISTEN
        docker logs -f nomad-master


### Run A Container

    docker run --rm  -it mrduguo/docker-nomad:0.4.1 run -address=http://192.168.99.100:4646 /hello-world.hcl

    docker run --rm  -it mrduguo/docker-nomad:0.4.1 status -address=http://192.168.99.100:4646 helloworld-v1
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 logs -address=http://192.168.99.100:4646  helloworld-v1
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 inspect -address=http://192.168.99.100:4646  helloworld-v1
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 stop -address=http://192.168.99.100:4646  helloworld-v1


    # docker run --rm  -it -v $(pwd):/pwd mrduguo/docker-nomad:0.4.1 run -address=http://192.168.99.100:4646 hello-world.hcl
    # open http://192.168.99.100:8500/v1/catalog/service/hello-group-hello



## Run In Linux Production Environment?

### Bring Up Consul


    docker rm -f nomad-standalone
    docker rm -f consul-standalone
    docker run -d -p 8300:8300 -p 8301:8301 -p 8302:8302 -p 8400:8400 -p 8500:8500 --name consul-standalone consul:v0.7.0 agent -dev -client 0.0.0.0
    docker logs consul-standalone
    # open http://192.168.99.100:8500

### Bring Up Nomad

    docker rm -f nomad-standalone
    docker run -d -p 4646:4646 -p 4647:4647 -p 4648:4648 --name nomad-standalone -v /tmp:/tmp -v /var/run/docker.sock:/var/run/docker.sock -e 'NOMAD_LOCAL_CONFIG={"bind_addr":"0.0.0.0","advertise":{"http":"192.168.99.100:4646","rpc":"192.168.99.100:4647","serf":"192.168.99.100:4648"},"consul": { "address": "192.168.99.100:8500"}}' mrduguo/docker-nomad:0.4.1 agent -dev
    docker logs nomad-standalone
    # open http://192.168.99.100:4646/v1/agent/servers

### Run A Container

    docker run --rm  -it mrduguo/docker-nomad:0.4.1 stop -address=http://192.168.99.100:4646  helloworld-v1

    docker run --rm  -it -v $(pwd):/pwd mrduguo/docker-nomad:0.4.1 run -address=http://192.168.99.100:4646 hello-world.hcl

    docker run --rm  -it mrduguo/docker-nomad:0.4.1 status -address=http://192.168.99.100:4646 helloworld-v1
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 logs -address=http://192.168.99.100:4646  helloworld-v1
    docker run --rm  -it mrduguo/docker-nomad:0.4.1 inspect -address=http://192.168.99.100:4646  helloworld-v1


## Build

    docker build -t mrduguo/docker-nomad:latest .

    docker tag mrduguo/docker-nomad:latest mrduguo/docker-nomad:0.4.1

    docker push mrduguo/docker-nomad
