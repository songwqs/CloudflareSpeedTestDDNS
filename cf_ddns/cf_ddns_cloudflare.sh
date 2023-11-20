#!/bin/bash
#		版本：20231004
#         用于CloudflareST调用，更新hosts和更新cloudflare DNS。

ipv4Regex="((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])";
CLOUDFLAREST_PATH="./cf_ddns/CloudflareST";
#获取空间id
zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo ${hostname[0]} | cut -d "." -f 2-)" -H "X-Auth-Email: $x_email" -H "X-Auth-Key: $api_key" -H "Content-Type: application/json" | jq -r '.result[0].id' )

if [ "$IP_TO_CF" = "1" ]; then
  # 验证cf账号信息是否正确
  res=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json");
  resSuccess=$(echo "$res" | jq -r ".success");
  if [[ $resSuccess != "true" ]]; then
    echo "登陆错误，检查cloudflare账号信息填写是否正确!"
    echo "登陆错误，检查cloudflare账号信息填写是否正确!" > $informlog
    source $cf_push;
    exit 1;
  fi
  echo "Cloudflare账号验证成功";
else
  echo "未配置Cloudflare账号"
fi

# 获取域名填写数量
num=${#hostname[*]};

# 判断优选ip数量是否大于域名数，小于则让优选数与域名数相同
if [ "$CFST_DN" -le $num ] ; then
  CFST_DN=$num;
fi
CFST_P=$CFST_DN;

# 判断工作模式
if [ "$IP_ADDR" = "ipv6" ] ; then
  if [ ! -f "./cf_ddns/ipv6.txt" ]; then
    echo "当前工作模式为ipv6，但该目录下没有【ipv6.txt】，请配置【ipv6.txt】。下载地址：https://github.com/XIU2/CloudflareSpeedTest/releases";
    exit 2;
  else
    echo "当前工作模式为ipv6";
  fi
else
  echo "当前工作模式为ipv4";
fi

#读取配置文件中的客户端
case $clien in
  "6") CLIEN=bypass;;
  "5") CLIEN=openclash;;
  "4") CLIEN=clash;;
  "3") CLIEN=shadowsocksr;;
  "2") CLIEN=passwall2;;
  *) CLIEN=passwall;;
esac

# 判断是否停止科学上网服务
if [ "$pause" = "false" ] ; then
  echo "按要求未停止科学上网服务";
else
  /etc/init.d/$CLIEN stop;
  echo "已停止$CLIEN";
fi

#判断是否配置测速地址 
if [[ "$CFST_URL" == http* ]] ; then
  CFST_URL_R="-url $CFST_URL -tp $CFST_TP ";
else
  CFST_URL_R="";
fi

# 检查 cfcolo 变量是否为空
if [[ -n "$cfcolo" ]]; then
  cfcolo="-cfcolo $cfcolo"
fi

# 检查 httping_code 变量是否为空
if [[ -n "$httping_code" ]]; then
  httping_code="-httping-code $httping_code"
fi

# 检查 CFST_STM 变量是否为空
if [[ -n "$CFST_STM" ]]; then
  CFST_STM="-httping $httping_code $cfcolo"
fi

# 检查是否配置反代IP
if [ "$IP_PR_IP" = "1" ] ; then
		  if [ -e ./cf_ddns/.pr_ip_timestamp ]; then
		    # 文件存在
		    if [[ $(cat ./cf_ddns/.pr_ip_timestamp | jq -r ".pr1_expires") -le $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) ]]; then
		        # 文件存在且时间戳小于等于当前时间戳，执行更新操作
		        curl -sSf -o ./cf_ddns/pr_ip.txt https://cf.vbar.fun/pr_ip.txt
		        echo "{\"pr1_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > ./cf_ddns/.pr_ip_timestamp
		        echo "已更新线路1的反向代理列表"
		    fi
		else
		    # 文件不存在，执行相应的操作
		    echo "Error: File ./cf_ddns/.pr_ip_timestamp does not exist. Downloading the file and creating it..."
		    curl -sSf -o ./cf_ddns/pr_ip.txt https://cf.vbar.fun/pr_ip.txt
		    echo "{\"pr1_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > ./cf_ddns/.pr_ip_timestamp
		fi
