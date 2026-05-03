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
# enabled by aws_s3_bucket_website_configuration below, which calls the
# S3-standard PutBucketWebsite. Garage serves anonymous traffic for
# website-flagged buckets through its s3_web listener (configured in
# common/garage.nix), not through the s3_api endpoint at s3.scottylabs.org.
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

resource "aws_s3_bucket_website_configuration" "scottylabs_assets" {
  bucket = garage_bucket.scottylabs_assets.name

  index_document {
    suffix = "index.html"
  }

  depends_on = [garage_permission.scottylabs_assets_writer]
}

output "scottylabs_assets_writer_access_key_id" {
  value     = garage_access_key.scottylabs_assets_writer.access_key_id
  sensitive = true
}

output "scottylabs_assets_writer_secret_access_key" {
  value     = garage_access_key.scottylabs_assets_writer.secret_access_key
  sensitive = true
}
