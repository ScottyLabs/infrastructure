# Garage

Garage is the S3-compatible object storage used across the fleet (Loki chunks, Tempo traces, the CDN, and kennel's per-deployment storage). It is configured declaratively by the `scottylabs.garage` module in [`services/garage/server.nix`](../../services/garage/server.nix), but a fresh node needs a cluster layout assigned once at runtime before it can hold data. The layout lives in garage's own metadata under `/var/lib/garage`, not in nix, so it survives rebuilds and must be created by hand a single time per host.

## Hosts

| Host | Endpoint | Purpose |
| --- | --- | --- |
| infra-01 | `s3.scottylabs.org` | Shared buckets (observability, CDN, tofu state) |
| deploy-01 | `s3.kennel.scottylabs.org` | Kennel per-deployment object storage |

## Secrets

Each garage host has a `garage.age` env file holding `GARAGE_RPC_SECRET` (required for the node to start) and `GARAGE_ADMIN_TOKEN` (the bearer token for the admin API). On deploy-01 the same `GARAGE_ADMIN_TOKEN` also lives in `kennel.age` so kennel can authenticate to the admin API and provision buckets.

## Running the CLI

The `garage` command is a wrapper that sources the RPC secret from `garage.age`, which only root can read, so it needs `sudo`:

```bash
sudo garage status
```

## Initializing the layout

A fresh node shows `NO ROLE ASSIGNED` and cannot store data. Read the node ID from `garage status`, assign it a zone and capacity, then apply the staged change:

```bash
sudo garage status

# Zone is arbitrary for a single node. Capacity is the node's storage weight,
# so leave headroom on the data partition (on deploy-01 that is the root fs).
sudo garage layout assign -z dc1 -c 30G <node-id>

# Version 1 is the first layout on a fresh cluster.
sudo garage layout apply --version 1
```

Afterwards `garage status` shows the node with its zone, capacity, and available disk, and provisioning works.
