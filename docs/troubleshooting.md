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

## ACME first-deploy race when adding a new subdomain

When a new subdomain is added to `tofu/cloudflare/records.tf` and a corresponding nginx vhost with `enableACME = true; forceSSL = true;` is added in the same comin reconcile, the first ACME issuance attempt typically fails. Let's Encrypt's resolvers query authoritative DNS faster than the new Cloudflare record propagates, so HTTP-01 validation hits NXDOMAIN.

Symptoms from outside the cluster:

- `curl https://<subdomain>` fails TLS verification with `curl: (60) SSL certificate problem` and `ssl_verify_result: 19` ("self-signed certificate in certificate chain").
- HTTP-to-HTTPS redirect still works, and `dig +short <subdomain>` returns the right IP.

The clue is `acme-order-renew-<subdomain>.service`, not `acme-<subdomain>.service`. The base `acme-<subdomain>.service` always succeeds because it only generates a `minica` self-signed placeholder so nginx can start. The real Let's Encrypt order runs in `acme-order-renew-<subdomain>.service`, and that is what fails on first deploy. Check the journal:

```bash
sudo journalctl -u acme-order-renew-<subdomain>.service -n 50 --no-pager
```

A failed run looks like:

```
urn:ietf:params:acme:error:dns :: DNS problem: NXDOMAIN looking up A for <subdomain>
```

To fix, first verify DNS is now resolvable from outside Cloudflare:

```bash
dig +short <subdomain> @1.1.1.1
```

Then manually re-run the order and reload nginx to pick up the issued cert:

```bash
sudo systemctl start acme-order-renew-<subdomain>.service
sudo systemctl reload nginx
```

Re-check the journal afterwards to confirm `Server responded with a certificate.` and `Installing new certificate`. The `acme-renew-<subdomain>.timer` would also self-heal on its own schedule, but manual retry is faster.

A definitive fix would be switching to a DNS-based ACME challenge (DNS-01 via the Cloudflare API), since that bypasses the public-DNS-propagation dependency. We have intentionally not made that change because we plan to adopt [dns-persist-01](https://letsencrypt.org/2026/02/18/dns-persist-01.html) once it ships, and do not want a one-time DNS-01 migration in between.
