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
  owner         = true
}

output "governance_access_key_id" {
  value     = garage_access_key.governance.access_key_id
  sensitive = true
}

output "governance_secret_access_key" {
  value     = garage_access_key.governance.secret_access_key
  sensitive = true
}

# Durable, org-wide bucket for static assets that outlive any single
# kennel deployment (team-page photos, etc.). Anonymous public read is
# enabled by calling the garage admin API once manually after the bucket
# is created, since the henrywhitaker3/garage provider does not expose
# website configuration. The exact request is documented in
# docs/troubleshooting.md under "Enabling website mode on a bucket".
resource "garage_bucket" "scottylabs_assets" {
  name = "scottylabs-assets"
}

resource "garage_access_key" "scottylabs_assets_writer" {
  name          = "scottylabs-assets-writer"
  never_expires = true
}

resource "garage_permission" "scottylabs_assets_writer" {
  access_key_id = garage_access_key.scottylabs_assets_writer.access_key_id
  bucket_id     = garage_bucket.scottylabs_assets.id
  read          = true
  write         = true
  owner         = true
}

output "scottylabs_assets_writer_access_key_id" {
  value     = garage_access_key.scottylabs_assets_writer.access_key_id
  sensitive = true
}

output "scottylabs_assets_writer_secret_access_key" {
  value     = garage_access_key.scottylabs_assets_writer.secret_access_key
  sensitive = true
}
