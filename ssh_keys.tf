# see https://registry.terraform.io/providers/hashicorp/tls/4.2.0/docs/resources/private_key
resource "tls_private_key" "main" {
  algorithm = "ED25519"
}

# # see https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/compute_ssh_key
# resource "ibm_compute_ssh_key" "main" {
#   label      = var.project_identifier
#   notes      = "SSH Key for ${var.project_identifier}."
#   public_key = tls_private_key.main.public_key_openssh
# }

# Exporting the private part of an SSH key is strictly not recommended.
# It is done here merely for demonstration purposes, do not replicate!
# see https://registry.terraform.io/providers/hashicorp/local/2.7.0/docs/resources/file
resource "local_sensitive_file" "private_ssh_key" {
  filename        = "${path.module}/dist/id_ed25519"
  content         = tls_private_key.main.private_key_openssh
  file_permission = "0600"
}