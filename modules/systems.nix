{
  config,
  inputs,
  lib,
  ...
}:
let
  nixos = config.flake.modules.nixos;
  darwin = config.flake.modules.darwin;
  users = import ../data/users.nix;

  hosts = {
    scottylabs = {
      infra-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      infra-02 = {
        domain = "scottylabs.org";
        system = "aarch64-darwin";
      };
      infra-03 = {
        domain = "scottylabs.org";
        system = "aarch64-linux";
      };
      infra-04 = {
        domain = "scottylabs.org";
        system = "aarch64-darwin";
      };
      deploy-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      signage-01 = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
      snoopy = {
        domain = "scottylabs.org";
        system = "x86_64-linux";
      };
    };
    stugov = {
      elect-01 = {
        domain = "andrew.cmu.edu";
        system = "x86_64-linux";
      };
    };
    thetartan = {
      www-04 = {
        domain = "thetartan.org";
        system = "x86_64-linux";
      };
    };
  };

  allHosts = lib.concatMapAttrs (
    org:
    lib.mapAttrs' (
      name: host:
      lib.nameValuePair "${org}-${name}" (
        host
        // {
          inherit org name;
          fqdn = "${name}.${host.domain}";
        }
      )
    )
  ) hosts;

  isDarwin = host: lib.hasSuffix "-darwin" host.system;
  nixosHosts = lib.filterAttrs (_: host: !isDarwin host) allHosts;
  darwinHosts = lib.filterAttrs (_: isDarwin) allHosts;

  specialArgs = { inherit inputs users; };

  identity = host: {
    networking.hostName = host.name;
    scottylabs.organization = host.org;
    scottylabs.domain = host.domain;
  };

  modulesFor = id: host: [
    nixos.${id}
    nixos.global
    (identity host)
  ];

  darwinModulesFor = id: host: [
    darwin.${id}
    darwin.global
    (identity host)
  ];

  deploymentFor = host: bastion: {
    targetHost = host.fqdn;
    targetUser = "deploy";
    sshOptions = lib.optionals (bastion != null) [
      "-J"
      "deploy@${bastion}"
    ];
  };

  configurationFor =
    id: host:
    if isDarwin host then
      config.flake.darwinConfigurations.${id}
    else
      config.flake.nixosConfigurations.${id};

  # nixbot deploys from infra-01, an x86_64-linux host
  effectPkgs = inputs.nixpkgs-hosts.legacyPackages.x86_64-linux;
  effects = inputs.nixbot.lib.effects { pkgs = effectPkgs; };
  hostKeys = import ../data/hosts.nix;
  knownHosts = effectPkgs.writeText "known_hosts" (
    lib.concatLines (lib.mapAttrsToList (id: host: "${host.fqdn} ${hostKeys.${id}}") allHosts)
  );

  # copies a host's system to it and switches to it
  deployEffect =
    id: host:
    let
      inherit (configurationFor id host) config;
      inherit (config.system.build) toplevel;
      deployment = deploymentFor host config.scottylabs.bastion;
      ssh = {
        destination = "${deployment.targetUser}@${deployment.targetHost}";
        sshOptions = lib.concatStringsSep " " deployment.sshOptions;
      };
      common = {
        name = "deploy-${id}";
        lock = "deploy-${id}";
        when.changed.toplevel = "${toplevel}";
        secretsMap.ssh = "deploy-ssh";
        userSetupScript = ''
          writeSSHKey ssh ~/.ssh/id_ed25519
          cp ${knownHosts} ~/.ssh/known_hosts
        '';
      };
    in
    if isDarwin host then
      effects.runNixDarwin (common // { inherit config ssh; })
    else
      effects.mkEffect (
        common
        // {
          inputs = [ effectPkgs.openssh ];
          # keeps switching if the SSH session drops or nixbot restarts
          effectScript = effects.ssh ssh ''
            set -euo pipefail
            sudo nix-env -p /nix/var/nix/profiles/system --set ${toplevel}
            sudo systemd-run --collect --no-ask-password --pipe --quiet --service-type=exec \
              --unit=nixbot-switch-to-configuration --wait \
              ${toplevel}/bin/switch-to-configuration switch
          '';
        }
      );
in
{
  flake.nixosConfigurations = lib.mapAttrs (
    id: host:
    inputs.nixpkgs-hosts.lib.nixosSystem {
      inherit (host) system;
      inherit specialArgs;
      modules = modulesFor id host;
    }
  ) nixosHosts;

  flake.darwinConfigurations = lib.mapAttrs (
    id: host:
    inputs.nix-darwin.lib.darwinSystem {
      inherit specialArgs;
      modules = darwinModulesFor id host;
    }
  ) darwinHosts;

  flake.colmenaHive = inputs.colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import inputs.nixpkgs-hosts { system = "x86_64-linux"; };
        inherit (inputs) nix-darwin;
        nodeNixpkgs = lib.mapAttrs (_: host: import inputs.nixpkgs-hosts { inherit (host) system; }) (
          lib.filterAttrs (_: host: host.system != "x86_64-linux") allHosts
        );
        inherit specialArgs;
      };
    }
    // lib.mapAttrs (id: host: {
      deployment = deploymentFor host config.flake.nixosConfigurations.${id}.config.scottylabs.bastion;
      imports = modulesFor id host;
    }) nixosHosts
    // lib.mapAttrs (id: host: {
      deployment =
        deploymentFor host config.flake.darwinConfigurations.${id}.config.scottylabs.bastion
        // {
          systemType = "darwin";
          # x86_64 deployers cannot cross-build darwin, and the mini can build itself
          buildOnTarget = true;
        };
      imports = darwinModulesFor id host;
    }) darwinHosts
  );

  # nixbot runs these after a green build of main
  flake.herculesCI = _: {
    onPush.default.outputs.effects = lib.mapAttrs deployEffect allHosts;
  };

  # puts every host's system in the checks required for merge
  flake.checks = lib.zipAttrsWith (_: lib.mergeAttrsList) (
    lib.mapAttrsToList (id: host: {
      ${host.system}.${id} = (configurationFor id host).config.system.build.toplevel;
    }) allHosts
  );
}
