# Architecture

This repository holds the NixOS configuration for every ScottyLabs machine. `infra-01` runs the shared services (identity, git, secrets, monitoring), `deploy-01` runs the Kennel deployment platform, `signage-01` is a display kiosk, and `snoopy` is a Computer Club virtual machine. Each host's full system is built from a set of small modules that live under `modules/`.

A service is defined in one file and then listed by name on the hosts that should run it.

## Module namespace

Three inputs in `flake.nix` provide the module system:

```nix
imports = [
  inputs.flake-parts.flakeModules.modules
  (inputs.import-tree ./modules)
  inputs.terranix.flakeModule
];
```

`import-tree ./modules` imports every `.nix` file under `modules/` as a flake-parts module, merging their definitions into one flake-wide configuration.

`flake-parts.flakeModules.modules` adds the `flake.modules` option that those files write into. Modules meant for a NixOS host go under `flake.modules.nixos`. A typical file declares one named entry:

```nix
# modules/global/base.nix
{
  flake.modules.nixos.base = { config, lib, ... }: {
    # NixOS options for the base system
  };
}
```

Each file names its entry after where the file lives:

- A module under `modules/global/` takes a bare name, so `modules/global/caddy.nix` declares `caddy`
- A platform under `modules/platforms/` takes its directory name, so `modules/platforms/campus-cloud/default.nix` declares `campus-cloud`
- A module under `modules/hosts/<host>/` takes the host as a prefix, so `modules/hosts/infra-01/forgejo.nix` declares `infra-01-forgejo` and `modules/hosts/deploy-01/kennel.nix` declares `deploy-01-kennel`

Every name is unique across the tree. To find the entry a file provides, read its first few lines. Every module across the tree is available as `config.flake.modules.nixos.<name>` in a single flat namespace, regardless of how deeply its file is nested.

## Roles

A host is built from a list of module names living in `modules/roles/`.

`modules/roles/global.nix` defines the baseline shared by every host: the base system, networking, secrets, and the observability agents, together with external inputs such as home-manager, agenix, and disko.

Each host has its own role. Its imports are grouped into a platform, the common modules it shares with other hosts, and the host's own services, with each group in a labelled section and sorted within the section:

```nix
flake.modules.nixos.infra-01.imports = with config.flake.modules.nixos; [
  # Platform
  campus-cloud

  # Common
  postgresql

  # Services
  infra-01-forgejo
  # ...
];
```

## Platforms

Each host role includes a platform. Platforms live in `modules/platforms/` and hold the machine-dependent parts of a configuration, such as the boot loader, kernel modules, and disk layout via disko. `campus-cloud` covers the CMU Campus Cloud VMware guests used by `infra-01` and `deploy-01`, `mele-cyber-x1` covers the signage hardware, and `computer-club` covers `snoopy`.

## Systems and deployment

`modules/systems.nix` produces the `nixosConfigurations` used for local builds and the `colmenaHive` used for deployment. Both come from the same per-host module list, which combines the host role with the global role:

```nix
modulesFor = hostname: [ nixos.${hostname} nixos.global ];
```

`nixosConfigurations` calls `nixpkgs.lib.nixosSystem` for each host with that module list. `colmenaHive` passes the same list to Colmena and adds deployment settings, so each host is reached over SSH at `<hostname>.scottylabs.org` as the `deploy` user. Both forms receive the same `specialArgs` (`inputs` and the contents of `users.nix`), so a module behaves identically whether it is built locally or deployed.

## Imported modules and enable flags

Most modules apply their configuration as soon as a role imports them. Others expose an option under the `scottylabs.*` namespace and apply nothing until it is set. `modules/global/node-exporter.nix` declares such an option and guards its config behind it:

```nix
options.scottylabs.nodeExporter = {
  enable = lib.mkEnableOption "Prometheus node_exporter";
  port = lib.mkOption {
    type = lib.types.port;
    default = 9100;
  };
};
```

Importing the module does nothing until `scottylabs.nodeExporter.enable` is set, which `modules/global/observability-agents.nix` does for all the agents.

The `scottylabs.*` namespace is the repository's own settings surface, alongside the upstream NixOS options. It carries options such as the host IP address (`scottylabs.ipAddress`) and the observability-agent toggles (`scottylabs.nodeExporter.enable`). A module's `options.scottylabs.*` block shows what it exposes and whether another module must switch it on.

## Flake-level configuration

Some files under `modules/` contribute configuration at the flake level. These values are collected across every host before they are used.

Files under `modules/terranix/` declare entries under `flake.modules.terranix`, which are assembled into `terranixConfigurations` and import one another by name, as on the NixOS side.

A service declares its Grafana dashboards and alerts through the flake-level `scottylabs.observability` option, in the same file as the service. `modules/hosts/deploy-01/kennel.nix` defines both the Kennel module and its dashboard. Grafana runs only on `infra-01` and reads the `scottylabs.observability` values from the whole flake, so a dashboard declared beside a service on `deploy-01` is rendered by the Grafana on `infra-01`.
