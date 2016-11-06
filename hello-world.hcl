job "helloworld-v1" {
  datacenters = [
    "dc1"
  ]
  type = "service"

  update {
    stagger = "30s"
    max_parallel = 1
  }

  group "hello-group" {
    count = 2
    task "hello-task" {
      driver = "docker"
      config {
        image = "dockercloud/hello-world"
        port_map {
          http = 80
        }
      }
      service {
        name = "${TASKGROUP}-hello"
        tags = [
          "helloworld"
        ]
        port = "http"
        check {
          name = "alive"
          type = "tcp"
          interval = "10s"
          timeout = "2s"
        }
      }
      resources {
        cpu = 100
        memory = 200
        network {
          mbits = 1
          port "http" {
          }
          port "httpx" {
          }
        }
      }
    }
  }
}