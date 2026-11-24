{
  scottylabs = {
    infra-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaOgbg8hOVqI4zmEHODl1NJpAeImw/7z6jPnVSoXywt root@infra-01";
      cache = "infra-01.scottylabs.org-1:U3gvVsTwubsVtsd2T1Ph5F+M1PaOz/z74X6Ih4SbrFI=";
    };
    mac-01 = {
      domain = "scottylabs.org";
      system = "aarch64-darwin";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXn1GdJYesQxj4Bq+vz+ZITAuWIeOZZkMHsjMbY1IeW root@infra-02";
      cache = "mac-01.scottylabs.org-1:l7EYPN6Peb60pozMrlHUINyTz7mAqtRMtTZfhnQVKJ8=";
    };
    mac-02 = {
      domain = "scottylabs.org";
      system = "aarch64-darwin";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIF6tigaBZVaTUgLUHUfHuw6Y44yT/FSEVzHccjT6IZA root@infra-04";
      cache = "mac-02.scottylabs.org-1:k35vESqkaneooJdGQ+Ne0f3/mDZtBr/nxBIuP40594k=";
    };
    ci-01 = {
      domain = "scottylabs.org";
      system = "aarch64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOaQliYDA6EKA9xrJiWqk+unJ4Tm80dbu674zXpFVIxL root@infra-03";
      cache = "ci-01.scottylabs.org-1:0DT6xnQ3qbzrcFypiQ6COWIAplEvlUnGz+0A/6IMEwk=";
    };
    deploy-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOm8p8uaXbhMbJGhkYJZWBzqYB25D9AVCUc5ACcMwU3c root@deploy-01";
      cache = "deploy-01.scottylabs.org-1:TtFRYjsx76lUXkCDvobNkTFZGOeLZFKTzdKX9oyiCcY=";
    };
    signage-01 = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHY/TsQztMS7l5ozBhLu05O+ze/DasZ3+grn5tvapoGX root@signage-01";
      cache = "signage-01.scottylabs.org-1:DgFjQ/nJRMj5Bp0Q6YgIaj81cZ3eIPZ6Us/NNaCIcJs=";
    };
    snoopy = {
      domain = "scottylabs.org";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJxoj1W19busC7uwr4iNXlJHP3uMS7Wg3M+Kv6j0TPa root@snoopy";
      cache = "snoopy.scottylabs.org-1:TXprqCrvF2Cr5EK6flZ4+Ttp9fGLsVAjGb0WikyNd88=";
    };
  };
  stugov = {
    elect-01 = {
      domain = "andrew.cmu.edu";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJgXDXDmf8KBfvmSLafIfoKvt/Wz1yBnw1X1OozeBKQB root@elect-01";
      cache = "elect-01.andrew.cmu.edu-1:QaJrfKR7i6GuUWzBR7v/PE/vUceh8iX5r/eqmJYqwh4=";
    };
  };
  thetartan = {
    www-04 = {
      domain = "thetartan.org";
      system = "x86_64-linux";
      ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMsm2+qTU3NpEPaS7KmkJLhqyFrXg52UYuObsPbbqtc6 root@tartan-01";
      cache = "www-04.thetartan.org-1:xuLa/YjK/B0B4Mji8UNzzs2CHZZlwKS4hOb+qU+cb+c=";
    };
  };
}
