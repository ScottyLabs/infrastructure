variable "garage_admin_token" {
  type      = string
  sensitive = true
}

variable "garage_node_id" {
  type        = string
  description = "Node ID from `garage status` after first boot"
}
