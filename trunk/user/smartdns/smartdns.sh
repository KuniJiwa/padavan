#!/bin/sh
# Copyright (C) 2018 Nick Peng (pymumu@gmail.com)
# Copyright (C) 2019 chongshengB (bkye@vip.qq.com)
# Copyright (C) 2022 TurBoTse (860018505@qq.com)

action="$1"
storage_Path="/etc/storage"
smartdns_Bin="/usr/bin/smartdns"
smartdns_Conf="$storage_Path/smartdns.conf"
smartdns_tmp_Conf="$storage_Path/smartdns_tmp.conf"
smartdns_address_Conf="$storage_Path/smartdns_address.conf"
smartdns_blacklist_Conf="$storage_Path/smartdns_blacklist-ip.conf"
smartdns_whitelist_Conf="$storage_Path/smartdns_whitelist-ip.conf"
smartdns_custom_Conf="$storage_Path/smartdns_custom.conf"
dnsmasq_Conf="$storage_Path/dnsmasq/dnsmasq.conf"
chn_Route="$storage_Path/chinadns/chnroute.txt"
smartdns_core_Path="/tmp/smartdns-core"
PIDFILE="/var/run/smartdns.pid"
STATEFILE="/tmp/smartdns.state"

# 读取 nvram 配置
sdns_enable=$(nvram get sdns_enable)
sdns_name=$(nvram get sdns_name)
sdns_port=$(nvram get sdns_port)
sdns_tcp_server=$(nvram get sdns_tcp_server)
sdns_ipv6_server=$(nvram get sdns_ipv6_server)
sdns_redirect=$(nvram get sdns_redirect)
sdns_cache=$(nvram get sdns_cache)
sdns_cache_persist=$(nvram get sdns_cache_persist)
sdns_cache_checkpoint_time=$(nvram get sdns_cache_checkpoint_time)
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
sdns_ns=$(nvram get sdns_ns)
sdns_ip_change=$(nvram get sdns_ip_change)
sdns_ip_change_time=$(nvram get sdns_ip_change_time)
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
sdnse_as=$(nvram get sdnse_as)
sdnse_ipv6_server=$(nvram get sdnse_ipv6_server)
sdnse_ipset=$(nvram get sdnse_ipset)
sdnse_ipc=$(nvram get sdnse_ipc)
sdnse_cache=$(nvram get sdnse_cache)
sdns_adblock=$(nvram get sdns_adblock)
sdns_adblock_url=$(nvram get sdns_adblock_url)
sdns_white=$(nvram get sdns_white)
sdns_black=$(nvram get sdns_black)
sdns_coredump=$(nvram get sdns_coredump)
sdns_log_level=$(nvram get sdns_log_level)
sdns_log_num=$(nvram get sdns_log_num)
sdns_log_size=$(nvram get sdns_log_size)
sdns_dnsmasq_lease=$(nvram get sdns_dnsmasq_lease)

adbyby_process=$(pidof adbyby | awk '{print $1}')
IPS4="$(ifconfig br0 2>/dev/null | grep "inet addr" | grep -v ":127" | grep "Bcast" | awk '{print $2}' | awk -F : '{print $2}')"
IPS6="$(ifconfig br0 2>/dev/null | grep "inet6 addr" | grep -v "fe80::" | grep -v "::1" | grep "Global" | awk '{print $3}')"

emit() {
    [ -n "$2" ] && echo "$1 $2" >> "$smartdns_tmp_Conf"
}

# 运行时状态
Read_state () {
    if [ -s "$STATEFILE" ]; then
        hosts_type=$(sed -n '1p' "$STATEFILE")
        sdns_redirected=$(sed -n '2p' "$STATEFILE")
        sdns_ported=$(sed -n '3p' "$STATEFILE")
    else
        hosts_type=0
        sdns_redirected=0
        sdns_ported="$sdns_port"
    fi
}

Write_state () {
    :>"$STATEFILE"
    echo "$hosts_type"      >> "$STATEFILE"
    echo "$sdns_redirected" >> "$STATEFILE"
    echo "$sdns_port"       >> "$STATEFILE"
}

Check_ss () {
    if [ -s /etc_ro/ss_ip.sh ]; then
        if [ "$(nvram get ss_enable)" = "1" ] && [ "$(nvram get ss_run_mode)" = "router" ] && [ "$(nvram get pdnsd_enable)" = "0" ]; then
            logger -t smartdns "检测到 SS 绕过大陆模式与 pdnsd 冲突，已停用，请改用手动配置模式"
            nvram set sdns_enable=0
            exit 0
        fi
    fi
}

