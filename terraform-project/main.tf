terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {}

# Create a Docker volume for PostgreSQL persistence
resource "docker_volume" "pg_data" {
  name = "postgres_data"
}

# Define PostgreSQL container
resource "docker_container" "postgres" {
  image = "postgres:latest"
  name  = "postgres-db"
  
  env = [
    "POSTGRES_USER=admin",
    "POSTGRES_PASSWORD=supersecret",
    "POSTGRES_DB=mydatabase"
  ]
  
  ports {
    internal = 5432
    external = 5432
  }
  
  volumes {
    volume_name    = docker_volume.pg_data.name
    container_path = "/var/lib/postgresql/data"
  }
}

# Define Nginx container
resource "docker_container" "nginx" {
  image = "nginx:latest"
  name  = "nginx-server"
  
  ports {
    internal = 80
    external = 8080
  }
}
