resource "garage_bucket" "loki_chunks" {
  name = "loki-chunks"
}

resource "garage_access_key" "loki" {
  name          = "loki"
  never_expires = true
}

resource "garage_permission" "loki" {
  access_key_id = garage_access_key.loki.access_key_id
  bucket_id     = garage_bucket.loki_chunks.id
  read          = true
  write         = true
  owner         = false
}

resource "vault_kv_secret_v2" "loki_s3" {
  mount = "secret"
  name  = "infra/loki-s3"

  data_json = jsonencode({
    ENV = "LOKI_S3_ACCESS_KEY_ID=${garage_access_key.loki.access_key_id}\nLOKI_S3_SECRET_ACCESS_KEY=${garage_access_key.loki.secret_access_key}\n"
  })
}

resource "garage_bucket" "tempo_traces" {
  name = "tempo-traces"
}

resource "garage_access_key" "tempo" {
  name          = "tempo"
  never_expires = true
}

resource "garage_permission" "tempo" {
  access_key_id = garage_access_key.tempo.access_key_id
  bucket_id     = garage_bucket.tempo_traces.id
  read          = true
  write         = true
  owner         = false
}

resource "vault_kv_secret_v2" "tempo_s3" {
  mount = "secret"
  name  = "infra/tempo-s3"

  data_json = jsonencode({
    ENV = "TEMPO_S3_ACCESS_KEY=${garage_access_key.tempo.access_key_id}\nTEMPO_S3_SECRET_KEY=${garage_access_key.tempo.secret_access_key}\n"
  })
}
