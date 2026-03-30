resource "garage_cluster_layout" "this" {
  roles {
    id       = var.garage_node_id
    zone     = "dc1"
    capacity = "1T"
  }
}

resource "garage_bucket" "tofu_state" {
  global_alias = "tofu-state"
}

resource "garage_key" "governance" {
  name = "governance-tofu"
}

resource "garage_bucket_key" "governance_tofu_state" {
  bucket_id     = garage_bucket.tofu_state.id
  access_key_id = garage_key.governance.access_key_id
  read          = true
  write         = true
  owner         = false
}

output "governance_access_key_id" {
  value     = garage_key.governance.access_key_id
  sensitive = true
}

output "governance_secret_access_key" {
  value     = garage_key.governance.secret_access_key
  sensitive = true
}
