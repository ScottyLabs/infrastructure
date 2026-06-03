# Helpers for NixOS hosts that run Docker workflow/job containers behind a strict firewall.
#
# Job containers use ephemeral WORKFLOW-* bridge networks (see defaultAddressPools).
# The host firewall must allow their subnets to reach host listeners (act-runner cache
# proxy, etc.). Job containers reach the host via host.docker.internal (host-gateway).
{ lib }:

let
  defaultWorkflowClientSubnets = [
    "10.89.0.0/16"
    "172.17.0.0/16"
    "172.16.0.0/12"
  ];

  defaultAddressPools = [
    {
      base = "10.89.0.0/16";
      size = 24;
    }
  ];
in
{
  inherit defaultWorkflowClientSubnets defaultAddressPools;

  # Accept inbound TCP to host ports from Docker workflow bridge clients.
  mkAllowTcpFromWorkflowClients =
    {
      ports,
      subnets ? defaultWorkflowClientSubnets,
    }:
    lib.mkAfter (
      lib.concatMapStringsSep "\n" (port:
        "iptables -I nixos-fw -i docker0 -p tcp --dport ${toString port} -j nixos-fw-accept"
        + "\n"
        + lib.concatMapStringsSep "\n" (subnet:
          "iptables -I nixos-fw -p tcp --dport ${toString port} -s ${subnet} -j nixos-fw-accept"
        ) subnets
      ) ports
    );

  mkDockerDaemonConfig =
    {
      pools ? defaultAddressPools,
    }:
    {
      enable = true;
      daemon.settings.default-address-pools = pools;
    };
}
