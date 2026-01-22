# Troubleshooting

## comin not deploying after a force push

If someone force pushes to the repository, comin's cached repo and state can get out of sync with the remote. Symptoms include comin fetching successfully but never triggering a build.

To fix:

```bash
sudo systemctl stop comin
sudo rm -rf /var/lib/comin/repository
sudo rm /var/lib/comin/store.json
sudo systemctl start comin
```

Wait ~30 seconds, then verify:

```bash
comin status
```

You should see a new build being evaluated or deployed.
