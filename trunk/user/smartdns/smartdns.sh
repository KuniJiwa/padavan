#!/bin/sh
# Copyright (C) 2018 Nick Peng (pymumu@gmail.com)
# Copyright (C) 2019 chongshengB (bkye@vip.qq.com)
# Copyright (C) 2022 TurBoTse (860018505@qq.com)
#
action="$1"
storage_Path="/etc/storage"
smartdns_Bin="/usr/bin/smartdns"
smartdns_Ini="$storage_Path/smartdns_conf.ini"
smartdns_Conf="$storage_Path/smartdns.conf"
smartdns_tmp_Conf="$storage_Path/smartdns_tmp.conf"
smartdns_address_Conf="$storage_Path/smartdns_address.conf"
smartdns_blacklist_Conf="$storage_Path/smartdns_blacklist-ip.conf"
smartdns_whitelist_Conf="$storage_Path/smartdns_whitelist-ip.conf"
smartdns_custom_Conf="$storage_Path/smartdns_custom.conf"
dnsmasq_Conf="$storage_Path/dnsmasq/dnsmasq.conf"
chn_Route="$storage_Path/chinadns/chnroute.txt"
smartdns_core_Path="/tmp/smartdns-core"

sdns_enable=$(nvram get sdns_enable)
sdns_name=$(nvram get sdns_name)
sdns_port=$(nvram get sdns_port)
sdns_tcp_server=$(nvram get sdns_tcp_server)
sdns_ipv6_server=$(nvram get sdns_ipv6_server)
sdns_redirect=$(nvram get sdns_redirect)
sdns_cache=$(nvram get sdns_cache)
sdns_cache_persist=$(nvram get sdns_cache_persist)
sdns_tcp_idle_time=$(nvram get sdns_tcp_idle_time)
sdns_rr_ttl=$(nvram get sdns_rr_ttl)
sdns_rr_ttl_min=$(nvram get sdns_rr_ttl_min)
sdns_rr_ttl_max=$(nvram get sdns_rr_ttl_max)
sdns_rr_ttl_reply_max=$(nvram get sdns_rr_ttl_reply_max)
sdns_max_reply_ip_num=$(nvram get sdns_max_reply_ip_num)
sdns_speed=$(nvram get sdns_speed)
sdns_speed_mode=$(nvram get sdns_speed_mode)
sdns_address=$(nvram get sdns_address)
sdns_ipset=$(nvram get sdns_ipset)
sdns_ipset_timeout=$(nvram get sdns_ipset_timeout)
sdns_as=$(nvram get sdns_as)
sdns_ip_change=$(nvram get sdns_ip_change)
sdns_ip_change_time=$(nvram get sdns_ip_change_time)
sdns_dualstack_ip_allow_force_aaaa=$(nvram get sdns_dualstack_ip_allow_force_aaaa)
sdns_force_aaaa_soa=$(nvram get sdns_force_aaaa_soa)
sdns_force_qtype_soa=$(nvram get sdns_force_qtype_soa)
sdns_prefetch_domain=$(nvram get sdns_prefetch_domain)
sdns_exp=$(nvram get sdns_exp)
sdns_exp_ttl=$(nvram get sdns_exp_ttl)
sdns_exp_ttl_max=$(nvram get sdns_exp_ttl_max)
sdns_exp_prefetch_time=$(nvram get sdns_exp_prefetch_time)
sdnse_enable=$(nvram get sdnse_enable)
sdnse_port=$(nvram get sdnse_port)
sdnse_tcp_server=$(nvram get sdnse_tcp_server)
sdnse_speed=$(nvram get sdnse_speed)
sdnse_name=$(nvram get sdnse_name)
sdnse_address=$(nvram get sdnse_address)
sdnse_ns=$(nvram get sdnse_ns)
sdns_ns=$(nvram get sdns_ns)
sdnse_ipset=$(nvram get sdnse_ipset)
sdnse_as=$(nvram get sdnse_as)
sdnse_ipv6_server=$(nvram get sdnse_ipv6_server)
sdnse_ipc=$(nvram get sdnse_ipc)
sdnse_cache=$(nvram get sdnse_cache)
sdns_adblock=$(nvram get sdns_adblock)
sdns_white=$(nvram get sdns_white)
sdns_black=$(nvram get sdns_black)
sdns_coredump=$(nvram get sdns_coredump)
sdns_log_level=$(nvram get sdns_log_level)
sdns_log_num=$(nvram get sdns_log_num)
sdns_dnsmasq_lease=$(nvram get sdns_dnsmasq_lease)
sdns_cache_checkpoint_time=$(nvram get sdns_cache_checkpoint_time)

