#!/usr/bin/env bash
set -e

# Clone and move files
git clone git@github.com:ScottyLabs/infrastructure.git ~/infrastructure
sudo mv ~/infrastructure/* /etc/nixos/
sudo mv ~/infrastructure/.git /etc/nixos/
rmdir ~/infrastructure

# Fix permissions
sudo chgrp -R wheel /etc/nixos
sudo chmod -R g+w /etc/nixos

# Run rebuild-switch
update
