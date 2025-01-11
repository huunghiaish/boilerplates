#!/bin/bash

# === Configuration ===
VOLUME_NAME="port.t.huunghiaish.com" # MODIFY HERE
BACKUP_DIR="/var/lib/docker/volumes"
PROMETHEUS_DIR="/etc/prometheus"
RCLONE_REMOTE="gdrive"
RCLONE_PATH="${RCLONE_REMOTE}:/backupserver/dumpvolume/${VOLUME_NAME}"

# === Functions ===
sync_to_drive() {
    echo "Starting Docker volumes sync to drive..."
    rclone sync "$BACKUP_DIR" "$RCLONE_PATH" \
        --exclude 'backingFsBlockDev/**' \
        --exclude 'metadata.db' \
        --exclude 'portainer_portainer_data/**' \
        --exclude 'traefik_traefik-public-certificates/**' \
        --delete-during --progress
    if [ $? -ne 0 ]; then
        echo "ERROR: Docker volumes sync failed."
        return 1
    fi
    echo "Docker volumes sync completed successfully."
    return 0
}

update_prometheus_metrics() {
    local timestamp=$(($(date -u +%s) * 1000))
    echo "sync_to_drive_time $timestamp" > "$PROMETHEUS_DIR/sync_to_drive_time.prom"
    echo "Prometheus metrics updated successfully."
}

# === Main Execution ===
sync_to_drive
update_prometheus_metrics