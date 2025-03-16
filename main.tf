terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_container" "nginx" {
  image = "nginx:latest"
  name  = "nginx-server"
  ports {
    internal = 80
    external = 8080
  }
}
