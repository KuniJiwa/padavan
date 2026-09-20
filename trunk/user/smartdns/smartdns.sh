#!/bin/sh
# Copyright (C) 2018 Nick Peng (pymumu@gmail.com)
# Copyright (C) 2019 chongshengB (bkye@vip.qq.com)
# Copyright (C) 2022 TurBoTse (860018505@qq.com)
#
action="$1"
storage_path="/etc/storage"
smartdns_bin="/usr/bin/smartdns"
smartdns_core_path="/tmp/smartdns-core"
smartdns_ini="$storage_path/smartdns_conf.ini"
smartdns_conf="$storage_path/smartdns.conf"
smartdns_tmp_conf="$storage_path/smartdns_tmp.conf"
smartdns_address_conf="$storage_path/smartdns_address.conf"
smartdns_blacklist_conf="$storage_path/smartdns_blacklist-ip.conf"
smartdns_whitelist_conf="$storage_path/smartdns_whitelist-ip.conf"
smartdns_custom_conf="$storage_path/smartdns_custom.conf"
dnsmasq_conf="$storage_path/dnsmasq/dnsmasq.conf"
chn_route="$storage_path/chinadns/chnroute.txt"

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

IPS4="$(ifconfig br0 | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
IPS6="$(ifconfig br0 | grep "inet6 addr" | grep -v "fe80::" | grep -v "::1" | grep "Global" | awk '{print $3}')"
dnsmasq_md5=$(md5sum  "$dnsmasq_conf" | awk '{ print $1 }')

# 读取上次成功启动时的状态（hosts_type/redirect/port）
read_ini () {
    if [ -s "$smartdns_ini" ] ; then
        hosts_type=$(sed -n '1p' $smartdns_ini)
        sdns_redirected=$(sed -n '2p' $smartdns_ini)
        sdns_ported=$(sed -n '3p' $smartdns_ini)
        sdnse_ported=$(sed -n '4p' $smartdns_ini)
        IPS4_saved=$(sed -n '5p' $smartdns_ini)
        IPS6_saved=$(sed -n '6p' $smartdns_ini)
    else
        hosts_type=0
        sdns_redirected=0
        sdns_ported="$sdns_port"
        sdnse_ported="$sdnse_port"
        IPS4_saved=""
        IPS6_saved=""
    fi
}

