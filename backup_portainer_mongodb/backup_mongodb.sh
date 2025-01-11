#!/bin/bash

# === Configuration ===
DB_HOST="127.0.0.1:27017" # MODIFY HERE
DB_NAME="HuuNghiaIsh" # MODIFY HERE
BACKUP_DIR="/home/deploy/dumpmongo"
PROMETHEUS_DIR="/etc/prometheus"
RCLONE_REMOTE="gdrive"
RCLONE_PATH="${RCLONE_REMOTE}:/dumpmongo/${DB_NAME}"

# === Functions ===
dump_mongodb() {
    local timestamp=$(date +%d%m%y%H)
    local backup_path="$BACKUP_DIR/$timestamp"
    mkdir -p "$backup_path"
    mongodump --host "$DB_HOST" --gzip -o "$backup_path"
    if [ $? -ne 0 ]; then
        echo "ERROR: MongoDB dump failed."
        exit 1
    fi
    echo "MongoDB dump completed successfully: $backup_path"
    echo "$backup_path"
}

clean_old_backups() {
    echo "Cleaning old backups..."
    find "$BACKUP_DIR" -maxdepth 1 -type d -mmin +1440 -exec rm -rf "{}" \;
    echo "Old backups cleaned successfully."
}

sync_to_drive() {
    echo "Synchronizing MongoDB backups to Google Drive..."
    rclone sync "$BACKUP_DIR" "$RCLONE_PATH" --delete-during --progress
    if [ $? -ne 0 ]; then
        echo "ERROR: Synchronization with Google Drive failed."
        exit 1
    fi
    echo "Synchronization with Google Drive completed successfully."
}

update_prometheus_metrics() {
    local timestamp=$(($(date -u +%s) * 1000))
    echo "dump_mongodb_time $timestamp" > "$PROMETHEUS_DIR/dump_mongodb_time.prom"
    echo "Prometheus metrics updated successfully."
}

# === Main Execution ===
dump_mongodb
clean_old_backups
sync_to_drive
update_prometheus_metrics