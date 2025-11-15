output "instance_external_ip" {
  value = google_compute_instance.flask_vm.network_interface[0].access_config[0].nat_ip
}

output "app_url" {
  value = format("http://%s:5000", google_compute_instance.flask_vm.network_interface[0].access_config[0].nat_ip)
}
