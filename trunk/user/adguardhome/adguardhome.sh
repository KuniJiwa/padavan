#!/bin/sh
ADG_BIN="AdGuardHome"
ADG_CONF="/etc/storage/adg.sh"
ADG_WORK="/tmp/AdGuardHome"
ADG_STORAGE="/etc/storage/AdGuardHome"
ADG_DNS_PORT="5335"
PID_FILE="/tmp/adguardhome.pid"

del_dns() {
    sed -i '/^no-resolv$/d' /etc/storage/dnsmasq/dnsmasq.conf
    sed -i "/^server=127.0.0.1#${ADG_DNS_PORT}$/d" /etc/storage/dnsmasq/dnsmasq.conf
    /sbin/restart_dhcpd
}

change_dns() {
    # 原版nvram判断完全保留
    if [ "$(nvram get adg_redirect)" = "1" ]; then
        del_dns
        cat >> /etc/storage/dnsmasq/dnsmasq.conf <<EOF
no-resolv
server=127.0.0.1#${ADG_DNS_PORT}
EOF
        /sbin/restart_dhcpd
        logger -t "AdGuardHome" "已添加DNS转发至${ADG_DNS_PORT}"
    fi
}

clear_iptable() {
    ip4_list=$(ip addr show | awk '/inet /&&!/127.0.0.1/{print $2}' | cut -d/ -f1)
    for lan_ip in $ip4_list; do
        iptables -t nat -D PREROUTING -p tcp -d "$lan_ip" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" 2>/dev/null
        iptables -t nat -D PREROUTING -p udp -d "$lan_ip" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" 2>/dev/null
    done

    if command -v ip6tables >/dev/null 2>&1; then
        ip6_list=$(ip -6 addr show | awk '/inet6 /&&!/^fe80::/&&!/::1/{print $2}' | cut -d/ -f1)
        for lan_ip6 in $ip6_list; do
            ip6tables -t nat -D PREROUTING -p tcp -d "$lan_ip6" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" 2>/dev/null
            ip6tables -t nat -D PREROUTING -p udp -d "$lan_ip6" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" 2>/dev/null
        done
    fi
}

set_iptable() {
    # 原版nvram判断完全保留
    if [ "$(nvram get adg_redirect)" = "2" ]; then
        clear_iptable
        ip4_list=$(ip addr show | awk '/inet /&&!/127.0.0.1/{print $2}' | cut -d/ -f1)
        for lan_ip in $ip4_list; do
            iptables -t nat -A PREROUTING -p tcp -d "$lan_ip" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" >/dev/null 2>&1
            iptables -t nat -A PREROUTING -p udp -d "$lan_ip" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" >/dev/null 2>&1
        done

        if command -v ip6tables >/dev/null 2>&1; then
            ip6_list=$(ip -6 addr show | awk '/inet6 /&&!/^fe80::/&&!/::1/{print $2}' | cut -d/ -f1)
            for lan_ip6 in $ip6_list; do
                ip6tables -t nat -A PREROUTING -p tcp -d "$lan_ip6" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" >/dev/null 2>&1
                ip6tables -t nat -A PREROUTING -p udp -d "$lan_ip6" --dport 53 -j REDIRECT --to-ports "${ADG_DNS_PORT}" >/dev/null 2>&1
            done
        fi
        logger -t "AdGuardHome" "已开启53端口全局转发至${ADG_DNS_PORT}"
    fi
}

getconfig(){
    if [ ! -f "${ADG_CONF}" ] || [ ! -s "${ADG_CONF}" ] ; then
        cat > "${ADG_CONF}" <<-\EEE
bind_host: 0.0.0.0
bind_port: 3030
auth_name: adguardhome
auth_pass: adguardhome
language: zh-cn
rlimit_nofile: 0
dns:
  bind_host: 0.0.0.0
  port: 5335
  protection_enabled: true
  filtering_enabled: true
  blocking_mode: nxdomain
  blocked_response_ttl: 10
  querylog_enabled: true
  ratelimit: 20
  ratelimit_whitelist: []
  refuse_any: true
  bootstrap_dns:
  - 223.5.5.5
  all_servers: true
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts: []
  parental_sensitivity: 0
  parental_enabled: false
  safesearch_enabled: false
  safebrowsing_enabled: false
  resolveraddress: ""
  upstream_dns:
  - 223.5.5.5
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  certificate_chain: ""
  private_key: ""
filters:
- enabled: true
  url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
  name: AdGuard Simplified Domain Names filter
  id: 1
- enabled: true
  url: https://adaway.org/hosts.txt
  name: AdAway
  id: 2
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  gateway_ip: ""
  subnet_mask: ""
  range_start: ""
  range_end: ""
  lease_duration: 86400
  icmp_timeout_msec: 1000
log_file: ""
verbose: false
schema_version: 3
EEE
        chmod 644 "${ADG_CONF}"
    fi
}

start_adg(){
    mkdir -p "${ADG_WORK}"
    mkdir -p "${ADG_STORAGE}"
    getconfig
    change_dns
    set_iptable

    if [ -f "${PID_FILE}" ]; then
        kill $(cat "${PID_FILE}") 2>/dev/null
        usleep 200000
        rm -f "${PID_FILE}"
    fi

    logger -t "AdGuardHome" "启动新版AdGuardHome，web资源内嵌内存运行"
    ${ADG_BIN} -c "${ADG_CONF}" -w "${ADG_WORK}" -v &
    echo $! > "${PID_FILE}"
}

stop_adg(){
    logger -t "AdGuardHome" "停止AdGuardHome，释放内存内嵌web资源"
    if [ -f "${PID_FILE}" ]; then
        kill $(cat "${PID_FILE}") 2>/dev/null
        usleep 500000
        rm -f "${PID_FILE}"
    fi
    killall "${ADG_BIN}" 2>/dev/null

    del_dns
    clear_iptable
    rm -rf "${ADG_WORK}"
}

case "$1" in
start)
    start_adg
    ;;
stop)
    stop_adg
    ;;
*)
    echo "Usage: $0 start|stop"
    ;;
esac