adbyby_process=$(pidof adbyby | awk '{ print $1 }')
smartdns_process=$(pidof smartdns | awk '{ print $1 }')
IPS4="$(ifconfig br0 | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
IPS6="$(ifconfig br0 | grep "inet6 addr" | grep -v "fe80::" | grep -v "::1" | grep "Global" | awk '{print $3}')"
dnsmasq_md5=$(md5sum  "$dnsmasq_Conf" | awk '{ print $1 }')

# 函数

Read_ini () {
# 【读取上次成功启动时的端口等】
    if [ -s "$smartdns_Ini" ] ; then
        hosts_type=$(sed -n '1p' $smartdns_Ini)
        sdns_redirected=$(sed -n '2p' $smartdns_Ini)
        sdns_ported=$(sed -n '3p' $smartdns_Ini)
        sdnse_ported=$(sed -n '4p' $smartdns_Ini)
    else
        hosts_type=0
        sdns_redirected=0
        sdns_ported="$sdns_port"
        sdnse_ported="$sdnse_port"
    fi
}

Check_ss(){
    if [ -s /etc_ro/ss_ip.sh ] ; then
        if [ $(nvram get ss_enable) = 1 ] && [ $(nvram get ss_run_mode) = "router" ] && [ $(nvram get pdnsd_enable) = 0 ] ; then
            logger -t "smartdns" "检测到 SS 绕过大陆模式与 pdnsd 冲突，请改用手动配置模式，程序退出"
            nvram set sdns_enable=0
            exit 0
        fi
    fi
}

