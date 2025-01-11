#!/bin/bash

# Đường dẫn đến thư mục backup
BACKUP_DIR="/home/deploy/dumpstack/port.t.huunghiaish.com"

# Địa chỉ và thông tin đăng nhập của Portainer
PORTAINER_URL="https://port.t.huunghiaish.com/api"
USERNAME="admin"
PASSWORD="Password@123"
ENDPOINT_ID=1 # Chỉnh sửa giá trị này cho phù hợp với endpointId của bạn

# Địa chỉ mới của máy chủ Redis và Mongo
NEW_REDIS_HOST="10.0.0.10"
NEW_MONGO_HOST="10.0.0.10:27017"

# Check if required commands are installed
for cmd in curl jq sed; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it and try again."
    exit 1
  fi
done

# Đăng nhập vào Portainer và lấy JWT token
TOKEN=$(curl -s -H "Content-Type: application/json" -d "{\"Username\":\"$USERNAME\",\"Password\":\"$PASSWORD\"}" "$PORTAINER_URL/auth" | jq -r .jwt)

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "Error: Failed to retrieve JWT token. Please check your credentials."
  exit 1
fi

# Hàm ghi vào nhật ký
log_message() {
  local timestamp=$(date +"%a %d %b %Y %r %Z")
  case $1 in
    "started")
      echo "Khôi phục bắt đầu vào lúc $timestamp"
      ;;
    "finished")
      echo "Khôi phục hoàn thành vào lúc $timestamp"
      ;;
    *)
      echo "$timestamp: $1"
      ;;
  esac
}

# Hàm tạo chuỗi ngẫu nhiên
generate_random_string() {
  cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 10 | head -n 1
}

# Hàm gửi yêu cầu tạo stack
create_stack() {
  local stack_name=$1
  local request_body=$2

  response=$(curl "$PORTAINER_URL/stacks/create/swarm/string?endpointId=$ENDPOINT_ID" \
  -H 'accept: application/json, text/plain, */*' \
  -H "authorization: Bearer $TOKEN" \
  -H 'content-type: application/json' \
  --data-raw "$request_body" \
  --silent --write-out 'HTTPSTATUS:%{http_code}')

  # extract the body and HTTP status code
  HTTP_STATUS=$(echo $response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
  response=$(echo $response | sed -e 's/HTTPSTATUS\:.*//g')

  # check the HTTP status code
  if [ "$HTTP_STATUS" -ne 200 ]; then
    echo "Error [HTTP status: $HTTP_STATUS]"
    echo "Response: $response"
    exit 1
  fi
}

# Hàm tạo stack init với tên ngẫu nhiên
create_stack_init() {
  local random_string=$(generate_random_string)
  local stack_name="init_$random_string"

  # Example stack content and environment variables
  local stack_content='version: "3.7"
services:
  hello-world:
    image: hello-world'
  local env_content='[
    {
      "name": "INIT_VAR",
      "value": "some_value"
    }
  ]'

  # Lấy Swarm ID từ endpoint
  local swarm_id=$(curl -s -H "Authorization: Bearer $TOKEN" "$PORTAINER_URL/endpoints/$ENDPOINT_ID/docker/swarm" | jq -r .ID)

  if [ -z "$swarm_id" ]; then
    log_message "Error: Failed to retrieve Swarm ID for endpoint $ENDPOINT_ID."
    exit 1
  fi

  # Ghi thông tin vào nhật ký
  log_message "Creating init stack '$stack_name'..."

  # request_body
  local request_body=$(cat <<EOF
{
  "method": "string",
  "type": "swarm",
  "Name": "$stack_name",
  "SwarmID": "$swarm_id",
  "StackFileContent": $(echo "$stack_content" | jq -Rs .),
  "Env": $env_content
}
EOF
)
  # Gửi yêu cầu tạo stack
  create_stack "$stack_name" "$request_body"

  # Ghi thông tin vào nhật ký khi stack init hoàn thành việc tạo
  log_message "Init stack '$stack_name' đã được tạo."
}

# Ghi thông tin vào nhật ký khi bắt đầu quá trình phục hồi
log_message "started"

# Tạo stack init với tên ngẫu nhiên
create_stack_init

# Lặp qua từng thư mục trong thư mục backup
for dir in "$BACKUP_DIR"/*; do
  if [ -d "$dir" ]; then
    stack_name=$(basename "$dir")

    # Đọc dữ liệu từ stack.json và chuyển đổi thành chuỗi JSON
    stack_content=$(cat "$dir/stack.json")
    env_content=$(cat "$dir/env.json")

    # Get a list of all stacks
    stacks=$(curl -s -H "Authorization: Bearer $TOKEN" "$PORTAINER_URL/stacks")

    # Get the ID of the latest stack
    latest_stack_id=$(echo "$stacks" | jq -r 'sort_by(.CreatedAt) | last | .Id')

    echo "VUI LÒNG KIỂM TRA Latest stack ID: $latest_stack_id"

    NEW_REDIS_DB=$((latest_stack_id + 1))

    # Thay đổi địa chỉ Redis trong stack_content bằng sed
    stack_content=$(sed "s/REDIS_HOST: [0-9\.]*\\\\n/REDIS_HOST: $NEW_REDIS_HOST\\\\n/g" <<< "$stack_content")

    # Thay đổi giá trị Redis DB trong env_content bằng jq
    env_content=$(jq "map(if .name == \"REDIS_DB\" then .value = \"$NEW_REDIS_DB\" elif .name == \"MONGO_HOST\" then .value = \"$NEW_MONGO_HOST\" else . end)" <<< "$env_content")

    # Lấy Swarm ID từ endpoint
    swarm_id=$(curl -s -H "Authorization: Bearer $TOKEN" "$PORTAINER_URL/endpoints/$ENDPOINT_ID/docker/swarm" | jq -r .ID)

    # Ghi thông tin vào nhật ký
    log_message "Bắt đầu khôi phục stack '$stack_name'..."

    # request_body
    request_body=$(cat <<EOF
{
  "method": "string",
  "type": "swarm",
  "Name": "$stack_name",
  "SwarmID": "$swarm_id",
  "StackFileContent": $stack_content,
  "Env": $env_content
}
EOF
)
    # Gửi yêu cầu tạo stack
    create_stack "$stack_name" "$request_body"

    # Ghi thông tin vào nhật ký khi mỗi stack hoàn thành việc phục hồi
    log_message "Stack '$stack_name' đã được khôi phục."

    # Đợi 1 giây để tránh quá tải hệ thống (tùy chỉnh theo nhu cầu)
    sleep 1
  fi
done

# Ghi thông tin vào nhật ký khi quá trình phục hồi hoàn thành
log_message "finished"