# 基本设置
get_sdns_conf () {
    :>"$smartdns_tmp_conf"
    echo "server-name $sdns_name" >> "$smartdns_tmp_conf"
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
        echo "bind" "[::]:$sdns_port $ARGS_1" >> "$smartdns_tmp_conf"
    else
        echo "bind" ":$sdns_port $ARGS_1" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_tcp_server" = "1" ] ; then
        if [ "$sdns_ipv6_server" = "1" ] ; then
            echo "bind-tcp" "[::]:$sdns_port $ARGS_1" >> "$smartdns_tmp_conf"
        else
            echo "bind-tcp" ":$sdns_port $ARGS_1" >> "$smartdns_tmp_conf"
        fi
    fi
    echo "cache-size $sdns_cache" >> "$smartdns_tmp_conf"
    echo "rr-ttl $sdns_rr_ttl" >> "$smartdns_tmp_conf"
    echo "rr-ttl-min $sdns_rr_ttl_min" >> "$smartdns_tmp_conf"
    echo "rr-ttl-max $sdns_rr_ttl_max" >> "$smartdns_tmp_conf"
    echo "tcp-idle-time $sdns_tcp_idle_time" >> "$smartdns_tmp_conf"
    echo "rr-ttl-reply-max $sdns_rr_ttl_reply_max" >> "$smartdns_tmp_conf"
    echo "max-reply-ip-num $sdns_max_reply_ip_num" >> "$smartdns_tmp_conf"
    echo "serve-expired-ttl $sdns_exp_ttl" >> "$smartdns_tmp_conf"
    echo "serve-expired-reply-ttl $sdns_exp_ttl_max" >> "$smartdns_tmp_conf"
    echo "serve-expired-prefetch-time $sdns_exp_prefetch_time" >> "$smartdns_tmp_conf"
    echo "force-qtype-SOA $sdns_force_qtype_soa" >> "$smartdns_tmp_conf"
    echo "speed-check-mode $sdns_speed_mode" >> "$smartdns_tmp_conf"
    _rm=$(nvram get sdns_response_mode)
    [ -n "$_rm" ] && echo "response-mode $_rm" >> "$smartdns_tmp_conf"
    if [ "$sdns_ip_change" = "1" ] ;then
        echo "dualstack-ip-selection yes" >> "$smartdns_tmp_conf"
        echo "dualstack-ip-selection-threshold $sdns_ip_change_time" >> "$smartdns_tmp_conf"
    fi
    # force-AAAA-SOA 只在下文与 cache 条件一同处理，此处不重复输出
    if [ "$sdns_dualstack_ip_allow_force_aaaa" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "dualstack-ip-allow-force-AAAA yes" >> "$smartdns_tmp_conf"
    else
        echo "dualstack-ip-allow-force-AAAA no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_cache_persist" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "cache-persist yes" >> "$smartdns_tmp_conf"
        echo "cache-file /tmp/smartdns.cache" >> "$smartdns_tmp_conf"
    else
        echo "cache-persist no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_prefetch_domain" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "prefetch-domain yes" >> "$smartdns_tmp_conf"
    else
        echo "prefetch-domain no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_ipset_timeout" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "ipset-timeout yes" >> "$smartdns_tmp_conf"
    else
        echo "ipset-timeout no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_force_aaaa_soa" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "force-AAAA-SOA yes" >> "$smartdns_tmp_conf"
    else
        echo "force-AAAA-SOA no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_exp" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "serve-expired yes" >> "$smartdns_tmp_conf"
    else
        echo "serve-expired no" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_adblock" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] ;then
        echo "conf-file /tmp/anti-ad-for-smartdns.conf" >> "$smartdns_tmp_conf"
    fi
    echo "log-level error" >> "$smartdns_tmp_conf"
    listnum=$(nvram get sdns_staticnum_x)
    if [ -n "$listnum" ] && [ "$listnum" -gt 0 ] ; then
        for i in $(seq 1 "$listnum")
        do
            j=$(expr "$i" - 1)
            sdnss_enable=$(nvram get sdnss_enable_x"$j")
            if  [ "$sdnss_enable" = "1" ] ; then
                sdnss_ip=$(nvram get sdnss_ip_x"$j")
                sdnss_port=$(nvram get sdnss_port_x"$j")
                sdnss_type=$(nvram get sdnss_type_x"$j")
                sdnss_ipc=$(nvram get sdnss_ipc_x"$j")
                sdnss_named=$(nvram get sdnss_named_x"$j")
                sdnss_non=$(nvram get sdnss_non_x"$j")
                sdnss_ipset=$(nvram get sdnss_ipset_x"$j")
                ipc=""
                named=""
                non=""
                if [ "$sdnss_ipc" = "whitelist" ] ; then
                    ipc="-whitelist-ip"
                elif [ "$sdnss_ipc" = "blacklist" ] ; then
                    ipc="-blacklist-ip"
                fi
                if [ -n "$sdnss_named" ] ; then
                    named="-group $sdnss_named"
                fi
                if [ "$sdnss_non" = "1" ] ; then
                    non="-exclude-default-group"
                fi
                if [ "$sdnss_type" = "tcp" ] ; then
                    if { [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ]; } ; then
                        echo "server-tcp $sdnss_ip:53 $ipc $named $non" >> "$smartdns_tmp_conf"
                    else
                        echo "server-tcp $sdnss_ip:$sdnss_port $ipc $named $non" >> "$smartdns_tmp_conf"
                    fi
                elif [ "$sdnss_type" = "udp" ] ; then
                    if { [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ]; } ; then
                        echo "server $sdnss_ip:53 $ipc $named $non" >> "$smartdns_tmp_conf"
                    else
                        echo "server $sdnss_ip:$sdnss_port $ipc $named $non" >> "$smartdns_tmp_conf"
                    fi
                elif [ "$sdnss_type" = "tls" ] ; then
                    if { [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ]; } ; then
                        echo "server-tls $sdnss_ip:853 $ipc $named $non" >> "$smartdns_tmp_conf"
                    else
                        echo "server-tls $sdnss_ip:$sdnss_port $ipc $named $non" >> "$smartdns_tmp_conf"
                    fi
                elif [ "$sdnss_type" = "https" ] ; then
                    if { [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ]; } ; then
                        echo "server-https $sdnss_ip:443 $ipc $named $non" >> "$smartdns_tmp_conf"
                    else
                        echo "server-https $sdnss_ip:$sdnss_port $ipc $named $non" >> "$smartdns_tmp_conf"
                    fi
                fi
                if [ "$sdnss_ipset"x != x ] ; then
                    # 检测 IP 是否合规
                    check_ip_addr "$sdnss_ipset"
                    if [ "$?" = "0" ] ;then
                        ipset add smartdns "$sdnss_ipset" 2>/dev/null
                    else
                        echo "ipset /$sdnss_ipset/smartdns" >> "$smartdns_tmp_conf"
                    fi
                fi
            fi
        done
    fi
    if [ "$sdns_white" = "1" ] && [ -f "$chn_route" ] ; then
        :>/tmp/whitelist.conf
        logger -t "smartdns" "正在根据 chnroute 生成白名单 IP 列表..."
        awk '{printf("whitelist-ip %s\n", $1)}' "$chn_route" >> /tmp/whitelist.conf
        echo "conf-file /tmp/whitelist.conf" >> "$smartdns_tmp_conf"
    fi
    if [ "$sdns_black" = "1" ] && [ -f "$chn_route" ] ; then
        :>/tmp/blacklist.conf
        logger -t "smartdns" "正在根据 chnroute 生成黑名单 IP 列表..."
        awk '{printf("blacklist-ip %s\n", $1)}' "$chn_route" >> /tmp/blacklist.conf
        echo "conf-file /tmp/blacklist.conf" >> "$smartdns_tmp_conf"
    fi
}

# 第二服务器设置
get_sdnse_conf () {
    if [ "$sdnse_enable" = "1" ] ; then
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
        echo "bind" "$ADDR:$sdnse_port $ARGS_2" >> "$smartdns_tmp_conf"
        if [ "$sdnse_tcp_server" = "1" ] ; then
            echo "bind-tcp" "$ADDR:$sdnse_port $ARGS_2" >> "$smartdns_tmp_conf"
        fi
    fi
}

check_ss () {
    if [ -s /etc_ro/ss_ip.sh ] ; then
        if [ "$(nvram get ss_enable)" = "1" ] && [ "$(nvram get ss_run_mode)" = "router" ] && [ "$(nvram get pdnsd_enable)" = "0" ] ; then
            logger -t "smartdns" "检测到 SS 绕过大陆模式与 pdnsd 冲突，请改用手动配置模式，程序已退出"
            nvram set sdns_enable=0
            exit 0
        fi
    fi
}

# IP地址必须为全数字
check_ip_addr () {
    echo "$1"|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" >/dev/null
    if [ $? -ne 0 ] ; then
        return 1
    fi
    ipaddr=$1
    a=$(echo "$ipaddr"|awk -F . '{ print $1 }')  # 分割IP
    b=$(echo "$ipaddr"|awk -F . '{ print $2 }')
    c=$(echo "$ipaddr"|awk -F . '{ print $3 }')
    d=$(echo "$ipaddr"|awk -F . '{ print $4 }')
    for num in $a $b $c $d
    do
        if [ "$num" -gt 255 ] || [ "$num" -lt 0 ] ; then   # 每个数值0-255
            return 1
        fi
    done
    return 0
}

# 下载广告过滤文件
start_ad () {
    adblock_url=$(nvram get sdns_adblock_url)
    if [ -z "$adblock_url" ]; then
        logger -t "smartdns" "广告规则下载地址为空，跳过"
        return 0
    fi
    curl -s -o /tmp/sdnsadnew.conf --connect-timeout 10 --retry 3 "$adblock_url"
    if [ ! -f "/tmp/sdnsadnew.conf" ]; then
        logger -t "smartdns" "广告规则下载失败，请检查 URL 或网络连接"
    else
        logger -t "smartdns" "广告规则下载成功，已启用过滤功能"
        if [ -f "/tmp/sdnsadnew.conf" ]; then
            if grep -qw "address=" /tmp/sdnsadnew.conf ; then
                cp /tmp/sdnsadnew.conf /tmp/anti-ad-for-smartdns.conf
            else
                cat /tmp/sdnsadnew.conf | grep ^\|\|[^\*]*\^$ | sed -e 's:||:address\=\/:' -e 's:\^:/0\.0\.0\.0:' > /tmp/anti-ad-for-smartdns.conf
            fi
        fi
    fi
    rm -f /tmp/sdnsadnew.conf
}

# 切换 adbyby 去广告规则归属
change_adbyby () {
    adbyby_process=$(pidof adbyby | awk '{ print $1 }')
    if [ "$adbyby_process"x != x ] && [ "$(nvram get adbyby_enable)" = "1" ] ; then
        case $sdns_enable in
            0)
                if [ "$(nvram get adbyby_add)" = "1" ] && [ "$hosts_type" != "dnsmasq" ]; then
                    nvram set adbyby_add=0
                    /usr/bin/adbyby.sh switch
                    logger -t "smartdns" "adbyby 去广告规则已切回 dnsmasq"
                    hosts_type="dnsmasq"
                fi
                ;;
            1)
                if [ "$hosts_type" != "smartdns" ] && [ "$action" = "start" ] ; then
                    if [ "$sdns_port" = "53" ] || [ "$(nvram get adbyby_add)" = "1" ] || [ "$sdns_redirect" = "2" ] ; then
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