Get_sdns_conf () {
    # 【基本设置：服务名 + bind】
    :>"$smartdns_tmp_Conf"
    echo "server-name $sdns_name" >> "$smartdns_tmp_Conf"
    ARGS_1=""
    if [ "$sdns_address" = "1" ] ; then
        ARGS_1="$ARGS_1 -no-rule-addr"
    fi
    if [ "$sdns_ns" = "1" ] ; then
        ARGS_1="$ARGS_1 -no-rule-nameserver"
    fi
    if [ "$sdns_ipset" = "1" ] ; then
        ARGS_1="$ARGS_1 -no-rule-ipset"
    fi
    if [ "$sdns_speed" = "1" ] ; then
        ARGS_1="$ARGS_1 -no-speed-check"
    fi
    if [ "$sdns_as" = "1" ] ; then
        ARGS_1="$ARGS_1 -no-rule-soa"
    fi
    if [ "$sdns_ipv6_server" = "1" ] ; then
        echo "bind" "[::]:$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
    else
        echo "bind" ":$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_tcp_server" = "1" ] ; then
        if [ "$sdns_ipv6_server" = "1" ] ; then
            echo "bind-tcp" "[::]:$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
        else
            echo "bind-tcp" ":$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
        fi
    fi
    # 【第二服务器】
    Get_sdnse_conf
    # 【TCP 空闲】
    echo "tcp-idle-time $sdns_tcp_idle_time" >> "$smartdns_tmp_Conf"
    # 【缓存】
    echo "cache-size $sdns_cache" >> "$smartdns_tmp_Conf"
    if [ "$sdns_cache_persist" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "cache-persist yes" >> "$smartdns_tmp_Conf"
        echo "cache-file /tmp/smartdns.cache" >> "$smartdns_tmp_Conf"
    else
        echo "cache-persist no" >> "$smartdns_tmp_Conf"
    fi
    echo "cache-checkpoint-time $sdns_cache_checkpoint_time" >> "$smartdns_tmp_Conf"
    if [ "$sdns_prefetch_domain" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "prefetch-domain yes" >> "$smartdns_tmp_Conf"
    else
        echo "prefetch-domain no" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_exp" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "serve-expired yes" >> "$smartdns_tmp_Conf"
    else
        echo "serve-expired no" >> "$smartdns_tmp_Conf"
    fi
    echo "serve-expired-ttl $sdns_exp_ttl" >> "$smartdns_tmp_Conf"
    echo "serve-expired-reply-ttl $sdns_exp_ttl_max" >> "$smartdns_tmp_Conf"
    echo "serve-expired-prefetch-time $sdns_exp_prefetch_time" >> "$smartdns_tmp_Conf"
    # 【高级：测速 / SOA / 双栈】
    echo "speed-check-mode $sdns_speed_mode" >> "$smartdns_tmp_Conf"
    if [ "$sdns_force_aaaa_soa" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "force-AAAA-SOA yes" >> "$smartdns_tmp_Conf"
    else
        echo "force-AAAA-SOA no" >> "$smartdns_tmp_Conf"
    fi
    echo "force-qtype-SOA $sdns_force_qtype_soa" >> "$smartdns_tmp_Conf"
    if [ "$sdns_ip_change" -eq 1 ] ;then
        echo "dualstack-ip-selection-threshold $sdns_ip_change_time" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_dualstack_ip_allow_force_aaaa" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "dualstack-ip-allow-force-AAAA yes" >> "$smartdns_tmp_Conf"
    else
        echo "dualstack-ip-allow-force-AAAA no" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_ip_change" -eq 1 ] ;then
        echo "dualstack-ip-selection yes" >> "$smartdns_tmp_Conf"
    fi
    # 【TTL】
    echo "rr-ttl $sdns_rr_ttl" >> "$smartdns_tmp_Conf"
    echo "rr-ttl-min $sdns_rr_ttl_min" >> "$smartdns_tmp_Conf"
    echo "rr-ttl-max $sdns_rr_ttl_max" >> "$smartdns_tmp_Conf"
    echo "rr-ttl-reply-max $sdns_rr_ttl_reply_max" >> "$smartdns_tmp_Conf"
    echo "max-reply-ip-num $sdns_max_reply_ip_num" >> "$smartdns_tmp_Conf"
    # 【日志与租约】
    echo "log-level $sdns_log_level" >> "$smartdns_tmp_Conf"
    echo "log-num $sdns_log_num" >> "$smartdns_tmp_Conf"
    if [ "$sdns_dnsmasq_lease" = "1" ] ; then
        echo "dnsmasq-lease-file /tmp/dnsmasq.leases" >> "$smartdns_tmp_Conf"
    fi
    # 【上游服务器】
    listnum=$(nvram get sdns_staticnum_x)
    for i in $(seq 1 "$listnum")
    do
        j=$(expr "$i" - 1)
        sdnss_enable=$(nvram get sdnss_enable_x"$j")
        if  [ "$sdnss_enable" -eq 1 ] ; then
            sdnss_ip=$(nvram get sdnss_ip_x"$j")
            sdnss_port=$(nvram get sdnss_port_x"$j")
            sdnss_type=$(nvram get sdnss_type_x"$j")
            sdnss_named=$(nvram get sdnss_named_x"$j")
            sdnss_ipc=$(nvram get sdnss_ipc_x"$j")
            sdnss_ipset=$(nvram get sdnss_ipset_x"$j")
            sdnss_non=$(nvram get sdnss_non_x"$j")
            sdnss_extra=$(nvram get sdnss_extra_x"$j")
            ipc=""
            named=""
            non=""
            extra=""
            if [ "$sdnss_ipc" = "whitelist" ] ; then
                ipc=" -whitelist-ip"
            elif [ "$sdnss_ipc" = "blacklist" ] ; then
                ipc=" -blacklist-ip"
            fi
            if [ "$sdnss_named"x != x ] ; then
                named=" -group $sdnss_named"
            fi
            if [ "$sdnss_non" = "1" ] ; then
                non=" -exclude-default-group"
            fi
            if [ "$sdnss_extra"x != x ] ; then
                extra=" $sdnss_extra"
            fi
            if [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ] ; then
                port_suffix=""
            else
                port_suffix=":$sdnss_port"
            fi
            case "$sdnss_type" in
                tcp)   echo "server-tcp $sdnss_ip$port_suffix$ipc$named$non$extra" >> "$smartdns_tmp_Conf" ;;
                udp)   echo "server $sdnss_ip$port_suffix$ipc$named$non$extra" >> "$smartdns_tmp_Conf" ;;
                tls)   echo "server-tls $sdnss_ip$port_suffix$ipc$named$non$extra" >> "$smartdns_tmp_Conf" ;;
                https) echo "server-https $sdnss_ip$port_suffix$ipc$named$non$extra" >> "$smartdns_tmp_Conf" ;;
            esac
            if [ "$sdnss_ipset"x != x ] ; then
                Check_ip_addr "$sdnss_ipset"
                if [ "$?" = "1" ] ;then
                    echo "ipset /$sdnss_ipset/smartdns" >> "$smartdns_tmp_Conf"
                else
                    ipset add smartdns "$sdnss_ipset" -exist 2>/dev/null
                fi
            fi
        fi
    done
    # 【ipset 超时】
    if [ "$sdns_ipset_timeout" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "ipset-timeout yes" >> "$smartdns_tmp_Conf"
    else
        echo "ipset-timeout no" >> "$smartdns_tmp_Conf"
    fi
    # 【广告过滤 / 黑白名单】
    if [ "$sdns_adblock" -eq 1 ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] && [ -f /tmp/anti-ad-for-smartdns.conf ] ;then
        echo "conf-file /tmp/anti-ad-for-smartdns.conf" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_white" = "1" ] && [ -f "$chn_Route" ] ; then
        :>/tmp/whitelist.conf
        logger -t "smartdns" "正在根据 chnroute 生成白名单 IP 列表"
        awk '{printf("whitelist-ip %s\n", $1, $1 )}' "$chn_Route" >> /tmp/whitelist.conf
        echo "conf-file /tmp/whitelist.conf" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_black" = "1" ] && [ -f "$chn_Route" ] ; then
        :>/tmp/blacklist.conf
        logger -t "smartdns" "正在根据 chnroute 生成黑名单 IP 列表"
        awk '{printf("blacklist-ip %s\n", $1, $1 )}' "$chn_Route" >> /tmp/blacklist.conf
        echo "conf-file /tmp/blacklist.conf" >> "$smartdns_tmp_Conf"
    fi
}