Check_ip_addr () {
    echo "$1" | grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" >/dev/null
    [ $? -ne 0 ] && return 1
    local ipaddr=$1
    local a=$(echo "$ipaddr" | awk -F . '{print $1}')
    local b=$(echo "$ipaddr" | awk -F . '{print $2}')
    local c=$(echo "$ipaddr" | awk -F . '{print $3}')
    local d=$(echo "$ipaddr" | awk -F . '{print $4}')
    for num in $a $b $c $d; do
        if [ "$num" -gt 255 ] || [ "$num" -lt 0 ]; then
            return 1
        fi
    done
    return 0
}

Wait_pidfile () {
    local max="$1"
    local i=0
    while [ $i -lt "$max" ]; do
        if [ -f "$PIDFILE" ]; then
            local p=$(cat "$PIDFILE" 2>/dev/null)
            if [ -n "$p" ] && [ -d "/proc/$p" ]; then
                return 0
            fi
        fi
        i=$((i+1))
        sleep 1
    done
    return 1
}

Wait_stop () {
    local pid="$1"
    local max="$2"
    local i=0
    while [ -d "/proc/$pid" ] && [ $i -lt "$max" ]; do
        i=$((i+1))
        sleep 1
    done
    [ -d "/proc/$pid" ] && return 1
    return 0
}

# 生成 smartdns 配置
Get_sdnse_conf () {
    [ "$sdnse_enable" = "1" ] || return
    local ARGS_2="" ADDR=""
    [ "$sdnse_speed" = "1" ]     && ARGS_2="$ARGS_2 -no-speed-check"
    [ -n "$sdnse_name" ]         && ARGS_2="$ARGS_2 -group $sdnse_name"
    [ "$sdnse_address" = "1" ]   && ARGS_2="$ARGS_2 -no-rule-addr"
    [ "$sdnse_ns" = "1" ]        && ARGS_2="$ARGS_2 -no-rule-nameserver"
    [ "$sdnse_ipset" = "1" ]     && ARGS_2="$ARGS_2 -no-rule-ipset"
    [ "$sdnse_as" = "1" ]        && ARGS_2="$ARGS_2 -no-rule-soa"
    [ "$sdnse_ipc" = "1" ]       && ARGS_2="$ARGS_2 -no-dualstack-selection"
    [ "$sdnse_cache" = "1" ]     && ARGS_2="$ARGS_2 -no-cache"
    [ "$sdnse_ipv6_server" = "1" ] && ADDR="[::]"
    echo "bind $ADDR:$sdnse_port$ARGS_2" >> "$smartdns_tmp_Conf"
    [ "$sdnse_tcp_server" = "1" ] && echo "bind-tcp $ADDR:$sdnse_port$ARGS_2" >> "$smartdns_tmp_Conf"
}