# 配置 dnsmasq（stop 时清理，start 时添加）
change_dnsmasq () {
    case $action in
        stop)
            sed -i '/no-resolv/d' "$dnsmasq_conf"
            sed -i '/server=127.0.0.1#'"$sdns_ported"'/d' "$dnsmasq_conf"
            sed -i '/port=0/d' "$dnsmasq_conf"
            if [ "$sdns_enable" = "0" ] ; then
                [ "$sdns_ported" = "53" ] && logger -t "smartdns" "已恢复 dnsmasq 为默认 DNS 解析服务"
                [ "$sdns_redirected" = "1" ] && logger -t "smartdns" "已移除 dnsmasq 上游指向 127.0.0.1:$sdns_ported"
            fi
            ;;
        start)
            # 启动 smartdns 时
            if [ "$sdns_port" = "53" ] ; then
                echo "port=0" >> "$dnsmasq_conf"
                logger -t "smartdns" "占用 53 端口，已停用 dnsmasq DNS 服务"
                if [ "$sdns_redirect" = "1" ] ; then
                    nvram set sdns_redirect=0
                    sdns_redirect=0
                    logger -t "smartdns" "检测到端口 53 冲突，重定向模式已强制设为「无」"
                fi
            fi
            if [ "$sdns_redirect" = "1" ] ; then
                echo "no-resolv" >> "$dnsmasq_conf"
                echo "server=127.0.0.1#$sdns_port" >> "$dnsmasq_conf"
                logger -t "smartdns" "dnsmasq 上游已指向 127.0.0.1:$sdns_port"
            fi
            ;;
    esac
}

