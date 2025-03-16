terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# ----------------------------
# Create a Custom Docker Network
# ----------------------------
resource "docker_network" "flask_network" {
  name = "flask_network"
}

# ----------------------------
# Nginx Image & Container
# ----------------------------
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx" {
  name  = "nginx-server"
  image = docker_image.nginx.name

  ports {
    internal = 80
    external = 8080
  }

  restart = "always"

  networks_advanced {
    name = docker_network.flask_network.name
  }
}

# ----------------------------
# PostgreSQL Database (Persistent Data)
# ----------------------------
resource "docker_image" "postgres" {
  name = "postgres:latest"
}

resource "docker_container" "postgres_db" {
  name  = "postgres-db"
  image = docker_image.postgres.name

  restart = "always"

  env = [
    "POSTGRES_DB=flaskdb",
    "POSTGRES_USER=flaskuser",
    "POSTGRES_PASSWORD=flaskpass"
  ]

  ports {
    internal = 5432
    external = 5432
  }

  # Bind mount for persistent data
  mounts {
    type   = "bind"
    source = "/home/pi/postgres_data"
    target = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = docker_network.flask_network.name
  }
}

# ----------------------------
# Flask Backend (Python + PostgreSQL)
# ----------------------------
resource "docker_image" "flask_app" {
  name = "python:3.9-slim"
}

resource "docker_container" "flask_backend" {
  name  = "flask-backend"
  image = docker_image.flask_app.name

  ports {
    internal = 5000
    external = 5000
  }

  restart = "always"

  networks_advanced {
    name = docker_network.flask_network.name
  }

  command = [
    "sh",
    "-c",
    <<-EOF
      pip install flask psycopg2-binary &&
      echo '
from flask import Flask
import psycopg2

app = Flask(__name__)

# Connect to PostgreSQL
try:
    conn = psycopg2.connect("dbname=flaskdb user=flaskuser password=flaskpass host=postgres-db")
    db_status = "Connected to Database!"
except:
    db_status = "Failed to connect to Database!"

@app.route("/")
def home():
    return db_status

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
      ' > app.py &&
      python3 app.py
    EOF
  ]
}