Get_sdns_conf () {
    :>"$smartdns_tmp_Conf"
    emit "server-name" "$sdns_name"

    local ARGS_1=""
    [ "$sdns_address" = "1" ] && ARGS_1="$ARGS_1 -no-rule-addr"
    [ "$sdns_ns" = "1" ]      && ARGS_1="$ARGS_1 -no-rule-nameserver"
    [ "$sdns_ipset" = "1" ]   && ARGS_1="$ARGS_1 -no-rule-ipset"
    [ "$sdns_speed" = "1" ]   && ARGS_1="$ARGS_1 -no-speed-check"
    [ "$sdns_as" = "1" ]      && ARGS_1="$ARGS_1 -no-rule-soa"

    if [ "$sdns_ipv6_server" = "1" ]; then
        echo "bind [::]:$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
    else
        echo "bind :$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_tcp_server" = "1" ]; then
        if [ "$sdns_ipv6_server" = "1" ]; then
            echo "bind-tcp [::]:$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
        else
            echo "bind-tcp :$sdns_port$ARGS_1" >> "$smartdns_tmp_Conf"
        fi
    fi

    Get_sdnse_conf

    emit "tcp-idle-time" "$sdns_tcp_idle_time"
    emit "cache-size" "$sdns_cache"
    if [ "$sdns_cache_persist" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ]; then
        emit "cache-persist" "yes"
        emit "cache-file" "/tmp/smartdns.cache"
    else
        emit "cache-persist" "no"
    fi
    emit "cache-checkpoint-time" "$sdns_cache_checkpoint_time"
    if [ "$sdns_prefetch_domain" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ]; then
        emit "prefetch-domain" "yes"
    else
        emit "prefetch-domain" "no"
    fi
    if [ "$sdns_exp" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ]; then
        emit "serve-expired" "yes"
    else
        emit "serve-expired" "no"
    fi
    emit "serve-expired-ttl" "$sdns_exp_ttl"
    emit "serve-expired-reply-ttl" "$sdns_exp_ttl_max"
    emit "serve-expired-prefetch-time" "$sdns_exp_prefetch_time"
    emit "speed-check-mode" "$sdns_speed_mode"
    emit "force-qtype-SOA" "$sdns_force_qtype_soa"
    if [ "$sdns_ip_change" = "1" ]; then
        emit "dualstack-ip-selection" "yes"
        emit "dualstack-ip-selection-threshold" "$sdns_ip_change_time"
    else
        emit "dualstack-ip-selection" "no"
    fi
    emit "rr-ttl" "$sdns_rr_ttl"
    emit "rr-ttl-min" "$sdns_rr_ttl_min"
    emit "rr-ttl-max" "$sdns_rr_ttl_max"
    emit "rr-ttl-reply-max" "$sdns_rr_ttl_reply_max"
    emit "max-reply-ip-num" "$sdns_max_reply_ip_num"
    emit "log-level" "$sdns_log_level"
    emit "log-num" "$sdns_log_num"
    emit "log-size" "$sdns_log_size"
    [ "$sdns_dnsmasq_lease" = "1" ] && echo "dnsmasq-lease-file /tmp/dnsmasq.leases" >> "$smartdns_tmp_Conf"

    local listnum=$(nvram get sdns_staticnum_x)
    [ -z "$listnum" ] && listnum=0
    local i=1
    while [ $i -le "$listnum" ]; do
        local j=$((i - 1))
        if [ "$(nvram get sdnss_enable_x$j)" = "1" ]; then
            local sdnss_ip=$(nvram get sdnss_ip_x$j)
            local sdnss_port=$(nvram get sdnss_port_x$j)
            local sdnss_type=$(nvram get sdnss_type_x$j)
            local sdnss_named=$(nvram get sdnss_named_x$j)
            local sdnss_ipc=$(nvram get sdnss_ipc_x$j)
            local sdnss_ipset=$(nvram get sdnss_ipset_x$j)
            local sdnss_non=$(nvram get sdnss_non_x$j)
            local sdnss_extra=$(nvram get sdnss_extra_x$j)
            local ipc="" named="" non="" extra="" port_suffix=""
            [ "$sdnss_ipc" = "whitelist" ] && ipc=" -whitelist-ip"
            [ "$sdnss_ipc" = "blacklist" ] && ipc=" -blacklist-ip"
            [ -n "$sdnss_named" ] && named=" -group $sdnss_named"
            [ "$sdnss_non" = "1" ] && non=" -exclude-default-group"
            [ -n "$sdnss_extra" ] && extra=" $sdnss_extra"
            if [ -z "$sdnss_port" ] || [ "$sdnss_port" = "default" ]; then
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
            if [ -n "$sdnss_ipset" ]; then
                Check_ip_addr "$sdnss_ipset"
                if [ $? -eq 1 ]; then
                    echo "ipset /$sdnss_ipset/smartdns" >> "$smartdns_tmp_Conf"
                else
                    ipset add smartdns "$sdnss_ipset" -exist 2>/dev/null
                fi
            fi
        fi
        i=$((i+1))
    done

    if [ "$sdns_ipset_timeout" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ]; then
        emit "ipset-timeout" "yes"
    else
        emit "ipset-timeout" "no"
    fi

    if [ "$sdns_adblock" = "1" ] && [ -n "$sdns_cache" ] && [ "$sdns_cache" -gt 0 ] && [ -f /tmp/anti-ad-for-smartdns.conf ]; then
        echo "conf-file /tmp/anti-ad-for-smartdns.conf" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_white" = "1" ] && [ -f "$chn_Route" ]; then
        :>/tmp/whitelist.conf
        logger -t smartdns "正在根据 chnroute 生成白名单 IP 列表，写入 /tmp/whitelist.conf"
        awk '{printf("whitelist-ip %s\n", $1)}' "$chn_Route" >> /tmp/whitelist.conf
        echo "conf-file /tmp/whitelist.conf" >> "$smartdns_tmp_Conf"
    fi
    if [ "$sdns_black" = "1" ] && [ -f "$chn_Route" ]; then
        :>/tmp/blacklist.conf
        logger -t smartdns "正在根据 chnroute 生成黑名单 IP 列表，写入 /tmp/blacklist.conf"
        awk '{printf("blacklist-ip %s\n", $1)}' "$chn_Route" >> /tmp/blacklist.conf
        echo "conf-file /tmp/blacklist.conf" >> "$smartdns_tmp_Conf"
    fi

    if [ -n "$(grep -v '^#' $smartdns_address_Conf 2>/dev/null | grep -v '^$')" ]; then
        echo "# smartdns_address.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_address_Conf | grep -v '^$' >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_blacklist_Conf 2>/dev/null | grep -v '^$')" ]; then
        echo "# smartdns_blacklist-ip.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_blacklist_Conf | grep -v '^$' >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_whitelist_Conf 2>/dev/null | grep -v '^$')" ]; then
        echo "# smartdns_whitelist-ip.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_whitelist_Conf | grep -v '^$' >> "$smartdns_tmp_Conf"
    fi
    if [ -n "$(grep -v '^#' $smartdns_custom_Conf 2>/dev/null | grep -v '^$')" ]; then
        echo "# smartdns_custom.conf" >> "$smartdns_tmp_Conf"
        grep -v '^#' $smartdns_custom_Conf | grep -v '^$' >> "$smartdns_tmp_Conf"
    fi

    sed -i '/my.router/d' "$smartdns_tmp_Conf"
    echo "# router built-in" >> "$smartdns_tmp_Conf"
    echo "domain-rules /my.router/ -c none -a $IPS4 -d no" >> "$smartdns_tmp_Conf"

    sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//' "$smartdns_tmp_Conf" | grep -v '^$' | awk '!x[$0]++' > "$smartdns_Conf"
    rm -f "$smartdns_tmp_Conf"
    ln -sf "$smartdns_Conf" /tmp/smartdns.conf
    logger -t smartdns "配置文件已生成：$smartdns_Conf"
}