# 检测 dnsmasq 配置变更，变化则重启
restart_dnsmasq_if_changed () {
    if [ "$dnsmasq_md5" != $(md5sum  "$dnsmasq_conf" | awk '{ print $1 }') ] ; then
        logger -t "smartdns" "检测到 dnsmasq 配置变更，正在重启服务..."
        /sbin/restart_dhcpd >/dev/null 2>&1 && logger -t "smartdns" "dnsmasq 服务已重启完成"
    fi
}

# 端口转发
change_iptable () {
    local statu=0
    case $action in
        stop)
            # 优先用 ini 里记录的上次 IP，为空时回退到当前 IP
            del_IPS4="${IPS4_saved:-$IPS4}"
            del_IPS6="${IPS6_saved:-$IPS6}"
            if [ "$sdns_redirected" = "2" ] ; then
                iptables -t nat -D PREROUTING -p tcp -d "$del_IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
                iptables -t nat -D PREROUTING -p udp -d "$del_IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
                ip6tables -t nat -D PREROUTING -p tcp -d "$del_IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
                ip6tables -t nat -D PREROUTING -p udp -d "$del_IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
                [ "$sdns_enable" = "0" ] && logger -t "smartdns" "已删除 iptables 重定向规则（端口 $sdns_ported → 53）"
            fi
            if [ "$sdns_redirected" = "1" ] ; then
                iptables -t nat -D PREROUTING -p udp -d "$del_IPS4" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1
            fi
            ;;
        start)
            if [ "$sdns_redirected" != "2" ] && [ "$sdns_redirect" = "2" ] ; then
                statu=1
                logger -t "smartdns" "正在添加 iptables 重定向：53 → $IPS4:$sdns_port"
            fi
            ;;
        reset)
            if [ "$sdns_redirect" = "2" ] ; then
                statu=1
            fi
            if [ "$sdns_redirect" = "1" ] ; then
                iptables -t nat -A PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports 53 >/dev/null 2>&1
            fi
            ;;
    esac
    if [ "$statu" = "1" ] ; then
        [ "$sdns_tcp_server" = "1" ] && iptables -t nat -A PREROUTING -p tcp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        iptables -t nat -A PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        if [ "$sdns_ipv6_server" = "1" ] ; then
            [ "$sdns_tcp_server" = "1" ] && ip6tables -t nat -A PREROUTING -p tcp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
            ip6tables -t nat -A PREROUTING -p udp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        fi
    fi
}

