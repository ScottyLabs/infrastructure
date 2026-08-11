{
  flake.modules.nixos.signage-01-reboot = {
    systemd.services.daily-reboot = {
      description = "Daily scheduled reboot";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/run/current-system/sw/bin/systemctl reboot";
      };
    };

    systemd.timers.daily-reboot = {
      description = "Reboot daily at 04:00 America/New_York";
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "*-*-* 04:00:00 America/New_York";
    };
  };
}