# 联动 dnsmasq / iptables / adbyby
Start_AD () {
    curl -s -o /tmp/sdnsadnew.conf --connect-timeout 10 --retry 3 "$sdns_adblock_url"
    if [ ! -f /tmp/sdnsadnew.conf ]; then
        logger -t smartdns "广告规则下载失败：$sdns_adblock_url，请检查 URL 或网络连接"
    else
        logger -t smartdns "广告规则下载成功，规则文件已保存，服务启动时生效"
        if grep -q "address=" /tmp/sdnsadnew.conf; then
            cp /tmp/sdnsadnew.conf /tmp/anti-ad-for-smartdns.conf
        else
            cat /tmp/sdnsadnew.conf | grep '^||[^\*]*\^$' | sed -e 's:||:address\=\/:' -e 's:\^:/0\.0\.0\.0:' > /tmp/anti-ad-for-smartdns.conf
        fi
    fi
    rm -f /tmp/sdnsadnew.conf
}

Change_adbyby () {
    adbyby_process=$(pidof adbyby | awk '{print $1}')
    if [ -n "$adbyby_process" ] && [ "$(nvram get adbyby_enable)" = "1" ]; then
        case "$sdns_enable" in
        0)
            if [ "$(nvram get adbyby_add)" = "1" ] && [ "$hosts_type" != "dnsmasq" ]; then
                nvram set adbyby_add=0
                /usr/bin/adbyby.sh switch
                logger -t smartdns "adbyby 去广告规则已切回 dnsmasq"
                hosts_type="dnsmasq"
            fi
            ;;
        1)
            if [ "$hosts_type" != "smartdns" ] && [ "$action" = "start" ]; then
                if [ "$sdns_port" = "53" ] || [ "$(nvram get adbyby_add)" = "1" ] || [ "$sdns_redirect" = "2" ]; then
                    nvram set adbyby_add=1
                    /usr/bin/adbyby.sh switch
                    logger -t smartdns "adbyby 去广告规则已切至 smartdns"
                    hosts_type="smartdns"
                fi
            fi
            ;;
        esac
    fi
}