Get_sdnse_conf () {
    # 【读取第二服务器设置】
    if [ "$sdnse_enable" -eq 1 ] ; then
        ARGS_2=""
        ADDR=""
        if [ "$sdnse_speed" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-speed-check"
        fi
        if [ -n "$sdnse_name" ] ; then
            ARGS_2="$ARGS_2 -group $sdnse_name"
        fi
        if [ "$sdnse_address" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-rule-addr"
        fi
        if [ "$sdnse_ns" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-rule-nameserver"
        fi
        if [ "$sdnse_ipset" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-rule-ipset"
        fi
        if [ "$sdnse_as" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-rule-soa"
        fi
        if [ "$sdnse_ipc" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-dualstack-selection"
        fi
        if [ "$sdnse_cache" = "1" ] ; then
            ARGS_2="$ARGS_2 -no-cache"
        fi
        if [ "$sdnse_ipv6_server" = "1" ] ; then
            ADDR="[::]"
        else
            ADDR=""
        fi
        echo "bind" "$ADDR:$sdnse_port$ARGS_2" >> "$smartdns_tmp_Conf"
        if [ "$sdnse_tcp_server" = "1" ] ; then
            echo "bind-tcp" "$ADDR:$sdnse_port$ARGS_2" >> "$smartdns_tmp_Conf"
        fi
    fi
}

Check_ip_addr () {
    echo "$1"|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" >/dev/null
    # IP地址必须为全数字
    if [ $? -ne 0 ] ; then
        return 1
    fi
    ipaddr=$1
    a=$(echo "$ipaddr"|awk -F . '{ print $1 }')  # 以"."分隔，取出每个列的值
    b=$(echo "$ipaddr"|awk -F . '{ print $2 }')
    c=$(echo "$ipaddr"|awk -F . '{ print $3 }')
    d=$(echo "$ipaddr"|awk -F . '{ print $4 }')
    for num in $a $b $c $d
    do
        if [ "$num" -gt 255 ] || [ "$num" -lt 0 ] ; then   # 每个数值必须在0-255之间
            return 1
        fi
    done
    return 0
}

Start_AD () {
# 【下载广告过滤文件】
    curl -s -o /tmp/sdnsadnew.conf --connect-timeout 10 --retry 3 $(nvram get sdns_adblock_url)
    if [ ! -f "/tmp/sdnsadnew.conf" ]; then
        logger -t "smartdns" "广告规则下载失败，请检查 URL 或网络连接"
    else
        logger -t "smartdns" "广告规则下载成功，已启用过滤功能"
        if [ -f "/tmp/sdnsadnew.conf" ]; then
            if grep -q "address=" /tmp/sdnsadnew.conf ; then
                cp /tmp/sdnsadnew.conf /tmp/anti-ad-for-smartdns.conf
            else
                cat /tmp/sdnsadnew.conf | grep ^\|\|[^\*]*\^$ | sed -e 's:||:address\=\/:' -e 's:\^:/0\.0\.0\.0:' > /tmp/anti-ad-for-smartdns.conf
            fi
        fi
    fi
    rm -f /tmp/sdnsadnew.conf
}

Change_adbyby () {
    # 【adbyby 去广告归属】
    adbyby_process=$(pidof adbyby | awk '{ print $1 }')
    if [ "$adbyby_process"x != x ] && [ $(nvram get adbyby_enable) = 1 ] ; then
        case $sdns_enable in
        0)
            if [ $(nvram get adbyby_add) = 1 ] && [ "$hosts_type" != "dnsmasq" ]; then
                nvram set adbyby_add=0
                /usr/bin/adbyby.sh switch
                logger -t "smartdns" "adbyby 去广告规则已切回 dnsmasq"
                hosts_type="dnsmasq"
            fi
            ;;
        1)
            if [ "$hosts_type" != "smartdns" ] && [ "$action" = "start" ] ; then
                if [ "$sdns_port" = "53" ] || [ $(nvram get adbyby_add) = 1 ] || [ "$sdns_redirect" = "2" ] ; then
                    nvram set adbyby_add=1
                    /usr/bin/adbyby.sh switch
                    logger -t "smartdns" "adbyby 去广告规则已切至 smartdns"
                    hosts_type="smartdns"
                fi
            fi
            ;;
        esac
    fi
}

Change_dnsmasq () {
    # 删除 DNSmasq 配置文件中的相关项，避免重复
    case $action in
    stop)
        sed -i '/no-resolv/d' "$dnsmasq_Conf"
        sed -i '/server=127.0.0.1#'"$sdns_ported"'/d' "$dnsmasq_Conf"
        sed -i '/port=0/d' "$dnsmasq_Conf"
        if [ "$sdns_enable" = 0 ] ; then
            [ "$_silent" != "1" ] && [ "$sdns_ported" = "53" ] && logger -t "smartdns" "已恢复 dnsmasq 为默认 DNS 解析服务" 
            [ "$_silent" != "1" ] && [ "$sdns_redirected" = "1" ] && logger -t "smartdns" "已移除 dnsmasq 上游指向 127.0.0.1:$sdns_ported" 
        fi
        ;;
    start)
        # 启动 SmartDNS 时：先清理旧条目，避免重复
        sed -i '/no-resolv/d' "$dnsmasq_Conf"
        sed -i '/server=127.0.0.1#/d' "$dnsmasq_Conf"
        sed -i '/port=0/d' "$dnsmasq_Conf"
        if [ "$sdns_port" = "53" ] ; then
            echo "port=0" >> "$dnsmasq_Conf"
            logger -t "smartdns" "占用 53 端口，已停用 dnsmasq DNS 服务"
            if [ "$sdns_redirect" = "1" ] ; then
                nvram set sdns_redirect=0
                sdns_redirect=0
                logger -t "smartdns" "端口 53 冲突，重定向已强制设为「无」" 
            fi
        fi
        if [ "$sdns_redirect" = "1" ] ; then
            echo "no-resolv" >> "$dnsmasq_Conf"
            echo "server=127.0.0.1#$sdns_port" >> "$dnsmasq_Conf"
            logger -t "smartdns" "dnsmasq 上游已指向 127.0.0.1:$sdns_port"
            if [ "$sdnse_enable" = 1 ] ; then
                logger -t "smartdns" "dnsmasq 第二上游已指向 127.0.0.1:$sdnse_port"
            fi
        fi
        ;;
    esac
}

Change_iptable () {
    # 【端口转发】
    local statu=0
    case $action in
    stop)
        if [ "$sdns_redirected" = 2 ] ; then
            iptables -t nat -D PREROUTING -p tcp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            iptables -t nat -D PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            ip6tables -t nat -D PREROUTING -p tcp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            ip6tables -t nat -D PREROUTING -p udp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            [ "$_silent" != "1" ] && [ "$sdns_enable" = 0 ] && logger -t "smartdns" "已删除 iptables 重定向规则（$IPS4:$sdns_ported → :53）"
        fi
        if [ "$sdns_redirected" = 1 ] ; then
            iptables -t nat -D PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1
        fi
        ;;
    start)
        if [ "$sdns_redirected" != 2 ] && [ "$sdns_redirect" = 2 ] ; then
            statu=1
            logger -t "smartdns" "正在添加 iptables 重定向：:53 → $IPS4:$sdns_port"
            if [ "$sdnse_enable" = 1 ] ; then
                logger -t "smartdns" "正在添加 iptables 重定向：:53 → $IPS4:$sdnse_port"
            fi
        fi
        ;;
    reset)
        if [ "$sdns_redirect" = 2 ] ; then
            statu=1
        fi
        if [ "$sdns_redirect" = 1 ] ; then
            iptables -t nat -A PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1
        fi
        ;;
    esac
    if [ "$statu" = 1 ] ; then
        [ "$sdns_tcp_server" = "1" ] && iptables -t nat -A PREROUTING -p tcp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        iptables -t nat -A PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        if [ "$sdns_ipv6_server" = "1" ] ; then
            [ "$sdns_tcp_server" = "1" ] && ip6tables -t nat -A PREROUTING -p tcp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
            ip6tables -t nat -A PREROUTING -p udp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        fi
    fi
}

