output "private_key_openssh" {
  value     = tls_private_key.main.private_key_openssh
  sensitive = true
}