Change_dnsmasq () {
    local _before=$(md5sum "$dnsmasq_Conf" 2>/dev/null | awk '{print $1}')
    case "$action" in
    stop)
        if [ "$sdns_enable" = "0" ]; then
            sed -i '/no-resolv/d' "$dnsmasq_Conf"
            sed -i '/server=127.0.0.1#/d' "$dnsmasq_Conf"
            sed -i '/port=0/d' "$dnsmasq_Conf"
        fi
        ;;
    start)
        # 53 端口下重定向模式（1/2）无效，强制纠正为 0
        if [ "$sdns_port" = "53" ] && [ "$sdns_redirect" != "0" ]; then
            nvram set sdns_redirect=0
            sdns_redirect=0
            logger -t smartdns "监听 53 端口时重定向模式无效，已强制设为「无」。如需该模式，请将监听端口改为非 53"
        fi

        local _eff_redirect="$sdns_redirect"
        local _need=0
        if [ "$sdns_port" = "53" ]; then
            grep -qxF 'port=0' "$dnsmasq_Conf" || _need=1
        else
            grep -qxF 'port=0' "$dnsmasq_Conf" && _need=1
        fi
        if [ "$_eff_redirect" = "1" ]; then
            grep -qxF 'no-resolv' "$dnsmasq_Conf" || _need=1
            grep -qxF "server=127.0.0.1#$sdns_port" "$dnsmasq_Conf" || _need=1
        else
            grep -qxF 'no-resolv' "$dnsmasq_Conf" && _need=1
            grep -q '^server=127.0.0.1#' "$dnsmasq_Conf" && _need=1
        fi
        if [ "$_need" = "1" ]; then
            sed -i '/no-resolv/d' "$dnsmasq_Conf"
            sed -i '/server=127.0.0.1#/d' "$dnsmasq_Conf"
            sed -i '/port=0/d' "$dnsmasq_Conf"
            if [ "$sdns_port" = "53" ]; then
                echo "port=0" >> "$dnsmasq_Conf"
                logger -t smartdns "53 端口被占用，已停用 dnsmasq DNS 服务"
            fi
            if [ "$sdns_redirect" = "1" ]; then
                echo "no-resolv" >> "$dnsmasq_Conf"
                echo "server=127.0.0.1#$sdns_port" >> "$dnsmasq_Conf"
                logger -t smartdns "dnsmasq 上游已指向 127.0.0.1:$sdns_port，DNS 查询将转发至 smartdns"
            fi
        fi
        ;;
    esac
    local _after=$(md5sum "$dnsmasq_Conf" 2>/dev/null | awk '{print $1}')
    if [ "$_before" != "$_after" ]; then
        _dnsmasq_changed=1
    else
        _dnsmasq_changed=0
    fi
}

Change_iptable () {
    local statu=0
    case "$action" in
    stop)
        if [ "$sdns_redirected" = "2" ]; then
            iptables  -t nat -D PREROUTING -p tcp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            iptables  -t nat -D PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            ip6tables -t nat -D PREROUTING -p tcp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            ip6tables -t nat -D PREROUTING -p udp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_ported" >/dev/null 2>&1
            [ "$sdns_enable" = "0" ] && logger -t smartdns "已删除 iptables 和 ip6tables 重定向规则"
        fi
        ;;
    start)
        if [ "$sdns_port" != "53" ] && [ "$sdns_redirected" != "2" ] && [ "$sdns_redirect" = "2" ]; then
            statu=1
            logger -t smartdns "正在添加 iptables 重定向：$IPS4:53 转发至本机 $sdns_port"
        fi
        ;;
    esac
    if [ "$statu" = "1" ]; then
        [ "$sdns_tcp_server" = "1" ] && iptables -t nat -A PREROUTING -p tcp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        iptables -t nat -A PREROUTING -p udp -d "$IPS4" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        if [ "$sdns_ipv6_server" = "1" ]; then
            [ "$sdns_tcp_server" = "1" ] && ip6tables -t nat -A PREROUTING -p tcp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
            ip6tables -t nat -A PREROUTING -p udp -d "$IPS6" --dport 53 -j REDIRECT --to-ports "$sdns_port" >/dev/null 2>&1
        fi
    fi
}