Start_smartdns () {
    # 【启动主流程】
    :>"$smartdns_Ini"
    [ "$sdns_enable" -eq 0 ] && nvram set sdns_enable=1 && sdns_enable=1
    killall -TERM smartdns 2>/dev/null
    sleep 1
    killall -9 smartdns 2>/dev/null
    Change_dnsmasq
    Change_adbyby
    echo "$hosts_type" >> "$smartdns_Ini"
    if [ "$sdns_redirect" = 0 ] ; then
        logger -t "smartdns" "主服务监听端口：$sdns_port (TCP+UDP)"
        if [ "$sdnse_enable" = 1 ] ; then
            logger -t "smartdns" "第二服务监听端口：$sdnse_port (TCP+UDP)"
        fi
    fi
    Change_iptable
    sdns_redirected="$sdns_redirect"
    echo "$sdns_redirected" >> "$smartdns_Ini"
    echo "$sdns_port" >> "$smartdns_Ini"
    echo "$sdnse_port" >> "$smartdns_Ini"
    args=""
    logger -t "smartdns" "正在生成主配置文件：$smartdns_Conf"
    ipset -N smartdns hash:net -exist >/dev/null 2>&1
    Get_sdns_conf
    if [ -n "$(grep -v '^#' $smartdns_address_Conf 2>/dev/null | grep -v '^$')" ] ; then
        echo "# smartdns_address.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_address_Conf | grep -v "^$" >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_blacklist_Conf 2>/dev/null | grep -v '^$')" ] ; then
        echo "# smartdns_blacklist-ip.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_blacklist_Conf | grep -v "^$" >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_whitelist_Conf 2>/dev/null | grep -v '^$')" ] ; then
        echo "# smartdns_whitelist-ip.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_whitelist_Conf | grep -v "^$" >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_custom_Conf 2>/dev/null | grep -v '^$')" ] ; then
        echo "# smartdns_custom.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_custom_Conf | grep -v "^$" >> "$smartdns_tmp_Conf"
    fi
    sed -i '/my.router/d' "$smartdns_tmp_Conf"
    echo "# router built-in" >> "$smartdns_tmp_Conf"
    echo "domain-rules " "/my.router/ -c none -a $IPS4 -d no" >> "$smartdns_tmp_Conf"
    # 配置文件去重
    sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' "$smartdns_tmp_Conf" | grep -v '^$' | awk '!x[$0]++' > "$smartdns_Conf"
    rm -f "$smartdns_tmp_Conf"
    ln -sf "$smartdns_Conf" /tmp/smartdns.conf
    if [ "$sdns_coredump" = "1" ] ; then
        args="$args -S"
        mkdir -p "$smartdns_core_Path"
        chmod 700 "$smartdns_core_Path"
        rm -f "$smartdns_core_Path"/core "$smartdns_core_Path"/core.*
        ulimit -c 8192 >/dev/null 2>&1
        logger -t "smartdns" "coredump 将写入 $smartdns_core_Path/core（上限 4 MiB）"
    fi
    # 通过检测配置文件是否变化，确定是否重启 DNSmasq 进程
    if [ "$dnsmasq_md5" != $(md5sum  "$dnsmasq_Conf" | awk '{ print $1 }') ] ; then
        logger -t "smartdns" "检测到 dnsmasq 配置变更，正在重启服务"
        /sbin/restart_dhcpd >/dev/null 2>&1
        logger -t "smartdns" "dnsmasq 服务已重启完成"
    fi
    # 启动 smartdns 进程
    if [ "$sdns_coredump" = "1" ] ; then
        (cd "$smartdns_core_Path" && exec "$smartdns_Bin" -f -c "$smartdns_Conf" "$args") >/dev/null 2>&1 &
    else
        "$smartdns_Bin" -f -c "$smartdns_Conf" "$args"  &>/dev/null &
    fi
    sleep 1
    smartdns_process=$(pidof smartdns | awk '{ print $1 }')
    if [ "$smartdns_process"x = x ] ; then
        if [ "$hosts_type" = "smartdns" ] ; then
            logger -t "smartdns" "启动失败"
            logger -t "smartdns" "正在移除 conf-file 广告配置并重试"
            logger -t "smartdns" "若重试成功，请检查去广告规则格式"
            sed -i '/conf-file /d' "$smartdns_Conf"
            if [ "$sdns_coredump" = "1" ] ; then
                (cd "$smartdns_core_Path" && exec "$smartdns_Bin" -f -c "$smartdns_Conf" "$args") >/dev/null 2>&1 &
            else
                "$smartdns_Bin" -f -c "$smartdns_Conf" "$args"  &>/dev/null &
            fi
        fi
    fi
    sleep 1
    smartdns_process=$(pidof smartdns | awk '{ print $1 }')
    if [ "$smartdns_process"x = x ] ; then
        logger -t "smartdns" "二次启动失败"
        logger -t "smartdns" "已停用，请检查端口配置与自定义配置"
        logger -t "smartdns" "回退：dnsmasq 恢复 DNS 解析"
        nvram set sdns_enable=0
        sdns_enable=0
        action="stop"
        Stop_smartdns
        if [ "$dnsmasq_md5" != $(md5sum  "$dnsmasq_Conf" | awk '{ print $1 }') ] ; then
            logger -t "smartdns" "检测到 dnsmasq 配置变更，正在重启服务"
            /sbin/restart_dhcpd >/dev/null 2>&1
            logger -t "smartdns" "dnsmasq 服务已重启完成"
        fi
        exit
    else
        logger -t "smartdns" "进程启动成功 (PID: $smartdns_process)"
    fi
}

