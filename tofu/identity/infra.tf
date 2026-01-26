# Policy for infrastructure secrets all hosts can read
resource "vault_policy" "infra" {
  name = "infra"
  policy = <<-EOT
    path "secret/data/infra/*" {
      capabilities = ["read"]
    }
    path "secret/metadata/infra/*" {
      capabilities = ["list", "read"]
    }
  EOT
}
