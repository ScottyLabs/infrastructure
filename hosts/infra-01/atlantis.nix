{ config, pkgs, ... }:

let
  repoConfig = pkgs.writeText "atlantis-repo-config.yaml" ''
    repos:
      - id: codeberg.org/ScottyLabs/governance
        apply_requirements: [mergeable, undiverged]
        import_requirements: [mergeable, undiverged]
        allowed_overrides: [apply_requirements]
        allow_custom_workflows: false
        workflow: governance

    workflows:
      governance:
        plan:
          steps:
            - run: bash ../.forgejo/scripts/install-forgejo-provider.sh
            - env:
                name: CARGO_TARGET_DIR
                command: 'echo "$HOME/cargo-target"'
            - run: cargo build --release --manifest-path=../Cargo.toml -p governance
            - env:
                name: PATH
                command: 'echo "$CARGO_TARGET_DIR/release:$PATH"'
            - env:
                name: TF_CLI_CONFIG_FILE
                command: 'echo "$HOME/.terraform.d/dev_overrides.tfrc"'
            - init
            - plan
        apply:
          steps:
            - run: bash ../.forgejo/scripts/install-forgejo-provider.sh
            - env:
                name: CARGO_TARGET_DIR
                command: 'echo "$HOME/cargo-target"'
            - run: cargo build --release --manifest-path=../Cargo.toml -p governance
            - env:
                name: PATH
                command: 'echo "$CARGO_TARGET_DIR/release:$PATH"'
            - env:
                name: TF_CLI_CONFIG_FILE
                command: 'echo "$HOME/.terraform.d/dev_overrides.tfrc"'
            - apply

    metrics:
      prometheus:
        endpoint: /metrics
  '';
in
{
  scottylabs.atlantis = {
    enable = true;
    domain = "atlantis.scottylabs.org";
    environmentFile = config.age.secrets.atlantis.path;
    extraPackages = [
      pkgs.opentofu
      pkgs.go
      pkgs.unzip
      pkgs.curl
      pkgs.cargo
      pkgs.rustc
      pkgs.gcc
    ];
    extraArgs = [
      "--gitea-base-url=https://codeberg.org"
      "--gitea-user=scottylabs-bot"
      "--repo-allowlist=codeberg.org/ScottyLabs/governance"
      "--allow-fork-prs"
      "--default-tf-distribution=opentofu"
      "--write-git-creds"
      "--allow-commands=version,plan,apply,unlock,approve_policies,cancel,import,state"
      "--silence-vcs-status-no-plans"
      "--hide-prev-plan-comments"
      "--enable-diff-markdown-format"
      "--repo-config=${repoConfig}"
    ];
  };

  age.secrets.atlantis = {
    file = ../../secrets/infra-01/atlantis.age;
    owner = "atlantis";
    mode = "0400";
  };
}
