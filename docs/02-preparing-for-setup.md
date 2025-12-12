# Preparing for Setup

CampusCloud VMs are managed through vSphere, which is accessed through [Citrix Workspace](https://apps.cmu.edu/). From here, you can select `Campus Cloud vSphere Client`. Install Citrix Viewer when prompted.

<img src="./assets/citrix-workspace.png" alt="Citrix workspace" height="300" />

This will take you to VMware® vSphere, where you can log in with your CMU credentials. The username is just your Andrew ID (not the email). From here, navigate to the `VM -> Actions -> Edit Settings`:

<img src="./assets/vm-edit-settings.png" alt="Edit VM settings" height="300" />

Here, you can switch the boot mode from the default (Legacy/BIOS) to UEFI via `VM Options -> Boot Options -> Firmware`:

<img src="./assets/vm-boot-mode.png" alt="VM boot mode" height="300" />

In this repository, add `hostname` to the `hosts` array in [flake.nix](../flake.nix). If not already present, create an entry for yourself in [users.nix](../users.nix)]. Then, create `hosts/hostname/configuration.nix` following the pattern of the other hosts in [hosts/](../hosts/):

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../platforms/campus-cloud
  ];

  system.stateVersion = "25.11"; # use the version of NixOS you are installing
}
```