Stop_smartdns () {
    # 没进程 + 开关关 → 流程照走，日志静音
    _silent=0
    if [ -z "$(pidof smartdns)" ] && [ "$sdns_enable" = "0" ] ; then
        _silent=1
    fi
    smartdns_pid=$(pidof smartdns)
    killall -TERM smartdns 2>/dev/null
    sleep 1
    killall -9 smartdns 2>/dev/null
    [ "$_silent" != "1" ] && [ -n "$smartdns_pid" ] && logger -t "smartdns" "正在终止进程 (PID: $smartdns_pid)"
    Change_adbyby
    Change_dnsmasq
    Change_iptable
    if [ "$dnsmasq_md5" != $(md5sum  "$dnsmasq_Conf" | awk '{ print $1 }') ] && [ "$sdns_enable" = 0 ] ; then
        [ "$_silent" != "1" ] && logger -t "smartdns" "检测到 dnsmasq 配置变更，正在重启服务"
        /sbin/restart_dhcpd >/dev/null 2>&1
        [ "$_silent" != "1" ] && logger -t "smartdns" "dnsmasq 服务已重启完成"
    fi
    smartdns_process=$(pidof smartdns | awk '{ print $1 }')
    if [ "$smartdns_process"x = x ] && [ "$sdns_enable" = 0 ] ; then 
        rm  -f "$smartdns_Ini"
        [ "$_silent" != "1" ] && logger -t "smartdns" "服务已停用"
    fi
}

