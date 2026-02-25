{ pkgs, ... }:

let
  kioskUrl = "https://signage.andrew.cmu.edu/frontend/63";
in
{
  # Minimal Wayland compositor that runs a single app fullscreen
  services.cage = {
    enable = true;
    user = "kiosk";
    program = toString (
      pkgs.writeShellScript "kiosk-browser" ''
        # Wait for the signage server to be reachable before launching,
        # otherwise we boot into an error page
        for i in $(seq 1 30); do
          ${pkgs.curl}/bin/curl -sf --max-time 5 "${kioskUrl}" > /dev/null && break
          sleep 2
        done

        exec ${pkgs.surf}/bin/surf -F "${kioskUrl}"
      ''
    );

    extraArguments = [ "-s" ];
  };

  # Dedicated unprivileged user for the kiosk session
  users.users.kiosk = {
    isSystemUser = true;
    group = "kiosk";
  };
  users.groups.kiosk = { };

  # Don't blank the screen or suspend on lid/idle
  services.logind.lidSwitch = "ignore";

  # cage expects at least one input device, tell wlroots not to care
  systemd.services.cage-tty1.environment = {
    WLR_LIBINPUT_NO_DEVICES = "1";
  };

  # Auto-restart if the browser or compositor crashes
  systemd.services.cage-tty1.serviceConfig = {
    Restart = "always";
    RestartSec = "5s";
  };
}