# 启动 smartdns 主流程
start_smartdns () {
    :>"$smartdns_ini"
    [ "$sdns_enable" = "0" ] && nvram set sdns_enable=1 && sdns_enable=1
    if pidof smartdns >/dev/null 2>&1; then
        kill -TERM $(pidof smartdns) 2>/dev/null
        sleep 1
        if pidof smartdns >/dev/null 2>&1; then
            kill -9 $(pidof smartdns) 2>/dev/null
        fi
    fi
    change_dnsmasq
    change_adbyby
    echo "$hosts_type" >> "$smartdns_ini"
    if [ "$sdns_redirect" = "0" ] ; then
        logger -t "smartdns" "主服务监听端口：$sdns_port (TCP+UDP)"
        if [ "$sdnse_enable" = "1" ] ; then
            logger -t "smartdns" "第二服务监听端口：$sdnse_port (TCP+UDP)"
        fi
    fi
    change_iptable
    sdns_redirected="$sdns_redirect"
    echo "$sdns_redirected" >> "$smartdns_ini"
    echo "$sdns_port" >> "$smartdns_ini"
    echo "$sdnse_port" >> "$smartdns_ini"
    echo "$IPS4" >> "$smartdns_ini"
    echo "$IPS6" >> "$smartdns_ini"
    args=""
    logger -t "smartdns" "正在生成主配置文件：$smartdns_conf"
    # ipset创建检测
    ipset list smartdns >/dev/null 2>&1 || ipset -N smartdns hash:net
    get_sdns_conf
    get_sdnse_conf
    grep -v '^#' $smartdns_address_conf | grep -v "^$" >> "$smartdns_tmp_conf"
    grep -v '^#' $smartdns_blacklist_conf | grep -v "^$" >> "$smartdns_tmp_conf"
    grep -v '^#' $smartdns_whitelist_conf | grep -v "^$" >> "$smartdns_tmp_conf"
    grep -v '^#' $smartdns_custom_conf | grep -v "^$" >> "$smartdns_tmp_conf"
    sed -i '/my.router/d' "$smartdns_tmp_conf"
    echo "domain-rules " "/my.router/ -c none -a $IPS4 -d no" >> "$smartdns_tmp_conf"
    # 配置文件去重
    awk '!x[$0]++' "$smartdns_tmp_conf" > "$smartdns_conf"
    rm -f "$smartdns_tmp_conf"
    if [ "$sdns_coredump" = "1" ] ; then
        args="$args -S"
        # 启用 coredump，默认 ulimit -c 0
        # 在前台运行并切换到可写 tmpfs，避免只读根目录下无法写入 core 文件
        # BusyBox 的 ulimit 以 512 字节为块单位，此处限制为 4 MiB，适配路由器 /tmp 低内存模式
        ulimit -c unlimited >/dev/null 2>&1
        mkdir -p "$smartdns_core_path"
        chmod 700 "$smartdns_core_path"
        rm -f "$smartdns_core_path"/core "$smartdns_core_path"/core.*
        ulimit -c 8192 >/dev/null 2>&1
        cd "$smartdns_core_path" || return 1
        logger -t "smartdns" "coredump 将写入 $smartdns_core_path/core（上限 4 MiB）"
    fi

    # 检测配置文件变化，重启 dnsmasq
    restart_dnsmasq_if_changed
    # 启动 smartdns 进程
    "$smartdns_bin" -f -c "$smartdns_conf" "$args"  &>/dev/null &
    sleep 1
    if ! pidof smartdns >/dev/null 2>&1 ; then
        if [ "$hosts_type" = "smartdns" ] ; then
            logger -t "smartdns" "启动失败，移除广告配置后重试"
            sed -i '/conf-file /d' "$smartdns_conf"
            "$smartdns_bin" -f -c "$smartdns_conf" "$args"  &>/dev/null &
        fi
    fi
    sleep 1
    if ! pidof smartdns >/dev/null 2>&1 ; then
        logger -t "smartdns" "二次启动失败，已停用并恢复 dnsmasq"
        nvram set sdns_enable=0
        sdns_enable=0
        action="stop"
        stop_smartdns
        restart_dnsmasq_if_changed
        exit
    else
        smartdns_process=$(pidof smartdns | awk '{ print $1 }')
        logger -t "smartdns" "进程启动成功 (PID: $smartdns_process)"
    fi
}

