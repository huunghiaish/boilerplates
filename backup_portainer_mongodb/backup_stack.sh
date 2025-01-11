#!/bin/bash

# === Configuration ===
STACK_NAME="port.t.huunghiaish.com" # MODIFY HERE
BACKUP_DIR="/home/deploy/dumpstack"
PROMETHEUS_DIR="/etc/prometheus"
RCLONE_REMOTE="gdrive"
RCLONE_PATH="${RCLONE_REMOTE}:/dumpstack/${STACK_NAME}"
PORTAINER_URL="https://${STACK_NAME}/api"
USERNAME="admin"
PASSWORD="Password@123"

# === Functions ===
authenticate_portainer() {
    echo "Authenticating with Portainer..."
    local token=$(curl -s -H "Content-Type: application/json" -d "{\"Username\":\"$USERNAME\",\"Password\":\"$PASSWORD\"}" "$PORTAINER_URL/auth" | jq -r .jwt)
    if [[ -z "$token" || "$token" == "null" ]]; then
        echo "ERROR: Failed to authenticate with Portainer."
        exit 1
    fi
    echo "$token"
}

dump_stacks() {
    local token=$1
    local stacks_file=$(mktemp)
    curl -s -H "Authorization: Bearer $token" "$PORTAINER_URL/stacks" > "$stacks_file"
    if [[ ! -s "$stacks_file" ]]; then
        echo "ERROR: Failed to retrieve stacks."
        rm "$stacks_file"
        exit 1
    fi

    jq -r '.[] | "\(.Name) \(.Id)"' "$stacks_file" | while read -r name id; do
        local stack_dir="$BACKUP_DIR/$name"
        mkdir -p "$stack_dir"
        curl -s -H "Authorization: Bearer $token" "$PORTAINER_URL/stacks/$id/file" | jq -r .StackFileContent > "$stack_dir/stack.json"
        curl -s -H "Authorization: Bearer $token" "$PORTAINER_URL/stacks/$id" | jq -r '.Env[] | {name: .name, value: .value}' > "$stack_dir/env.json"
        echo "Backup completed for stack: $name"
    done
    rm "$stacks_file"
}

sync_to_drive() {
    echo "Synchronizing stack backups to Google Drive..."
    rclone sync "$BACKUP_DIR" "$RCLONE_PATH" --delete-before --progress
}

update_prometheus_metrics() {
    local timestamp=$(($(date -u +%s) * 1000))
    echo "dump_stacks_time $timestamp" > "$PROMETHEUS_DIR/dump_stacks_time.prom"
    echo "Prometheus metrics updated successfully."
}

# === Main Execution ===
mkdir -p "$BACKUP_DIR" "$PROMETHEUS_DIR"
token=$(authenticate_portainer)
dump_stacks "$token"
sync_to_drive
update_prometheus_metrics