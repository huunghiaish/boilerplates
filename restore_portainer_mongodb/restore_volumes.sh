#!/bin/bash

VOLUMES_BACKUP_DIR="/home/deploy/dumpvolume/port.t.huunghiaish.com"
VOLUMES_DES_DIR="/var/lib/docker/volumes"

# Tạo thư mục đích nếu chưa tồn tại
mkdir -p "$VOLUMES_DES_DIR"

# Copy dữ liệu từ thư mục backup sang thư mục đích
rsync -aAXv "$VOLUMES_BACKUP_DIR/" "$VOLUMES_DES_DIR/"

# Kiểm tra kết quả copy
if [ $? -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Chuyển dữ liệu volume thành công"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Lỗi khi chuyển dữ liệu volume"
fi