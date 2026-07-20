{
  flake.modules.nixos.signage-01-kiosk =
    { pkgs, ... }:

    let
      kioskUrl = "https://signage.andrew.cmu.edu/frontend/63";

      errorPage = pkgs.replaceVars ./html/error.html {
        inherit kioskUrl; # Automatically replaces @kioskUrl@ in the file
      };
    in
    {
      # Minimal Wayland compositor that runs a single app fullscreen
      services.cage = {
        enable = true;
        user = "kiosk";
        program = toString (
          pkgs.writeShellScript "kiosk-browser" ''
            # Error page redirects to kioskUrl when online
            exec ${pkgs.firefox}/bin/firefox --kiosk="file://${errorPage}"
          ''
        );

        environment = {
          WLR_NO_HARDWARE_CURSORS = "1";
          XDG_SEAT = "seat0";
        };

        extraArguments = [ ];
      };

      # Dedicated unprivileged user for the kiosk session
      users.users.kiosk = {
        isNormalUser = true;
        group = "kiosk";
        extraGroups = [
          "video"
          "input"
          "tty"
          "seat"
          "render"
        ];
        home = "/home/kiosk";
        createHome = true;
      };
      users.groups.kiosk = { };

      # Don't blank the screen or suspend on lid/idle
      services.logind.settings.Login.HandleLidSwitch = "ignore";

      # Cage expects at least one input device, tell wlroots not to care
      systemd.services.cage-tty1.environment = {
        WLR_LIBINPUT_NO_DEVICES = "1";
      };

      # Auto-restart if the browser or compositor crashes
      systemd.services.cage-tty1.serviceConfig = {
        Restart = "always";
        RestartSec = "5s";
      };
    };
}
