# Dokploy bunny.net waf on hetzner Guide
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
Hetzner sets the firewall rules in an api call but it limits to  500 ips per request, even though the firewall holds more, we can't append to it, so each request overrides all the rules.. which means we have to add the 900 bunny ips to multiple firewalls. 
make sure 
<!--stackedit_data:
eyJoaXN0b3J5IjpbNzE4NzIxNTYyLDMzOTI2NjU3NiwtNzUyOD
cyNjYyLC0xNTg3Mzk2MTYyLDE3NDMzNDExNjJdfQ==
-->