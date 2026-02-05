# Dokploy bunny.net waf guide on hetzner
Why bunny and not cloudfare? because cloudfare does not give clear $ pricing per x million request and bandwidth. They are waiting to [trap you](https://www.reddit.com/r/CloudFlare/comments/1oa4lut/does_cloudflare_really_not_charge_for/nk73eka/) once you are locked into their proprietary tools. Give this a watch: https://youtu.be/8zj7ei5Egk8

What you need

 1. bunny.net account 
 2. hetzner vps server*emphasized text*
 3. a domain

This guide involves setting firewall rules at the hetzner network firewall level before it reaches the server. If your server provider has a network firewall, you may be able to add this many ips but we are adding lots of rules, and scripts will have to be modified.

You can keep your current dns records. but bunny is a good free dns provider.

I assume you already set up your dns zone in https://dash.bunny.net/dns/zones

I made a wildcard record for ease, bunny has said they recently started ssl certs for those.




<!--stackedit_data:
eyJoaXN0b3J5IjpbMjIyNDE0MzUzXX0=
-->