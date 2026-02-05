# Dokploy Bunny WAF on Hetzner Server Guide

## Why Bunny and Not Cloudflare?

Cloudflare doesn't provide clear pricing per million requests and bandwidth. They're waiting to [trap you](https://www.reddit.com/r/CloudFlare/comments/1oa4lut/does_cloudflare_really_not_charge_for/nk73eka/) once you're locked into their proprietary tools. Give this a watch: [https://youtu.be/8zj7ei5Egk8](https://youtu.be/8zj7ei5Egk8)

This is a great way to offload our security to a provider that's fairly cheap and worry about developing, not hosting. Since I'm using the free tier, I still have Crowdsec running on my server. Crowdsec seems to catch a lot passing through the Bunny WAF, but the detection on the free tier isn't as good as features in premium/business plans.

## What You Need

1. Bunny.net account (you get free trial, no card required)
2. Hetzner VPS server
3. A domain

> **Note**: This guide involves setting firewall rules at the Hetzner network firewall level before traffic reaches the server. If your server provider has a network firewall, you may be able to add this many IPs, but we're adding lots of rules and scripts will need to be modified.

## Part 1: Bunny DNS Configuration

You can keep your current DNS records, but Bunny is a good free DNS provider.

I assume you've already set up your DNS zone in [https://dash.bunny.net/dns/zones](https://dash.bunny.net/dns/zones)

I made a wildcard record for ease. Bunny has said they recently started issuing SSL certs for those.

### Enable CDN Acceleration

Make sure to click 'CDN acceleration' for your DNS records.  
[https://support.bunny.net/hc/en-us/articles/21123161178396-What-is-CDN-Acceleration-and-how-to-enable-it](https://support.bunny.net/hc/en-us/articles/21123161178396-What-is-CDN-Acceleration-and-how-to-enable-it)

**If you have your own DNS provider**, you'll need to create a CNAME record and point to the pull zone you create. CDN acceleration does this for us automatically when we use Bunny DNS.

![enter image description here](https://wsrv.nl/?url=https://c.l3n.co/FxCKb1.png)

## Part 2: Pull Zone Configuration

Bunny has combined the services, so you need a pull zone that has CDN and the WAF Shield in one place.

### Configure Caching Settings

Navigate to: **Sidebar → CDN → Pull Zone (the one with your domain record) → Caching → General**

Here I set **Cache Expiration Time** to "override do not cache" so all traffic will hit our server. For now, we're focusing only on the WAF.

![enter image description here](https://wsrv.nl/?url=https://c.l3n.co/FxCSdm.png)

### Important for Wildcard Records

Since I'm using a wildcard (*) record, if I had CDN on, it would cache content from beszel.mysite.com and I would see it on ghost.mysite.com 😲

To prevent cache bleeding between subdomains:  
**Caching → General → Vary Cache → Check 'Request Hostname'**

This ensures different domains get different caches.

## Part 3: Shield (WAF) Configuration

In Shield, you'll need to turn it on. The free plan is fine.

Look around at the rules. **The most important part** is to add an access list with your IP and select 'Bypass' in the dropdown, so you're never blocked from accessing your hosted services.

![enter image description here](https://b.l3n.co/FxCeMi.png)

## Part 4: Hetzner Firewall Setup

SSH into your server. You need to only allow access to the server with Bunny IPs, since we want all traffic to flow through the WAF.

> **Note**: Bunny provides these links with the list of updated IPs:  
> [https://support.bunny.net/hc/en-us/articles/115003578911-How-to-detect-when-BunnyCDN-PoP-servers-are-accessing-your-backend](https://support.bunny.net/hc/en-us/articles/115003578911-How-to-detect-when-BunnyCDN-PoP-servers-are-accessing-your-backend)

Check this guide someone made. It's basically fetching Cloudflare's IP list and calling Hetzner's API, which adds these IPs to a firewall rule, and that firewall is applied to the server. This is what will happen, but just with Bunny:  
[https://community.hetzner.com/tutorials/cloudflare-website-protect#step-4---setting-up-hetzner-cloud-firewall](https://community.hetzner.com/tutorials/cloudflare-website-protect#step-4---setting-up-hetzner-cloud-firewall)

### Generate Hetzner API Token

Go to the Hetzner console:

1. On the sidebar, scroll down to **Security → API Tokens**
2. Generate a token and save it in your password manager

### Create Firewalls

Go to **Firewalls → Create Firewall**

Create three firewalls: `bunnycdn1`, `bunnycdn2`, `bunnycdn3`

Add an IP from here as a placeholder for ports 80/443:  
[https://bunnycdn.com/api/system/edgeserverlist/plain](https://bunnycdn.com/api/system/edgeserverlist/plain)

> **Why three firewalls?** Hetzner sets firewall rules in an API call but limits it to 500 IPs per request. Even though the firewall holds more, we can't append to it—each request overrides all the rules. This means we have to add the 940 Bunny IPs to multiple firewalls.

> ⚠️ **Warning**: Make sure your main firewall doesn't have 'any IP' for ports 80/443. I would only leave those open and let Traefik proxy route to them. You can also leave port 22 for your IP only, but Tailscale works without it.

Apply these three firewalls to your Hetzner server running Dokploy.

### Get Your Firewall IDs

Make this API call in terminal to get the firewall IDs:

```bash
export HETZNER_API_TOKEN='key_here'
curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
  https://api.hetzner.cloud/v1/firewalls | jq '.firewalls[] | {id: .id, name: .name}'
```

Write down the firewall IDs.

## Part 5: Creating Automation Scripts

Create a folder for the cron scripts:

```bash
cd /etc/dokploy
mkdir cron-scripts
cd cron-scripts
```

### Create the IP List Fetcher Script

```bash
nano get-bunnycdn-2iplist.sh
chmod +x get-bunnycdn-2iplist.sh
```

Paste the code from here:  
[https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/get-bunnycdn-2iplist.sh](https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/get-bunnycdn-2iplist.sh)

### Create the Firewall Update Script

```bash
nano hetzner-firewall-update.sh
chmod +x hetzner-firewall-update.sh
```

Paste the code from here, **but you'll need to edit it** with your Hetzner API key and those three firewall IDs so it can call them with the IP list:  
[https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/hetzner-firewall-update.sh](https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/hetzner-firewall-update.sh)

### Configure IP List File Paths

**Make note of the directory where it's saving the IP list files:**

```bash
IPV4_FILE="/var/lib/crowdsec/data/bunnycdn_ipv4.txt"
IPV6_FILE="/var/lib/crowdsec/data/bunnycdn_ipv6.txt"
```

Since I'm using Crowdsec, it will create a whitelist from the files there and I add them to an allowlist (that's for a separate Crowdsec tutorial).

> **If you're not using Crowdsec**: Simply change the directory of the IP file in both scripts to:
> ```bash
> /etc/dokploy/cron-scripts/bunnycdn_ipv4.txt
> /etc/dokploy/cron-scripts/bunnycdn_ipv6.txt
> ```

### Optional: Crowdsec Integration

If you are using Crowdsec, create an allowlist called 'bunnycdn' and uncomment these lines in the script:

```bash
#cscli allowlists add bunnycdn $(cat "$IPV4_FILE" "$IPV6_FILE" | tr '\n' ' ') -d "Bunny CDN Edge Servers"
#cscli allowlists list
```

## Part 6: Setting Up Cron Jobs

Create cron jobs to run these scripts daily:

```bash
crontab -e
```

Scroll down and add these scripts (runs daily at 2 PM and 3 PM):

```bash
0 14 * * * /etc/dokploy/cron-scripts/get-bunnycdn-2iplist.sh >> /var/log/bunnycdn-allowlist.log 2>&1
0 15 * * * /etc/dokploy/cron-scripts/hetzner-firewall-update.sh >> /var/log/bunnycdn-allowlist.log 2>&1
```

## Part 7: Traefik Configuration

In Traefik we have two options (or more I don't know about) to get the user's real IP behind a proxy: we can add an array of trusted IPs or simply turn on insecure mode.  
[https://doc.traefik.io/traefik/v1.4/configuration/entrypoints/#proxyprotocol](https://doc.traefik.io/traefik/v1.4/configuration/entrypoints/#proxyprotocol)

> **The challenge**: Bunny has 940 IPs 🙃 and Cloudflare has less than 20. We could have a script do it, but something could go wrong messing with our main static Traefik config file. So I opt for insecure mode. We also need logs turned on.

### Enable Traefik Logging

In Dokploy panel: **Traefik File System → traefik.yml**

Insert `log` section after `global`:

```yaml
global:
  sendAnonymousUsage: false
log:
  level: info
accessLog:
  format: common
  fields:
    headers:
      defaultMode: keep
```

You should be able to see Traefik logs with this command after restarting the Traefik container:

```bash
docker logs --tail 20 dokploy-traefik
```

### Configure Forwarded Headers

In the same file, add or modify the `entryPoints` section:

```yaml
entryPoints:
  web:
    address: :80
    forwardedHeaders:
      insecure: true
  websecure:
    address: :443
    http3:
      advertisedPort: 443
    http:
      tls:
        certResolver: letsencrypt
    forwardedHeaders:
      insecure: true
```

> **About `trustedIPs`**: This is where the `trustedIPs = ["127.0.0.1/32", "192.168.1.7"]` array would go if we were using it, but for now use insecure mode.

> ⚠️ **Security Warning**: You must remember this setting! If you stop using Bunny WAF or any firewall in front, then any malicious user can forge `X-Real-IP` or `X-Forwarded-*` headers.  
>
> According to Traefik documentation: "Only IPs in `trustedIPs` will be authorized to trust the client forwarded headers."

However, since we completely blocked access to our server except through Bunny, I know all requests come from Bunny, and Bunny WAF will pass along the real user's IP. If I don't turn on this insecure mode or add trusted IPs, then Traefik logs will only show Bunny's IPs. And my Crowdsec parser will only see Bunny IPs in the Traefik logs, so it won't ever ban any users for malicious requests since I added all 940 Bunny IPs to the Crowdsec allowlist.

## Alternative Approaches

### Using iptables Instead of Hetzner Firewall

I haven't tried using iptables yet, but Hetzner could stop this API with lower limits at any time, so just monitor your logs to know. I hope someone makes a guide to add these to iptables. Many people might be on a VPS provider that doesn't have a network-level firewall, so this is needed.

### Using Traefik Middleware for IP Filtering

We could have forgone using the firewall altogether and allowed any IP to ports 80/443, then used Traefik for blocking:  
[https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/)

However, Traefik blocks far less per second than the firewall can. When people say their service is being attacked, it usually means they didn't think about any security beforehand. A Traefik blocker wouldn't have saved them, but a firewall could, since Bunny can just turn on expert-level bot fight mode.

## Crowdsec vs Bunny WAF

I'm no expert on setting up a firewall. It comes down to: do you want to worry about your own security or offload that to an external Web Application Firewall?

At first I didn't know Crowdsec is meant to be your only firewall, and you might need some Traefik plugins like the OWASP Top 10 rule protector to match the abilities of some WAFs with lots of features. But Crowdsec wasn't meant to be behind this proxy in the first place, meaning we wouldn't have to turn on insecure mode or add trusted IPs to Traefik forwardedHeaders. So I made it a lot more complex when I basically added two firewalls, and Bunny made it more complex by not having <20 IPs like Cloudflare, but having 940.

Most of us are here self-hosting a VPS since we don't want to become a story here: [https://serverlesshorrors.com](https://serverlesshorrors.com)

To me, the WAF is cheap enough since you're paying per million requests. The real money is paying 10x more for CPU and bandwidth. The cheapest PaaS bandwidth is $50 per TB, other than Digital Ocean at $20.  
[https://getdeploying.com/reference/data-egress](https://getdeploying.com/reference/data-egress)

Crowdsec is easy enough to set up but another thing to worry about, plus all the other things we would need to replicate Bunny's WAF that is less than $1 per million requests.

<!--stackedit_data:
eyJoaXN0b3J5IjpbLTE0MzMxNzA4MDgsLTE1OTQ2OTA1MTZdfQ
==
-->