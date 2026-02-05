# Dokploy bunny.net waf guide on hetzner
Why bunny and not cloudfare? because cloudfare does not give clear $ pricing per x million request and bandwidth. They are waiting to [trap you](https://www.reddit.com/r/CloudFlare/comments/1oa4lut/does_cloudflare_really_not_charge_for/nk73eka/) once you are locked into their proprietary tools. Give this a watch: https://youtu.be/8zj7ei5Egk8

What you need

 1. bunny.net account 
 2. hetzner vps server*emphasized text*
 3. a domain

This guide involves setting firewall rules at the hetzner network firewall level before it reaches the server. trying to get iptables to work with docker is complex=



<!--stackedit_data:
eyJoaXN0b3J5IjpbLTE4MDEwOTI2NjMsNjY3ODE2NTAyXX0=
-->