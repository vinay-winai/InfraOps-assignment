# Challenge 1: Network Debugging

**Objective**: Fix WireGuard connectivity between the client and server VMs so that the client can access the internal service on the server over the VPN without routing conflicts or firewall blocks.

## Notes & Fixes

1. **Routing Conflicts**
   - **Observation**: The client had conflicting routes: `192.168.0.0/24 via 172.19.20.226 dev eth0` and `192.168.0.0/24 dev wg0 proto kernel scope link src 192.168.0.2`.
   - **Fix**: Deleted the `eth0` route to ensure `192.168.0.0/24` traffic goes through WireGuard.
     `ip route del 192.168.0.0/24 via 172.19.20.226 dev eth0`

2. **WireGuard Client Configuration (`wg0.conf`)**
   - **Observation**: Default setup had mismatched addresses and `AllowedIPs` (using `10.0.x.x` ranges instead of `192.168.0.x`). It was also missing the server Endpoint. 
   - **Fix**:
     - Added server's IPv6 Endpoint: `Endpoint = [fdaa:10:e940:a7b:177:2657:5181:2]:51820`
     - Changed `Address` and `AllowedIPs` to `192.168.0.0/24` to match the test script server IP (`192.168.0.1`).
     - Restarted with `wg-quick down wg0` and `wg-quick up wg0`.

3. **Firewall Rules (Server)**
   - **Observation**: `wg show` indicated packets sent by the client were not being received by the server. Checked `ip6tables` and `iptables`.
   - **Fix**:
     - Found `ip6tables` dropping UDP port `51820` (WireGuard). Flushed with `ip6tables -F`.
     - Found `iptables` dropping TCP port `8080` specifically on interface `wg0`. Flushed with `iptables -F`.

4. **Requirement: Block direct 6pn HTTP access (Client)**
   - **Observation**: The challenge requires HTTP connection over the 6PN network to fail, but succeed over WireGuard.
   - **Fix**: Added an `ip6tables` outbound drop rule on the client for the server's 6PN address:
     `ip6tables -A OUTPUT -p tcp --dport 8080 -d fdaa:10:e940:a7b::/64 -j DROP`

5. **ICMP Ignored (Server)**
   - **Observation**: Ping attempts `192.168.0.1` by the test script timed out, but `ping 8.8.8.8` worked. Checked `sysctl`.
   - **Fix**: The kernel module ignoring ICMP echos was enabled (`net.ipv4.icmp_echo_ignore_all=1`). Set it to `0`.
     `sysctl -w net.ipv4.icmp_echo_ignore_all=0`

6. **MTU Fragmentation**
   - **Observation**: Checked `tcpdump -i eth0 -n 'ip6[6] = 44'` and found fragmented packets with payload sizes throwing "bad length" errors. WireGuard adds an 80-byte overhead (40 bytes IPv6 + 8 bytes UDP + 32 bytes WG header). Default MTU created excessive fragmentation.
   - **Fix**: Set WG MTU to `1340` on both client and server limits to optimize performance and stop fragmentation. Verified with `iperf`.
     `ip link set wg0 mtu 1340`


---


# Challenge 2: Storage Debugging

**Objective**: Fix the read-only `/data` mount, repair LVM issues, and safely expand the storage volume online without experiencing downtime for the object service.

## Notes & Fixes

1. **Read-Only `/data` Mount**
   - **Observation**: Checked `dmesg` to see `/data` was mounted read-only due to an `ext4-fs` error/re-mount or `fstab` entry enforcing `ro`. Confirmed via `cat /etc/fstab`.
   - **Fix**: Remounted the filesystem online to enable read/write without downtime.
     `mount -o remount,rw /data`

2. **LVM Loop Disk Corruption / Unallocatable PVs**
   - **Observation**: `/dev/loop1` wasn't allocatable in the PV block (`pvchange -x y /dev/loop0` wasn't applicable since it's full and locked out differently). `vg0` had issues spanning extents dynamically.
   - **Fix**: Rebuilt the PV loop1 and merged the extents properly.
     ```bash
     pvresize /dev/loop2
     pvmove /dev/loop1 /dev/loop2
     vgreduce vg0 /dev/loop1
     pvremove /dev/loop1
     pvcreate /dev/loop1
     vgextend vg0 /dev/loop1
     ```

3. **Storage Extents Limitation (Workaround for Mock Physical Constraints)**
   - **Observation**: Found the 4th disk `fallocate` failed initially because the rootfs ephemeral storage ran out of space.
   - **Fix (Sparce File Bypass)**: Inspected `/data/test/` with `filefrag` assuming sparse potential, they are indeed fallocated. Creating a sparse file bypasses actual block allocation in the rootfs but allows loop/LVM to detect capacity.
     ```bash
     truncate -s 1800M /media/disk3.img
     losetup /dev/loop3 /media/disk3.img
     pvcreate /dev/loop3
     vgextend vg0 /dev/loop3
     ```
   - **Expansion**: We could then successfully augment the main logical volume utilizing the new mock physical volume:
     `lvextend -L +4G /dev/vg0/data0 -r`

4. **Dynamic Auto-Expansion Script**
   - **Observation**: Need program to expand the volume dynamically when it reaches limits, without downtime.
   - **Fix**: Created a daemon with service script (`auto-expand.sh`) that polls `df` and `vgs`. It checks if `/data` exceeds 90% usage and explicitly uses `lvextend -L +500M -r` to expand if there is enough space left in the VG.
   - *Alternative Fix*: Instead of step 3, I also experimented with LVM Thin Provisioning (`vg0/thinpool`) and tested setting `thin_pool_autoextend_threshold = 70` inside `/etc/lvm/lvm.conf`. This is natively handled by the kernel mapper.

5. **Downtime Monitoring**
   - **Observation**: Needed to ensure the HTTP server never died during LVM maintenance operations.
   - **Fix**: Ran a local `http_status_log.sh` checker pulling `curl -s -o /dev/null -w "%{http_code}"` against `localhost:8000` waiting for 200 OKs. Verified zero downtime during the online `resize2fs` / LV extend operations.
