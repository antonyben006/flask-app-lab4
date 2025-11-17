terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "assignment-2-478521"
  region  = "northamerica-northeast1"
}

resource "google_compute_network" "vpc_network" {
  name                    = "ben-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "ben-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "northamerica-northeast1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "ben-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "northamerica-northeast1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_firewall" "flask_app" {
  name    = "ben-flask-app-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["flask-app"]
}

resource "google_compute_firewall" "ssh" {
  name    = "ben-allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}

resource "google_compute_instance" "flask_vm" {
  name         = "ben-flask-vm"
  machine_type = "e2-micro"
  zone         = "northamerica-northeast1-a"
  tags         = ["flask-app", "ssh"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -ex
    sudo apt-get update
    sudo apt-get install -y docker.io curl
    sudo systemctl start docker
    sudo systemctl enable docker

    # Authenticate Docker to Artifact Registry (if gcloud is installed)
    if command -v gcloud >/dev/null; then
      export ACCESS_TOKEN=$(gcloud auth print-access-token)
      echo "$ACCESS_TOKEN" | sudo docker login -u oauth2accesstoken --password-stdin northamerica-northeast1-docker.pkg.dev
    fi

    sudo docker pull northamerica-northeast1-docker.pkg.dev/assignment-2-478521/ben-flask-repo/ben-flask-app:latest
    sudo docker run -d --name flask-app -p 5000:5000 --restart always northamerica-northeast1-docker.pkg.dev/assignment-2-478521/ben-flask-repo/ben-flask-app:latest
  EOT

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

output "instance_external_ip" {
  value = google_compute_instance.flask_vm.network_interface[0].access_config[0].nat_ip
}

output "app_url" {
  value = format("http://%s:5000", google_compute_instance.flask_vm.network_interface[0].access_config[0].nat_ip)
}