elif [ "$IP_PR_IP" = "2" ] ; then
	 		if [ -e ./cf_ddns/.pr_ip_timestamp ]; then
			    # 文件存在
			    if [[ $(cat ./cf_ddns/.pr_ip_timestamp | jq -r ".pr2_expires") -le $(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) ]]; then
			        # 文件存在且时间戳小于等于当前时间戳，执行更新操作
			        curl -sSf -o ./cf_ddns/pr_ip.txt https://cf.vbar.fun/zip_baipiao_eu_org/pr_ip.txt
			        echo "{\"pr2_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > ./cf_ddns/.pr_ip_timestamp
			        echo "已更新线路2的反向代理列表"
			    fi
			else
			    # 文件不存在，下载文件并执行相应的操作
			    echo "Error: File ./cf_ddns/.pr_ip_timestamp does not exist. Downloading the file and creating it..."
			    curl -sSf -o ./cf_ddns/pr_ip.txt https://cf.vbar.fun/zip_baipiao_eu_org/pr_ip.txt
			    echo "{\"pr2_expires\":\"$(($(date -d "$(date "+%Y-%m-%d %H:%M:%S")" +%s) + 86400))\"}" > ./cf_ddns/.pr_ip_timestamp
			fi
fi


	# 检查 CloudflareST 是否存在
	if [ ! -x "$CLOUDFLAREST_PATH" ]; then
	    echo "CloudflareST not found. Downloading..."
	
	    # 获取系统架构
	    ARCHITECTURE=$(uname -m)
	    
	    # 获取最新版本号
	    LATEST_VERSION=$(curl -s "https://api.github.com/repos/XIU2/CloudflareSpeedTest/releases/latest" | jq -r .tag_name)
	    echo "最新版本$LATEST_VERSION"
	    if [ "$LATEST_VERSION" == "null" ]; then
	        echo "Failed to fetch the latest version from GitHub API."
	        exit 1
	    fi

	     # 判断架构并设置对应的下载链接
    case $ARCHITECTURE in
        x86_64)
            DOWNLOAD_URL="https://git.songw.top/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/CloudflareST_linux_amd64.tar.gz"
            ;;
        armv7l)
            DOWNLOAD_URL="https://git.songw.top/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/CloudflareST_linux_armv7.tar.gz"
            ;;
        aarch64)
            DOWNLOAD_URL="https://git.songw.top/https://github.com/XIU2/CloudflareSpeedTest/releases/download/$LATEST_VERSION/CloudflareST_linux_arm64.tar.gz"
            ;;
        *)
            echo "没找到这个架构: $ARCHITECTURE 可以去项目地址看看 https://github.com/XIU2/CloudflareSpeedTest/releases/tag/$LATEST_VERSION"
            exit 1
            ;;
    esac
	    TMP_ARCHIVE="/tmp/CloudflareST.tar.gz"
	    # 下载最新版本 CloudflareST
	    curl -L -o "$TMP_ARCHIVE" "$DOWNLOAD_URL"
	
	    # 解压缩文件
	    tar -xzvf "$TMP_ARCHIVE" -C ./cf_ddns/
	    
	    # 删除临时压缩文件
	    rm "$TMP_ARCHIVE"
	    # 设置执行权限
    	  chmod +x "$CLOUDFLAREST_PATH"
	
	    echo "CloudflareST downloaded and installed successfully."
	fi
	# 检查 result.csv 文件是否存在，如果不存在则创建
	if [ ! -e ./cf_ddns/result.csv ]; then
	    touch ./cf_ddns/result.csv
	fi


 if [ ! -e "./cf_ddns/pr_ip.txt" ]; then
    if [ -e "./cf_ddns/ip.txt" ]; then
        mv "./cf_ddns/ip.txt" "./cf_ddns/pr_ip.txt"
    else
    	   curl -sSf -o ./cf_ddns/pr_ip.txt https://cf.vbar.fun/pr_ip.txt
        echo "默认下载ip-scanner/cloudflare仓库"
    fi
else
    echo "pr_ip.txt already exists."
