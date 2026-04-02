# Storage Debugging Challenge Report

## Objective
Fix the read-only `/data` mount, repair LVM issues, and safely expand the storage volume online without experiencing any downtime for the running application.

## Issues Identified & Fixed

### 1. Read-Only Disk Mount
The `dmesg` logs showed that the `/data` directory had switched to a read-only partition (`ro`), effectively preventing new data writes. The `/etc/fstab` configuration inadvertently enforced the restrictive mount.
* **Fix**: Remounted the filesystem online to enable read/write capabilities without downtime:
  ```bash
  mount -o remount,rw /data
  ```

### 2. Loop Disk Corruptions
Inspecting LVM showed physical volume issues, particularly that `/dev/loop1` wasn't allocatable. There was also the imminent threat of rootfs running completely out of space.
* **Fix**: Mitigated corrupt metadata and properly migrated the extents to ensure stable volume groups.
  ```bash
  pvresize /dev/loop2
  pvmove /dev/loop1 /dev/loop2
  vgreduce vg0 /dev/loop1
  pvremove /dev/loop1
  pvcreate /dev/loop1
  vgextend vg0 /dev/loop1
  ```

### 3. Safely Expanding Storage Capacity
To combat running out of physical limits during the simulated disk growth, an expansion method was formulated leveraging sparse files.
* **Fix**: Created an additional image backed by a sparse file, added it as a loop device, initialized as a PV, and extended the LV seamlessly:
  ```bash
  truncate -s 1800M /media/disk3.img
  losetup /dev/loop3 /media/disk3.img
  pvcreate /dev/loop3
  vgextend vg0 /dev/loop3
  lvextend -L +4G /dev/vg0/data0 -r
  ```

### 4. Thin Provisioning and Dynamic Auto-Expansion
To fully automate future block capacity exhaustion, two potential strategies were engineered:

**Strategy A: Auto-Expand Custom Daemon**
Written a Bash lifecycle loop running in the background (`auto-expand.sh`) and daemonized via `systemd`. It proactively monitors `df` usage and LVM capacities, issuing an `lvextend -r` command whenever space usage rises over 90%.
```bash
if [ "$DUSAGE" -gt 90 ] && [ "$VG_FREE" -ge "$EXPAND_SIZE" ]; then
    lvextend -L +"${EXPAND_SIZE}M" /dev/vg0/data0 -r
```

**Strategy B: LVM Thin Pools**
Explored allocating an optimized thin pool (`vg0/thinpool`) to allow over-commit allocations natively. Adjusted `lvm.conf` parameter:
```ini
thin_pool_autoextend_threshold = 70
```
This enables the kernel mapper to intercept writes and allocate chunk boundaries dynamically.

## Validation & Results
A background curling process (`http_status_log.sh`) continuously monitored an HTTP app serving endpoints for 200 OK statuses, verifying zero downtime.

Running the storage verifier script completed all assertions:
```
root@32876262f07685:/media# /usr/local/bin/test-storage.sh
PASS: Successfully wrote to the data dir.
PASS: Detected 4 PVs
PASS: All PVs are correctly sized.
PASS: The data0 LV is 4096 MiB.
PASS: Data in /data/objects checksums correctly.
...
Logical volume vg0/data0 successfully resized.
...
PASS: /data is at least 6G
```