# 进程启停
Start_smartdns () {
    action="start"
    [ "$sdns_enable" = "0" ] && nvram set sdns_enable=1 && sdns_enable=1

    if [ -f "$PIDFILE" ]; then
        local oldpid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$oldpid" ] && [ -d "/proc/$oldpid" ]; then
            kill -TERM "$oldpid" 2>/dev/null
            if ! Wait_stop "$oldpid" 5; then
                kill -9 "$oldpid" 2>/dev/null
            fi
        fi
        rm -f "$PIDFILE"
    fi
    killall -9 smartdns >/dev/null 2>&1

    Change_dnsmasq
    Change_adbyby

    # dnsmasq 配置变更立即重启，释放 53 端口 / 让上游指向生效
    if [ "$_dnsmasq_changed" = "1" ]; then
        /sbin/restart_dhcpd >/dev/null 2>&1
    fi

    logger -t smartdns "主服务监听端口：$sdns_port，TCP=$sdns_tcp_server，IPv6=$sdns_ipv6_server"
    [ "$sdnse_enable" = "1" ] && logger -t smartdns "第二服务监听端口：$sdnse_port，TCP=$sdnse_tcp_server，IPv6=$sdnse_ipv6_server"

    Change_iptable
    sdns_redirected="$sdns_redirect"
    Get_sdns_conf
    ipset -N smartdns hash:net -exist >/dev/null 2>&1

    local extra_args=""
    if [ "$sdns_coredump" = "1" ]; then
        mkdir -p "$smartdns_core_Path"
        chmod 700 "$smartdns_core_Path"
        rm -f "$smartdns_core_Path"/core "$smartdns_core_Path"/core.*
        ulimit -c 8192
        logger -t smartdns "已启用 coredump（上限 4 MiB，-S 参数由内核生成 core）"
        extra_args="-S"
    fi

    $smartdns_Bin -R -c "$smartdns_Conf" -p "$PIDFILE" $extra_args

    if ! Wait_pidfile 6; then
        logger -t smartdns "启动失败，PID 文件未生成，已回退 dnsmasq"
        nvram set sdns_enable=0
        sdns_enable=0
        action="stop"
        Stop_smartdns
        exit 1
    fi

    logger -t "smartdns[$(cat $PIDFILE)]" "服务已启动，配置加载完成"


    Write_state
}

Stop_smartdns () {
    action="stop"
    local pid=""
    if [ -f "$PIDFILE" ]; then
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && [ -d "/proc/$pid" ]; then
            kill -TERM "$pid" 2>/dev/null
            if ! Wait_stop "$pid" 6; then
                kill -9 "$pid" 2>/dev/null
            fi
        fi
        rm -f "$PIDFILE"
    fi

    Change_adbyby
    Change_dnsmasq
    Change_iptable

    if [ "$_dnsmasq_changed" = "1" ] && [ "$sdns_enable" = "0" ]; then
        logger -t smartdns "已恢复 dnsmasq 默认 DNS 解析"
        /sbin/restart_dhcpd >/dev/null 2>&1
    fi

    rm -f "$STATEFILE"

    if [ "$sdns_enable" = "0" ]; then
        if [ -n "$pid" ]; then
            logger -t "smartdns[$pid]" "服务已停止"
        else
            logger -t smartdns "服务已停止"
        fi
    fi
}

Main () {
    case "$action" in
    start)
        logger -t smartdns "正在启动服务，生成运行配置"
        if [ "$(nvram get adbyby_enable)" = "1" ]; then
            [ "$(nvram get adbyby_add)" = "1" ] && hosts_type="smartdns"
            [ "$(nvram get adbyby_add)" = "0" ] && hosts_type="dnsmasq"
        else
            hosts_type="0"
        fi
        Check_ss
        [ "$(nvram get sdns_adblock)" = "1" ] && Start_AD
        Start_smartdns
        sleep 2
        echo 3 > /proc/sys/vm/drop_caches
        ;;
    stop)
        Stop_smartdns
        ;;
    restart)
        if [ "$(nvram get adbyby_enable)" = "1" ]; then
            [ "$(nvram get adbyby_add)" = "1" ] && hosts_type="smartdns"
            [ "$(nvram get adbyby_add)" = "0" ] && hosts_type="dnsmasq"
        else
            hosts_type="0"
        fi
        Check_ss
        logger -t smartdns "正在重启服务，重载最新配置"
        [ "$(nvram get sdns_adblock)" = "1" ] && Start_AD
        Stop_smartdns
        Start_smartdns
        logger -t smartdns "服务已重启完成，DNS 解析已恢复"
        sleep 2
        echo 3 > /proc/sys/vm/drop_caches
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 2
        ;;
    esac
}

Read_state
Main
