resource "garage_bucket" "tofu_state" {
  name = "tofu-state"
}

resource "garage_access_key" "governance" {
  name          = "governance-tofu"
  never_expires = true
}

resource "garage_permission" "governance_tofu_state" {
  access_key_id = garage_access_key.governance.access_key_id
  bucket_id     = garage_bucket.tofu_state.id
  read          = true
  write         = true
  owner         = false
}

output "governance_access_key_id" {
  value     = garage_access_key.governance.access_key_id
  sensitive = true
}

output "governance_secret_access_key" {
  value     = garage_access_key.governance.secret_access_key
  sensitive = true
}