fi
if [ "$IP_PR_IP" -ne "0" ] ; then
  $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f ./cf_ddns/pr_ip.txt -o ./cf_ddns/result.csv
elif [ "$IP_ADDR" = "ipv6" ] ; then
  #开始优选IPv6
  $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f ./cf_ddns/ipv6.txt -o ./cf_ddns/result.csv
else
  #开始优选IPv4
  $CloudflareST $CFST_URL_R -t $CFST_T -n $CFST_N -dn $CFST_DN -tl $CFST_TL -dt $CFST_DT -tp $CFST_TP -tll $CFST_TLL -sl $CFST_SL -p $CFST_P -tlr $CFST_TLR $CFST_STM -f ./cf_ddns/ip.txt -o ./cf_ddns/result.csv
fi
echo "测速完毕";

#判断是否重启科学服务
if [ "$pause" = "false" ] ; then
  echo "按要求未重启科学上网服务";
  sleep 3s;
else
  /etc/init.d/$CLIEN restart;
  echo "已重启$CLIEN";
  echo "等待${sleepTime}秒后开始更新DNS！"
  sleep ${sleepTime}s;
fi

# 开始循环
echo "正在更新域名，请稍后..."
x=0

while [[ ${x} -lt $num ]]; do
  CDNhostname=${hostname[$x]}
  
  # 获取优选后的ip地址
  ipAddr=$(sed -n "$((x + 2)),1p" ./cf_ddns/result.csv | awk -F, '{print $1}');
  ipSpeed=$(sed -n "$((x + 2)),1p" ./cf_ddns/result.csv | awk -F, '{print $6}');
  if [ "$ipSpeed" == "0.00" ]; then
    echo "第$((x + 1))个---$ipAddr测速为0，跳过更新DNS，检查配置是否能正常测速！";
  else
    if [ "$IP_TO_HOSTS" = 1 ]; then
      echo $ipAddr $CDNhostname >> ./cf_ddns/hosts_new
    fi

    if [ "$IP_TO_CF" = 1 ]; then
      echo "开始更新第$((x + 1))个---$ipAddr"

      # 开始DDNS
      if [[ $ipAddr =~ $ipv4Regex ]]; then
        recordType="A"
      else
        recordType="AAAA"
      fi

      listDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?type=${recordType}&name=${CDNhostname}"
      createDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records"

      # 关闭小云朵
      proxy="false"
  
      res=$(curl -s -X GET "$listDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json")
      recordId=$(echo "$res" | jq -r ".result[0].id")
      recordIp=$(echo "$res" | jq -r ".result[0].content")
  
      if [[ $recordIp = "$ipAddr" ]]; then
        echo "更新失败，获取最快的IP与云端相同"
        resSuccess=false
      elif [[ $recordId = "null" ]]; then
        res=$(curl -s -X POST "$createDnsApi" -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
        resSuccess=$(echo "$res" | jq -r ".success")
      else
        updateDnsApi="https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${recordId}"
        res=$(curl -s -X PUT "$updateDnsApi"  -H "X-Auth-Email:$x_email" -H "X-Auth-Key:$api_key" -H "Content-Type:application/json" --data "{\"type\":\"$recordType\",\"name\":\"$CDNhostname\",\"content\":\"$ipAddr\",\"proxied\":$proxy}")
        resSuccess=$(echo "$res" | jq -r ".success")
      fi
  
      if [[ $resSuccess = "true" ]]; then
        echo "$CDNhostname更新成功"
      else
        echo "$CDNhostname更新失败"
      fi
    fi
  fi
  x=$((x + 1))
  sleep 3s
done > $informlog

if [ "$IP_TO_HOSTS" = 1 ]; then
  if [ ! -f "/etc/hosts.old_cfstddns_bak" ]; then
    cp /etc/hosts /etc/hosts.old_cfstddns_bak
    cat ./cf_ddns/hosts_new >> /etc/hosts
  else
    rm /etc/hosts
    cp /etc/hosts.old_cfstddns_bak /etc/hosts
    cat ./cf_ddns/hosts_new >> /etc/hosts
    echo "hosts已更新"
    echo "hosts已更新" >> $informlog
    rm ./cf_ddns/hosts_new
  fi
fi
