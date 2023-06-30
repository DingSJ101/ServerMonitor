#!/bin/bash

# 构造JSON字段函数
construct_json_field() {
  local key="$1"
  local value="$2"
  local is_last="$3"
  # echo "$key" "$value" "$is_last"
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
script_dir=$(dirname "$0")
config_file="$script_dir/config.json"
config_data=$(sed '/^[[:blank:]]*\/\//d' "$config_file" )

# 遍历每个配置任务并执行
for task in $(echo "$config_data" | jq -r '.configurations[].task'); do

  json_data="{"
  # 获取当前配置
  current_config=$(echo "$config_data" | jq -r ".configurations[] | select(.task == \"$task\")")
  # echo "$current_config"
  task=$(echo "$current_config" | jq -r '.task')
  construct_json_field "task" "$task"
  # 获取URL
  url=$(echo "$current_config" | jq -r '.url')

  # 获取当前时间
  current_time=$(date +%Y-%m-%d\ %H:%M:%S)
  construct_json_field "time" "$current_time"

  # 获取IP地址
  ip_address=$(hostname -I | awk '{print $1}')
  construct_json_field "ip" "$ip_address" 

  # 获取主机名
  if [[ $(echo "$current_config"| jq -r '.hostname') == "true" ]]; then
    hostname=$(hostname)
    construct_json_field "hostname" "$hostname"
  fi

  # 获取CPU使用率
  if [[ $(echo "$current_config"| jq -r '.cpu_usage') == "true" ]]; then
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    construct_json_field "cpu_usage" "$cpu_usage"
  fi

  if [[ $(echo "$current_config"| jq -r '.memory_usage') == "true" ]]; then
    # 获取内存总量
    total_memory=$(free -h | grep 'Mem' | awk '{print $2}')
    # 获取已使用内存量
    used_memory=$(free -h | grep 'Mem' | awk '{print $3}')
    construct_json_field "total_memory" "$total_memory"
    construct_json_field "used_memory" "$used_memory"
  fi

  # 获取显卡显存使用量
  # gpu_memory_usage=()
  # gpu_memory_total=()
  if [[ $(echo "$current_config"| jq -r '.gpu_usage') == "true" ]]; then
    gpu_ids=($(echo "$current_config"|jq -r '.gpu_ids[]' ))
    for id in "${gpu_ids[@]}"; do
      # 每张显卡的显存
      memory_usage=$(nvidia-smi --id=$id --query-gpu=memory.used --format=csv,noheader,nounits| awk '{ total += $1 } END { print total " MiB" }')
      memory_total=$(nvidia-smi --id=$id --query-gpu=memory.total --format=csv,noheader,nounits| awk '{ total += $1 } END { print total " MiB" }')
      construct_json_field "gpu_${id}_usage" "$memory_usage"
      construct_json_field "gpu_${id}_total" "$memory_total"
      # gpu_memory_usage+=("$memory_usage")
      # gpu_memory_total+=("$memory_total")

      processes=$(nvidia-smi --id=$id --query-compute-apps=pid,used_memory --format=csv,noheader,nounits)
      # Sort the processes by memory usage in descending order
      sorted_processes=$(echo "$processes" | sort -t',' -k2 -nr) 
      pid_cnt=0
      while IFS= read -r row; do
        # 如果pid为空，则跳过
        if [[ -z "$row" ]]; then
          continue
        fi
        pid_cnt=$((pid_cnt+1))
        pid=$(echo "$row" | cut -d',' -f1)
        memory=$(echo "$row" | cut -d',' -f2)
        user=$(ps -p $pid -o user --no-headers)
        cmd=$(ps -p $pid -o cmd --no-headers)
        # construct_json_field "gpu_${id}_pid_${pid_cnt}" "$pid"
        construct_json_field "gpu_${id}_memory_${pid_cnt}" "$memory MiB"
        construct_json_field "gpu_${id}_user_${pid_cnt}" "$user"
        construct_json_field "gpu_${id}_cmd_${pid_cnt}" "$cmd"
      done <<< "$sorted_processes"
    done
  fi
  
  # # 填充默认的四个元素
  # while [ "${#gpu_memory_usage[@]}" -lt 4 ]; do
  #   gpu_memory_usage+=("N/A")
  # done
  # while [ "${#gpu_memory_total[@]}" -lt 4 ]; do
  #   gpu_memory_total+=("N/A")
  # done
  
  # 获取磁盘使用量
  if [[ $(echo "$current_config"| jq -r '.disk_usage_home') == "true" ]]; then
    home_usage=$(df -h | awk '/\/home$/ {print $3}')
    home_total=$(df -h | awk '/\/home$/ {print $2}')
    construct_json_field "home_usage" "$home_usage"
    construct_json_field "home_total" "$home_total"
  fi


#   # 构建JSON数据
#   json_data=$(cat <<EOF
# {
#   "time": "$current_time",
#   "ip": "$ip_address",
#   "cpu_usage": "$cpu_usage",
#   "hostname": "$hostname",
#   "total_memory": "$total_memory",
#   "used_memory": "$used_memory",
#   "gpu_memory": "$gpu_memory",
#   "gpu_0":"${gpu_memory_usage[0]}",
# }
# EOF
# )
# json_data=$(cat <<EOF
# {
#   "gpu_0":"${gpu_memory_usage[0]}",
#   "gpu_0":"${gpu_memory_usage[3]}",
# }
# EOF
# )


  construct_json_field "end" "END" "END"
  # 保存JSON数据到文件
  # echo "$json_data" > status.json
  echo "$json_data"

  # 发送JSON数据到URL
  # curl -X POST -H "Content-Type: application/json" -d "@status.json" "$url"
  curl -X POST -H "Content-Type: application/json" -d "$json_data" "$url"
  # echo "$url"
done


#TODO - 通过github action 执行docker，通过ssh进入服务器执行脚本
#FIXME - 需要设置VPN
#FIXME - 需要设置ssh配置和登录脚本

# TODO - 设置多个webhook监听不同任务
