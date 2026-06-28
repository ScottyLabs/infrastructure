resource "garage_bucket" "loki_chunks" {
  global_alias = "loki-chunks"
}

resource "garage_key" "loki" {
  name = "loki"
}

resource "garage_bucket_permission" "loki" {
  access_key_id = garage_key.loki.id
  bucket_id     = garage_bucket.loki_chunks.id
  read          = true
  write         = true
  owner         = false
}

resource "vault_kv_secret_v2" "loki_s3" {
  mount = "secret"
  name  = "infra/loki-s3"

  data_json = jsonencode({
    ENV = "LOKI_S3_ACCESS_KEY_ID=${garage_key.loki.id}\nLOKI_S3_SECRET_ACCESS_KEY=${garage_key.loki.secret_access_key}\n"
  })
}

resource "garage_bucket" "tempo_traces" {
  global_alias = "tempo-traces"
}

resource "garage_key" "tempo" {
  name = "tempo"
}

resource "garage_bucket_permission" "tempo" {
  access_key_id = garage_key.tempo.id
  bucket_id     = garage_bucket.tempo_traces.id
  read          = true
  write         = true
  owner         = false
}

resource "vault_kv_secret_v2" "tempo_s3" {
  mount = "secret"
  name  = "infra/tempo-s3"

  data_json = jsonencode({
    ENV = "TEMPO_S3_ACCESS_KEY=${garage_key.tempo.id}\nTEMPO_S3_SECRET_KEY=${garage_key.tempo.secret_access_key}\n"
  })
}
