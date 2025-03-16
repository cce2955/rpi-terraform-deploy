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

# Nginx Image & Container
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
}

# Flask Backend
resource "docker_image" "flask_app" {
  name = "python:3.9-slim"
}

resource "docker_container" "flask_backend" {
  name  = "flask-backend"
  image = "python:3.9-slim"

  ports {
    internal = 5000
    external = 5000
  }

  restart = "always"

command = [
  "sh",
  "-c",
  <<-EOF
    pip install flask &&
    echo 'from flask import Flask
app = Flask(__name__)
@app.route("/")
def home():
    return "Hello from Flask!"
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)' > app.py &&
    python3 app.py
  EOF
]
}