Main () {
# 【调用各子函数】
    case $action in
    start)
        if [ ! -s "$smartdns_Ini" ] ; then
            logger -t "smartdns" "正在启动服务"
        fi
        if [ $(nvram get adbyby_enable) = 1 ] ; then
            [ $(nvram get adbyby_add) = 1 ] && hosts_type="smartdns"
            [ $(nvram get adbyby_add) = 0 ] && hosts_type="dnsmasq"
        else
            hosts_type="0"
        fi
        Check_ss
        if [ $(nvram get sdns_adblock) = "1" ]; then
                Start_AD
        fi
        Start_smartdns
        logger -t "smartdns" "服务已启动 (PID: $smartdns_process)"
        sleep 2
        echo 3 > /proc/sys/vm/drop_caches
        ;;
    stop)
        smartdns_process=$(pidof smartdns | awk '{ print $1 }')
        if [ "$smartdns_process"x != x ] ; then
            case $sdns_enable in
            0)
                logger -t "smartdns" "正在停止服务"
                ;;
            1)
                logger -t "smartdns" "应用配置，正在重启服务"
                ;;
            esac
        fi
        Stop_smartdns
        sleep 2
        echo 3 > /proc/sys/vm/drop_caches
        ;;
    restart)
        if [ $(nvram get adbyby_enable) = 1 ] ; then
            [ $(nvram get adbyby_add) = 1 ] && hosts_type="smartdns"
            [ $(nvram get adbyby_add) = 0 ] && hosts_type="dnsmasq"
        else
            hosts_type="0"
        fi
        Check_ss
        Start_smartdns
        logger -t "smartdns" "服务已重启完成"
        sleep 2
        echo 3 > /proc/sys/vm/drop_caches
        ;;
    reset)
        [ "$sdns_enable" = "1" ] && Change_iptable
        ;;
    *)
        echo "check"
        ;;
    esac
}

Read_ini
Main