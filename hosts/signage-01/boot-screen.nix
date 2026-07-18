{ lib, pkgs, ... }:

{
  # Fix grub res
  boot.loader.grub.gfxmodeEfi = "3840x2160";
  boot.loader.grub.gfxpayloadEfi = "keep";

  # No more grub menu
  boot.loader.timeout = lib.mkForce 0;
  boot.loader.grub.timeoutStyle = "hidden";
  boot.loader.grub.splashImage = null;

  # Quiet boot
  boot.consoleLogLevel = 0;
  boot.kernelParams = [
    "bgrt_disable"
    "quiet"
    "udev.log_level=0"
    "vt.global_cursor_default=0"
  ];

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
}
