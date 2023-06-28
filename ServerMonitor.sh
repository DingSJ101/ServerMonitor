#!/bin/bash

# 构造JSON字段函数
construct_json_field() {
  local key="$1"
  local value="$2"
  local is_last="$3"

  json_data+="\"$key\":\"$value\""

  if [[ "$is_last" == "END" ]]; then
    json_data+="}"
  else
    json_data+=","
  fi
}

# how to build json string 
# json_data="{"
# construct_json_field "key1" "$value1" 
# construct_json_field "key2" "$value2" "END"
# add "END" flag at the last item


# 读取配置文件
config_file="config.json"
config_data=$(sed '/\/\//d' "$config_file" )
# echo "$config_data"

# 遍历每个配置任务并执行
for task in $(echo "$config_data" | jq -r '.configurations[].task'); do

  json_data="{"
  # 获取当前配置
  current_config=$(echo "$config_data" | jq -r ".configurations[] | select(.task == \"$task\")")
  
  # 获取URL
  url=$(echo "$current_config" | jq -r '.url')

  # 获取当前时间
  current_time=$(date +%Y-%m-%d\ %H:%M:%S)
  construct_json_field "time" "$current_tiem" 

  # 获取IP地址
  ip_address=$(hostname -I | awk '{print $1}')
  construct_json_field "ip" "$ip_address" 

  # 获取主机名
  if [[ $(echo "$current_config"| jq -r '.hostname') == "true" ]]; then
    hostname=$(hostname)
  else
    hostname=""
  fi

  # 获取CPU使用率
  if [[ $(echo "$current_config"| jq -r '.cpu_usage') == "true" ]]; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
  else
    cpu_usage=""
  fi

  if [[ $(echo "$current_config"| jq -r '.memory_usage') == "true" ]]; then
    # 获取内存总量
    total_memory=$(free -h | grep 'Mem' | awk '{print $2}')
    # 获取已使用内存量
    used_memory=$(free -h | grep 'Mem' | awk '{print $3}')
  else
    total_memory=""
    used_memory=""
  fi

  # 获取显卡显存使用量
  gpu_memory_usage=()
  gpu_memory_total=()
  if [[ $(echo "$current_config"| jq -r '.gpu_usage') == "true" ]]; then
    gpu_ids=($(echo "$current_config"|jq -r '.gpu_ids[]' ))
    for id in "${gpu_ids[@]}"; do
      # 每张显卡的显存
      memory_usage=$(nvidia-smi --id=$id --query-gpu=memory.used --format=csv,noheader,nounits| awk '{ total += $1 } END { print total " MiB" }')
      memory_total=$(nvidia-smi --id=$id --query-gpu=memory.total --format=csv,noheader,nounits| awk '{ total += $1 } END { print total " MiB" }')
      gpu_memory_usage+=("$memory_usage")
      gpu_memory_total+=("$memory_total")
    done
  fi
  
  # 填充默认的四个元素
  while [ "${#gpu_memory_usage[@]}" -lt 4 ]; do
    gpu_memory_usage+=("N/A")
  done
  while [ "${#gpu_memory_total[@]}" -lt 4 ]; do
    gpu_memory_total+=("N/A")
  done
  
  # 获取磁盘使用量
  if [[ $(echo "$current_config"| jq -r '.disk_usage_home') == "true" ]]; then
    home_usage=$(df -h | awk '/\/home$/ {print $3}')
    home_total=$(df -h | awk '/\/home$/ {print $2}')
  else
    home_usage=""
    home_total=""
  fi


  # 构建JSON数据
  json_data=$(cat <<EOF
{
  "time": "$current_time",
  "ip": "$ip_address",
  "cpu_usage": "$cpu_usage",
  "hostname": "$hostname",
  "total_memory": "$total_memory",
  "used_memory": "$used_memory",
  "gpu_memory": "$gpu_memory",
  "gpu_0":"${gpu_memory_usage[0]}",
}
EOF
)
json_data=$(cat <<EOF
{
  "gpu_0":"${gpu_memory_usage[0]}",
  "gpu_0":"${gpu_memory_usage[3]}",
}
EOF
)


  json_data="{"
  construct_json_field "time" "$current_time" 
  construct_json_field "ip" "$ip_address"

  # 保存JSON数据到文件
  # echo "$json_data" > status.json
  echo "$json_data"

  # 发送JSON数据到URL
  # curl -X POST -H "Content-Type: application/json" -d "@status.json" "$url"
done
