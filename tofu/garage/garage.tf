resource "garage_bucket" "tofu_state" {
  global_alias = "tofu-state"
}

resource "garage_key" "governance" {
  name = "governance-tofu"
}

resource "garage_bucket_permission" "governance_tofu_state" {
  access_key_id = garage_key.governance.id
  bucket_id     = garage_bucket.tofu_state.id
  read          = true
  write         = true
  owner         = true
}

output "governance_access_key_id" {
  value     = garage_key.governance.id
  sensitive = true
}

output "governance_secret_access_key" {
  value     = garage_key.governance.secret_access_key
  sensitive = true
}

# Durable, org-wide bucket for static assets that outlive any single
# kennel deployment (team-page photos, etc.). Website mode serves
# anonymous public reads over the garage web endpoint.
resource "garage_bucket" "scottylabs_assets" {
  global_alias           = "scottylabs-assets"
  website_enabled        = true
  website_index_document = "index.html"
}

resource "garage_key" "scottylabs_assets_writer" {
  name = "scottylabs-assets-writer"
}

resource "garage_bucket_permission" "scottylabs_assets_writer" {
  access_key_id = garage_key.scottylabs_assets_writer.id
  bucket_id     = garage_bucket.scottylabs_assets.id
  read          = true
  write         = true
  owner         = true
}

output "scottylabs_assets_writer_access_key_id" {
  value     = garage_key.scottylabs_assets_writer.id
  sensitive = true
}

output "scottylabs_assets_writer_secret_access_key" {
  value     = garage_key.scottylabs_assets_writer.secret_access_key
  sensitive = true
}

# Static site bucket for the ScottyLabs documentation hub (CI uploads via
# documentation/.forgejo/workflows/deploy.yml -> nix run .#upload-garage).
resource "garage_bucket" "scottylabs_docs" {
  global_alias           = "scottylabs-docs"
  website_enabled        = true
  website_index_document = "index.html"
}

resource "garage_key" "scottylabs_docs_writer" {
  name = "scottylabs-docs-writer"
}

resource "garage_bucket_permission" "scottylabs_docs_writer" {
  access_key_id = garage_key.scottylabs_docs_writer.id
  bucket_id     = garage_bucket.scottylabs_docs.id
  read          = true
  write         = true
  owner         = true
}

output "scottylabs_docs_writer_access_key_id" {
  value     = garage_key.scottylabs_docs_writer.id
  sensitive = true
}

output "scottylabs_docs_writer_secret_access_key" {
  value     = garage_key.scottylabs_docs_writer.secret_access_key
  sensitive = true
}

# Shared sccache compilation cache for Rust builds
resource "garage_bucket" "sccache" {
  global_alias = "sccache"
}

resource "garage_key" "sccache" {
  name = "sccache"
}

resource "garage_bucket_permission" "sccache" {
  access_key_id = garage_key.sccache.id
  bucket_id     = garage_bucket.sccache.id
  read          = true
  write         = true
  owner         = false
}

resource "vault_kv_secret_v2" "sccache_s3" {
  mount = "secret"
  name  = "shared/sccache"

  data_json = jsonencode({
    AWS_ACCESS_KEY_ID     = garage_key.sccache.id
    AWS_SECRET_ACCESS_KEY = garage_key.sccache.secret_access_key
  })
}
