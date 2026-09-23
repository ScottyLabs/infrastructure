{
  flake.modules.nixos.signage-01-boot-screen =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    {
      # Inform kernel of the resolution
      boot.loader.grub.gfxmodeEfi = "3840x2160";
      boot.loader.grub.gfxpayloadEfi = "keep";

      # Disable default grub artwork
      boot.loader.timeout = lib.mkForce 0;
      boot.loader.grub.timeoutStyle = "hidden";
      boot.loader.grub.splashImage = null;

      # udev-trigger returns before i915 binds, so splash can race KMS
      boot.initrd.systemd.services.plymouth-start.after = [ "systemd-modules-load.service" ];

      # Hold the splash on screen until cage launches
      systemd.services.plymouth-quit.serviceConfig.ExecStart = [
        ""
        "${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
      ];

      # Kill splash after cage init
      systemd.services.plymouth-quit.wantedBy = lib.mkForce [ ];
      systemd.services.plymouth-quit-wait.wantedBy = lib.mkForce [ ];

      # Opem plymouth shutdown window right after cage goes down
      systemd.services.plymouth-reboot.after = [ "cage-tty1.service" ];
      systemd.services.plymouth-poweroff.after = [ "cage-tty1.service" ];
      systemd.services.plymouth-halt.after = [ "cage-tty1.service" ];

      # These tty resets would wipe the retained splash
      systemd.services.cage-tty1.serviceConfig = {
        TTYReset = lib.mkForce "no";
        TTYVTDisallocate = lib.mkForce "no";
        TTYVHangup = lib.mkForce "no";
      };

      # Bypass getty login prompt
      systemd.targets.getty.wants = lib.mkForce [ ];

      # Quiet boot
      boot.consoleLogLevel = 0;
      boot.kernelParams = [
        "bgrt_disable"
        "quiet"
        "udev.log_level=0"
        "rd.udev.log_level=0"
        "systemd.show_status=false"
        "rd.systemd.show_status=false"
        "vt.global_cursor_default=0"
        # srvos puts a serial console on the cmdline
        "plymouth.ignore-serial-consoles"
        "initcall_blacklist=simpledrm_platform_driver_init"
        "i915.enable_fbc=0"
      ];

      # Remove extraneous consoles
      srvos.boot.consoles = [ "ttyS0,115200" ];

      # Splash screen
      boot.plymouth = {
        enable = true;
        theme = "slabstheme";
        themePackages = [
          (pkgs.stdenv.mkDerivation {
            name = "slabstheme";

            src = ./.;

            dontUnpack = true;

            installPhase = ''
              mkdir -p $out/share/plymouth/themes/slabstheme

              # Copy your image into the theme directory
              cp $src/scottylabs.png $out/share/plymouth/themes/slabstheme/splash.png

              # Generate the .plymouth configuration file
              cat <<EOF > $out/share/plymouth/themes/slabstheme/slabstheme.plymouth
              [Plymouth Theme]
              Name=Slabs Theme
              Description=A custom static image theme
              ModuleName=script

              [script]
              ImageDir=$out/share/plymouth/themes/slabstheme
              ScriptFile=$out/share/plymouth/themes/slabstheme/slabstheme.script
              EOF

              # Copy the script file to center the image on a black background
              cp $src/slabs.plymouth $out/share/plymouth/themes/slabstheme/slabstheme.script
            '';
          })
        ];
      };
    };
}
