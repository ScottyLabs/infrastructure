# Helpers for NixOS hosts that run Docker workflow/job containers behind a strict firewall.
#
# Job containers use ephemeral WORKFLOW-* bridge networks (see defaultAddressPools).
# They are not on docker0, so networking.firewall.trustedInterfaces = [ "docker0" ]
# alone does not allow them to reach host listeners (act-runner cache proxy, etc.).
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
      lib.concatMapStringsSep "\n" (subnet:
        lib.concatMapStringsSep "\n" (port:
          "iptables -I nixos-fw -p tcp --dport ${toString port} -s ${subnet} -j nixos-fw-accept"
        ) ports
      ) subnets
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
