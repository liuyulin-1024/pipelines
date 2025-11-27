#!/bin/bash
set -euo pipefail

: "${nacos_server:?请先设置 nacos_server}"
: "${nacos_username:?请先设置 nacos_username}"
: "${nacos_password:?请先设置 nacos_password}"
: "${group_id:?请先设置 group_id}"
: "${namespace_id:?请先设置 namespace_id}"
: "${data_ids:?请先设置 data_ids，格式如 '文件名:dataId 文件名:dataId'}"

# data_ids 环境变量示例：
# export data_ids="docker-compose.yaml:DataId credentials.json:DataId"
read -r -a DATA_ID_ENTRIES <<< "$data_ids"

login_response=$(curl -s -X POST "$nacos_server/v3/auth/user/login" \
  -d "username=$nacos_username&password=$nacos_password")
token=$(echo "$login_response" | jq -r '.accessToken')

if [[ -z "$token" || "$token" == "null" ]]; then
  echo "登录失败：$login_response"  exit 1
fi
echo "成功获取到登录令牌"

for entry in "${DATA_ID_ENTRIES[@]}"; do
  if [[ "$entry" != *:* ]]; then
    echo "条目格式错误（缺少冒号）：$entry"
    exit 1
  fi

  file_name="${entry%%:*}"
  data_id="${entry#*:}"

  echo "开始拉取 dataId=$data_id 写入 $file_name"
  config_response=$(curl -s -X GET \
    "$nacos_server/v3/console/cs/config?dataId=$data_id&groupName=$group_id&tenant=$namespace_id&namespaceId=$namespace_id" \
    -H "accept: application/json" \
    -H "accesstoken: $token")

  config_content=$(echo "$config_response" | jq -r '.data.content')
  if [[ -z "$config_content" || "$config_content" == "null" ]]; then
    echo "获取配置失败：$config_response"
    exit 1
  fi

  printf '%s\n' "$config_content" > "$file_name"
  echo "已写入 $file_name"
done