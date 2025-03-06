provider "google" {
  credentials = file("/Users/osh6/Documents/GitHub/aiscaler/src/terraform/terraform-sa-key.json")
  project     = "aiscaler"
  region      = "us-central1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# Génération de la clé SSH (4096 bits) pour se connecter à l'instance
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Sauvegarde locale de la clé privée (pour pouvoir l'utiliser pour la connexion)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/id_rsa"
  file_permission = "0600"
}

# Sauvegarde locale de la clé publique (facultatif)
resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/id_rsa.pub"
}

# Ajout de la clé SSH aux métadonnées du projet GCP pour autoriser l'accès SSH
resource "google_compute_project_metadata" "ssh_keys" {
  metadata = {
    ssh-keys = "aiscaler:${tls_private_key.ssh_key.public_key_openssh}"
  }
}

# Création du VPC
resource "google_compute_network" "vpc_aiscaler" {
  name                    = "vpc-aiscaler-${random_id.suffix.hex}"
  auto_create_subnetworks = false
}

# Création du sous-réseau
resource "google_compute_subnetwork" "subnet_aiscaler" {
  name          = "subnet-aiscaler-${random_id.suffix.hex}"
  ip_cidr_range = "10.0.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_aiscaler.id
}

# Règle de pare-feu pour autoriser SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-${random_id.suffix.hex}"
  network = google_compute_network.vpc_aiscaler.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Création d'une instance pour le conteneur Ubuntu
resource "google_compute_instance" "ubuntu_container" {
  name         = "instance-ubuntu-container-${random_id.suffix.hex}"
  machine_type = "e2-micro"
  zone         = "us-central1-b"
  
  boot_disk {
    initialize_params {
      # Pour cet exemple, nous utilisons une image Container-Optimized OS (COS)
      image = "cos-cloud/cos-stable"
    }
  }

  # Nous n'ajoutons pas la clé SSH dans les métadonnées de l'instance
  # car elle est déjà définie au niveau du projet via google_compute_project_metadata.ssh_keys.
  metadata = {
    "gce-container-declaration" = <<-EOF
      spec:
        containers:
          - name: ubuntu-container
            image: "ubuntu:latest"
            command: ["/bin/bash", "-c", "while true; do sleep 3600; done"]
        restartPolicy: Always
    EOF
  }

  network_interface {
    network    = google_compute_network.vpc_aiscaler.id
    subnetwork = google_compute_subnetwork.subnet_aiscaler.id
    access_config {}
  }
}

# Output pour récupérer l'IP externe de l'instance
output "ubuntu_container_external_ip" {
  description = "IP externe de l'instance ubuntu_container"
  value       = google_compute_instance.ubuntu_container.network_interface[0].access_config[0].nat_ip
}
