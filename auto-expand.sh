#!/bin/bash

# auto-expand.sh
# Expands the /data logical volume proactively when it reaches 90% capacity.

EXPAND_SIZE=500
LOGFILE="/var/log/auto-expand.log"

while true; do
    DUSAGE=$(df /data | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
    VG_FREE=$(vgs -o vg_free --units m --noheadings --nosuffix vg0 | awk '{print int($1)}')
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$DUSAGE" -gt 90 ] && [ "$VG_FREE" -ge "$EXPAND_SIZE" ]; then
        lvextend -L +"${EXPAND_SIZE}M" /dev/vg0/data0 -r
        echo "$TIMESTAMP [INFO] EXPANDED /data by ${EXPAND_SIZE}M. VG Free: ${VG_FREE}M." >> "$LOGFILE"
    elif [ "$DUSAGE" -gt 90 ]; then
        echo "$TIMESTAMP [WARN] Insufficient space (${VG_FREE}M free). ${EXPAND_SIZE}M needed." >> "$LOGFILE"
    fi

    sleep 2
done