# 停止 smartdns 主流程
stop_smartdns () {
    if pidof smartdns >/dev/null 2>&1; then
        local old_pid=$(pidof smartdns)
        logger -t "smartdns" "正在终止进程 (PID: $old_pid)"
        kill -TERM $(pidof smartdns) 2>/dev/null
        sleep 1
        if pidof smartdns >/dev/null 2>&1; then
            kill -9 $(pidof smartdns) 2>/dev/null
            sleep 1
        fi
    fi
    change_adbyby
    change_dnsmasq
    change_iptable
    [ "$sdns_enable" = "0" ] && restart_dnsmasq_if_changed
    if ! pidof smartdns >/dev/null 2>&1 && [ "$sdns_enable" = "0" ] ; then
        rm  -f "$smartdns_ini"
        logger -t "smartdns" "服务已完全停止"
    fi
}

# 调用各子函数
main () {
    case $action in
        start)
            if [ ! -s "$smartdns_ini" ] ; then
                logger -t "smartdns" ">>> 启动流程开始"
            fi
            check_ss
            if [ "$(nvram get sdns_adblock)" = "1" ]; then
                start_ad
            fi
            start_smartdns
            logger -t "smartdns" "<<< 启动流程完成"
            sync && echo 1 > /proc/sys/vm/drop_caches
            ;;
        stop)
            if pidof smartdns >/dev/null 2>&1 ; then
                case $sdns_enable in
                    0)
                        logger -t "smartdns" "正在停止服务 ..."
                        ;;
                    1)
                        logger -t "smartdns" "应用配置，正在重启服务"
                        ;;
                esac
            fi
            stop_smartdns
            sync
            ;;
        restart)
            if [ "$(nvram get adbyby_enable)" = "1" ] ; then
                [ "$(nvram get adbyby_add)" = "1" ] && hosts_type="smartdns"
                [ "$(nvram get adbyby_add)" = "0" ] && hosts_type="dnsmasq"
            else
                hosts_type="0"
            fi
            check_ss
            start_smartdns
            logger -t "smartdns" "<<< 重启流程完成"
            sleep 2
            sync && echo 3 > /proc/sys/vm/drop_caches
            ;;
        reset)
            [ "$sdns_enable" = "1" ] && change_iptable
            ;;
        *)
            echo "check"
            ;;
    esac
}

read_ini
main
