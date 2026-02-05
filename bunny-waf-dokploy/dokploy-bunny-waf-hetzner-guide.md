# Dokploy bunny waf on hetzner server Guide
Why bunny and not cloudfare? because cloudfare does not give clear $ pricing per x million request and bandwidth. They are waiting to [trap you](https://www.reddit.com/r/CloudFlare/comments/1oa4lut/does_cloudflare_really_not_charge_for/nk73eka/) once you are locked into their proprietary tools. Give this a watch: https://youtu.be/8zj7ei5Egk8

This is a great way to offload our security to a provider thats fairly cheap and worry about developing not hosting. Since I'm using the free tier, I still have crowdsec running on my server. Crowdsec seems to catch a lot passing through the bunny waf, but the detection on free tier isnt as good as features in premium/business.
What you need

 1. bunny.net account (you get free trial, no card required)
 2. hetzner vps server*emphasized text*
 3. a domain

This guide involves setting firewall rules at the hetzner network firewall level before it reaches the server. If your server provider has a network firewall, you may be able to add this many ips but we are adding lots of rules, and scripts will have to be modified.

You can keep your current dns records. but bunny is a good free dns provider.

I assume you already set up your dns zone in https://dash.bunny.net/dns/zones

I made a wildcard record for ease, bunny has said they recently started ssl certs for those.

Make sure to click 'cdn acceleration' 
https://support.bunny.net/hc/en-us/articles/21123161178396-What-is-CDN-Acceleration-and-how-to-enable-it
**If you have your own dns provider, you will have to create a CNAME record and point to the pull zone your create** cdn acceleration does this for us when we use bunny dns.
![enter image description here](https://c.l3n.co/FxCKb1.png)

Bunny has combined the services, so you need a pull zone, that has cdn, and the waf shield in 1 place.
In the sidebar:  CDN -> pullzone (one with my domain record) -> caching -> general
here i set **cache expiration time** to "override do not cache" all traffic will hit our server, so only focus on waf for now.
![enter image description here](https://c.l3n.co/FxCSdm.png)
Also, since I'm using a wildcard * record. if i had CDN on, it would cache things from beszel.mysite.com and i would see it on ghost.mysite.com 😲 ,
to prevent that,  caching -> general -> vary cache -> check 'request hostname'  so different domains get different caches.
_____
In shield, you will need to turn it on, free plan is fine.
look around at the rules. The most important part is add an access list with your ip and select 'bypass' in the dropdown. so you are never blocked accessing your hosted services.

![enter image description here](https://b.l3n.co/FxCeMi.png)
____
ssh into your server, you need to only allow access to the server with bunny ips, since we want all traffic to flow through the WAF.

note bunny has these links with the list of updated ips https://support.bunny.net/hc/en-us/articles/115003578911-How-to-detect-when-BunnyCDN-PoP-servers-are-accessing-your-backend

Check this guide someone made, its basically fetching cloudfares ip list, and calling hetzners api which adds these ips to a firewall rule, and that firewall is applied to the server. This is what will happen, but just with bunny. https://community.hetzner.com/tutorials/cloudflare-website-protect#step-4---setting-up-hetzner-cloud-firewall
___ 
Go to the Hetzner console
on the side, scroll down to security -> API tokens -> generate a token and save it in password manager.
go to firewalls -> create firewalls -> 
create 3 firewalls, bunnycdn1, bunnycdn2, bunnycdn3
add an ip from here as placeholder for port 80/443 https://bunnycdn.com/api/system/edgeserverlist/plain

Hetzner sets the firewall rules in an api call but it limits to  500 ips per request, even though the firewall holds more, we can't append to it, so each request overrides all the rules.. which means we have to add the 9400 bunny ips to multiple firewalls. 

**make sure your main firewall doesnt have 'any ip' for port 80/443** . I would only leave those open and let traefik proxy route to them. You can also leave port 22 for your ip only, but tailscale works without it
apply these to your hetzner server running dokploy
___
create a folder /etc/dokploy/cron-scripts
first cd into /etc/dokploy ..

    mkdir cron-scripts
    nano get-bunnycdn-2iplist.sh
    #to make it executable
    chmod +x get-bunnycdn-2iplist.sh 
    
    nano hetzner-firewall-update.sh
    chmod +x hetzner-firewall-update.sh
    
now 'ls' should show these files. before adding the scripts you need your api key from earlier, and your firewall id from hetzner,
so make this api call in terminal to get the firewall Id's

     export HETZNER_API_TOKEN='key_here'
        curl -H "Authorization: Bearer $HETZNER_API_TOKEN" \
      https://api.hetzner.cloud/v1/firewalls | jq '.firewalls[] | {id: .id, name: .name}'

write down the firewall id's
___
now edit the get-bunnycdn-2iplist sh file and paste code from here https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/get-bunnycdn-2iplist.sh

edit hetzner-firewall-update sh file and paste code from here, but you will need to edit it with your hetzner api key and those 3 firewalls ids so it can call them with the ip list!
https://github.com/MooseCapital/md-post/blob/main/bunny-waf-dokploy-scripts/hetzner-firewall-update.sh

**make note of the directory its saving the ip list files to**

    IPV4_FILE="/var/lib/crowdsec/data/bunnycdn_ipv4.txt"
    IPV6_FILE="/var/lib/crowdsec/data/bunnycdn_ipv6.txt"

since I'm using crowdsec, it will create a whitelist from the files there and I add them to an allowlist, that is for a separate crowdsec tutorial. If your not using crowdsec, then simply change the directory of the ip file in both scripts to

    /etc/dokploy/cron-scripts/bunnycdn_ipv4.txt
    /etc/dokploy/cron-scripts/bunnycdn_ipv6.txt

if you are using crowdsec, then create an allowlist called 'bunnycdn' and uncomment these lines:

    #cscli allowlists add bunnycdn $(cat "$IPV4_FILE" "$IPV6_FILE" | tr '\n' ' ') -d "Bunny CDN Edge Servers"
    #cscli allowlists list

___
create a cronjob to run these
type crontab -e
scroll down and add these scripts:
0 14 * * * /etc/dokploy/cron-scripts/get-bunnycdn-2iplist.sh >> /var/log/bunnycdn-allowlist.log 2>&1
0 15 * * * /etc/dokploy/cron-scripts/hetzner-firewall-update.sh  >> /var/log/bunnycdn-allowlist.log 2>&1

___
In traefik we have 2 options, or more I don't know about.To get the users real ip behind a proxy. we can add an array of trusted Ip's or simple turn on insecure mode https://doc.traefik.io/traefik/v1.4/configuration/entrypoints/#proxyprotocol
Note bunny has 940 Ips.. 🙃 and cloudfare has less than 20. We could have a script do it, but something could go wrong messing with our main static traefik config file. So I opt for insecure mode. we also need logs turned on.

In dokploy panel -> traefik file system -> traefik.yml
insert log after global

    global:
      sendAnonymousUsage: false
    log:
      level: info
    accessLog:
      format: common
      fields:
        headers:
          defaultMode: keep
you should be able to see traefik logs with this command after restarting traefik container.
docker logs --tail 20 dokploy-traefik

In the same file add

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
This is where the trustedIPs = ["127.0.0.1/32", "192.168.1.7"] array would go if we were using, but for now use insecure. You must remember this since if you stop using bunny waf or any firewall in front, then any malicious users can forge 
x-real-ip or this from traefik "Only IPs in `trustedIPs` will be authorized to trust the client forwarded headers (`X-Forwarded-*`)."  

However, since we completely blocked access to our server except bunny, then I know all request come from bunny, and bunny waf will pass along the real users ip. If I don't turn on this insecure mode or add trusted Ip's then traefik logs will only show bunny's ips. and my crowdsec parser will only see bunny ip's in the traefik logs so it won't ever ban any users for malicious request since I added all 940 bunny ips to crowdsec allowlist.

I haven't tried using iptables yet, but hetzner could stop this api with lower limits at any time so just monitor your logs to know. I hope someone makes a guide to add these to iptables. Many people might be on a vps provider that doesn't have a network level firewall, so this is needed.

we could have forgone using firewall altogether, and allow any ip to port 80/443 and use traefik for blocking, https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/ipallowlist/
However traefik blocks far less per second than the firewall can. When people say their service is being attacked, it usually means they didn't think about any security beforehand. And a traefik blocker wouldn't have saved them, but a firewall could, since bunny can just turn on expert level bot fight mode.

## Crowdsec vs Bunny waf
I'm no expert on setting up a firewall, It comes down to do you want to worry about your own security or offload that to an external  Web access firewall. At first I didn't know  crowdsec is meant to be your only firewall and you might need some traefik plugins like owasp 10 rule protector to match the abilities of some wafs with lots of features. But crowdsec wasn't meant to be behind this proxy in the first place, meaning we wouldn't have to turn on insecure mode or add trusted ip's to traefik forwardedHeaders. So I made it a lot more complex when I basically added 2 firewalls, and bunny made it more complex by not having < 20 ips like cloudfare, but having 940.

Most of us are here self hosting a vps since we don't want to become a story here https://serverlesshorrors.com 
To me, the waf is cheap enough, since your paying per million request. The real money is paying 10x more for cpu and bandwidth, the cheapest paas bandwidth is $50 per TB, other than digital ocean at $20. https://getdeploying.com/reference/data-egress

Crowdsec is easy enough to setup but another thing to worry about, plus all the other things we would need to replicate bunny's waf that is less than $1 per million request.
<!--stackedit_data:
eyJoaXN0b3J5IjpbMTcxMzIyODY1LDgzNzI1NTc3Myw2ODYzMj
k5MDMsLTE0MzgyODEwODAsOTY0MzE2MTgyLC00NDAyNzIzNzEs
LTEwNDM3Mjc0MDEsLTE5MTY0ODU4NjksLTQyODAyNDM0NSwyOD
QwOTk0MzZdfQ==
-->