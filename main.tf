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

# --- Nginx Web Server ---
resource "docker_image" "nginx" {
  name = "nginx:latest"
}

resource "docker_container" "nginx_server" {
  name  = "nginx-server"
  image = docker_image.nginx.name

  ports {
    internal = 80
    external = 8080
  }

  restart = "always"
}

# --- PostgreSQL Database ---
resource "docker_image" "postgres" {
  name = "postgres:latest"
}

resource "docker_volume" "postgres_data" {
  name = "postgres_data"
}

resource "docker_container" "postgres_db" {
  name  = "postgres-db"
  image = docker_image.postgres.name

  ports {
    internal = 5432
    external = 5432
  }

  volumes {
    container_path = "/var/lib/postgresql/data"
    volume_name    = docker_volume.postgres_data.name
  }

  env = [
    "POSTGRES_USER=flaskuser",
    "POSTGRES_PASSWORD=flaskpass",
    "POSTGRES_DB=flaskdb"
  ]

  restart = "always"
}

# --- Flask Backend ---
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

  env = [
    "DATABASE_URL=postgresql://flaskuser:flaskpass@postgres-db:5432/flaskdb"
  ]

  depends_on = [docker_container.postgres_db]

  command = [
    "sh", "-c",
    <<-EOF
    pip install flask psycopg2-binary &&
    echo 'from flask import Flask, request, jsonify
import psycopg2
app = Flask(__name__)
conn = psycopg2.connect("dbname=flaskdb user=flaskuser password=flaskpass host=postgres-db")
cursor = conn.cursor()
cursor.execute("CREATE TABLE IF NOT EXISTS messages (id SERIAL PRIMARY KEY, content TEXT)")
conn.commit()
@app.route("/", methods=["GET"])
def home():
    return "Flask is connected to PostgreSQL!"
@app.route("/add", methods=["POST"])
def add():
    data = request.get_json()
    cursor.execute("INSERT INTO messages (content) VALUES (%s) RETURNING id", (data["content"],))
    conn.commit()
    return jsonify({"message": "Inserted", "id": cursor.fetchone()[0]})
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)' > app.py &&
    python3 app.py
    EOF
  ]
}
