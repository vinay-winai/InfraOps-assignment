# Service Restored: Connectivity Issue between Client and Server Resolved

**Summary of the Incident & Fix**

Recently, the network connection between the "client" and "server" apps was completely broken. While they were previously communicating normally over ****’s standard 6PN private network, a specific requirement dictated they connect encryptedly over a dedicated WireGuard tunnel instead.

**What went wrong?**
There were several configuration errors on both sides preventing the tunnel from working:
1. **Misconfigured Tunnels:** The client machine was using the wrong IP ranges (`10.0.x.x` instead of `192.168.0.x`) and missing the endpoint address for the server.
2. **Conflicting Routes:** The client routing table still preferred sending `192.168.0.x` traffic over the standard network interface (`eth0`) rather than injecting it into our newly created `wg0` tunnel.
3. **Firewall Blocks:** The server's firewall (`iptables`/`ip6tables`) was blocking incoming UDP packets for the VPN and dropping incoming TCP connections intended for the web service. It was also aggressively ignoring Ping (ICMP) checks.
4. **Network MTU Fragmentation:** The default network configuration was trying to send data packets that were too large to fit inside a WireGuard tunnel (which has an 80-byte header overhead), causing massive fragmentation and bad payloads.

**How we fixed it:**
- Fixed the routing conflict and bound the correct IPs to the WireGuard configuration.
- Cleared the blocking firewall rules on the server so the tunnel could handshake and web traffic could flow.
- Added a specific firewall rule to the client *preventing* it from reaching the server directly over the unencrypted 6PN network, forcing all traffic over the secure tunnel.
- Lowered the network interface Maximum Transmission Unit (MTU) to `1340` on both systems, perfectly accommodating the WireGuard packet overhead and resolving the fragmentation lag. 

Both the client and server are now communicating flawlessly over the secure tunnel with optimal performance.
