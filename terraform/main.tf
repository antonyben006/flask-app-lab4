terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "instant-heading-474717-g6"
  region  = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  name                    = "ben-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "ben-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "private_subnet" {
  name          = "ben-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
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
  zone         = "us-central1-a"
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

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io curl
    systemctl start docker

    export ACCESS_TOKEN=$(gcloud auth print-access-token)
    echo "$ACCESS_TOKEN" | docker login -u oauth2accesstoken --password-stdin https://us-docker.pkg.dev

    docker run -d -p 5000:5000 us-docker.pkg.dev/instant-heading-474717-g6/gcr.io/ben-flask-app:latest
  EOT
}
