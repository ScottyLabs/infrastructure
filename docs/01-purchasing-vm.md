# Purchasing a VM

We buy CampusCloud VMs from CMU. To request a new VM:

1. Visit [this form](https://cmu.service-now.com/go/CampusCloudNewServer).
2. Fill out the form with the following details:

    * Department: `ScottyLabs`
    * Proposed Server Name: `hostname.scottylabs.org`
    * Intended OS: `Other Linux (Specify Below)`
    * Version: `NixOS 25.11` (or the current latest stable version)
    * Public subnet
    * Default configuration: 4 CPUs, 16 GB RAM, 40 GB SSD
    * Oracle String: Available under Finance collection in Vaultwarden

3. Submit the form and wait the VM to be provisioned by Computing Services.

They will provide a MAC address for the VM, which you can enter on [NetReg](https://netreg.net.cmu.edu/bin/netreg.pl?op=mach_reg_s1&bmvm=1&building=-1&subnet=1326&subnetNEXT=Continue).

Before continuing, you must have permissions on NetReg. If you do not have permission, ask the current Head of Developer Operations. This link should have the subnet pre-selected for CampusCloud VMs, but if it is not, go to `Register a New Machine` and select the subnet `A100 Datacenter - Colocation Public`. Fill out the form with the following details:

* Hostname: `hostname` (select `scottylabs.org` in the dropdown)
* Hardware Address: The MAC address provided by Computing Services
* Affiliation: `ScottyLabs`

You must then wait for the public IP to be assigned to the VM, which can take up to 30 minutes. Once you have the IP, create an `A` record on `hostname.scottylabs.org` pointing to this IP.

For Cloudflare, disable Cloudflare proxy, add `netreg.net.cmu.edu` in the comment.

<img src="./assets/cloudflare.png" alt="A record created in Cloudflare" height="300" />
