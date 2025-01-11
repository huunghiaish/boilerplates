#!/bin/bash

# Định nghĩa đường dẫn tới thư mục chứa tất cả các bản backup
ALL_DB_DIR='/home/deploy/dumpmongo/HuuNghiaIsh/01012025'
# Định nghĩa host và port của database mới
HOST_DB_NEW='127.0.0.1:27017'

# Các tên cơ sở dữ liệu bạn không muốn khôi phục
declare -a EXCLUDED_DBS=("admin")

# Duyệt qua tất cả các thư mục con trong thư mục backup
for db_dir in "$ALL_DB_DIR"/*; do
    # Kiểm tra xem db_dir có phải là một thư mục hay không
    if [ -d "$db_dir" ]; then
        # Lấy tên của thư mục (tên database)
        db_name=$(basename "$db_dir")
        # Kiểm tra nếu tên cơ sở dữ liệu không có trong danh sách các cơ sở dữ liệu bị loại bỏ
        if [[ ! " ${EXCLUDED_DBS[@]} " =~ " $db_name " ]]; then
            echo "Restoring database $db_name from $db_dir to $HOST_DB_NEW"

            # Thực hiện restore database với tham số --gzip
            mongorestore --host "$HOST_DB_NEW" --db "$db_name" --gzip "$db_dir"

            # Kiểm tra kết quả của lệnh mongorestore
            if [ $? -eq 0 ]; then
                echo "Successfully restored $db_name"
            else
                echo "Failed to restore $db_name"
            fi
        else
            echo "Skipping restore of database '$db_name'"
        fi
    fi
done
