#!/usr/bin/env python3
# gen_config.py - Apply user config to firmware templates
#
# Rules:
#   1. Input is comma-separated plugin names
#   2. Prefix "-" means disable (set to n)
#   3. Unlisted plugins stay at template default
#   4. Blacklisted plugins are never modified
#   5. Unknown plugin names are silently skipped
#   6. Case-insensitive, Chinese punctuation auto-normalized
#   7. Nano mode force-disables a batch of modules
#   8. Print changelog after change
#   9. LAN IP / account / WiFi applied to defaults.h + CN.dict
#      (anchor by macro name, empty value = keep source default)
#  10. customization is a comma string:
#      lanip,signaccount,signpassword,wifi2gssid,wifi2gpsk,wifi5gssid,wifi5gpsk
#      Any empty field or wrong count -> fall back to default
#
# Usage:
#   python3 gen_config.py --config <path> --plugins "xray,-smartdns"
#                         [--customization "192.168.2.1,admin,admin,Padavan,1234567890,Padavan-5G,1234567890"]
#                         [--nano true] [--oc true] [--oc-value 0x362]

import argparse
import os
import re
import sys

# Network config file paths (fixed, matches yml)
DEFAULTS_H = 'trunk/user/shared/src/defaults.h'
CN_DICT = 'trunk/user/www/dict/CN.dict'

# Keys written to GITHUB_ENV (for release body)
ENV_KEYS = ['LANIP', 'SIGNACCOUNT', 'SIGNPASSWORD',
            'WIFI2GSSID', 'WIFI2GPSK', 'WIFI5GSSID', 'WIFI5GPSK']

# Placeholder for "kept default" in result display
DEFAULT = '默认'

# Chinese punctuation normalization
def normalize(s):
    """Convert full-width punctuation to half-width"""
    trans = {
        '－': '-',    # full-width minus
        '，': ',',    # full-width comma
    }
    for k, v in trans.items():
        s = s.replace(k, v)
    return s

# Blacklist - never modified even if user requests
BLACKLIST = {
    'CONFIG_VENDOR',
    'CONFIG_PRODUCT',
    'CONFIG_FIRMWARE_PRODUCT_ID',
    'CONFIG_LINUXDIR',
    'CONFIG_KERNEL_NO_COMPRESS',
    'CONFIG_32M_REBOOT_FIXUP',
    'CONFIG_FIRMWARE_INCLUDE_SFE',
    'CONFIG_FIRMWARE_INCLUDE_CURL',
    'CONFIG_FIRMWARE_ENABLE_EXT2',
    'CONFIG_FIRMWARE_ENABLE_EXT3',
    'CONFIG_FIRMWARE_ENABLE_EXT4',
    'CONFIG_FIRMWARE_ENABLE_XFS',
    'CONFIG_FIRMWARE_ENABLE_FAT',
    'CONFIG_FIRMWARE_ENABLE_EXFAT',
    'CONFIG_FIRMWARE_ENABLE_FUSE',
    'CONFIG_FIRMWARE_ENABLE_SWAP',
    'CONFIG_FIRMWARE_INCLUDE_DUMP1090',
    'CONFIG_FIRMWARE_INCLUDE_RTL_SDR',
}

# Nano mode disable list
NANO_DISABLE = [
    'ANTFS', 'FAT', 'EXFAT', 'EXT2', 'EXT3', 'EXT4', 'XFS', 'FUSE', 'SWAP',
    'UVC', 'HID', 'SERIAL', 'AUDIO', 'XFRM', 'QOS', 'IMQ', 'IFB', 'NFSD', 'NFSC',
    'CIFS', 'NTFS_3G', 'LPRD', 'U2EC', 'TCPDUMP', 'HDPARM', 'PARTED',
    'SMBD', 'WINS', 'SMBD_SYSLOG', 'FTPD', 'RPL2TP', 'EAP_PEAP', 'HTTPS',
    'SFTP', 'DROPBEAR', 'DROPBEAR_FAST_CODE', 'OPENSSH', 'OPENVPN', 'SSWAN',
    'OPENSSL_EC', 'OPENSSL_EXE', 'XUPNPD', 'MINIDLNA', 'FIREFLY', 'FFMPEG_NEW',
    'TRANSMISSION', 'TRANSMISSION_WEB_CONTROL', 'ARIA', 'ARIA_WEB_CONTROL',
    'CURL', 'SCUTCLIENT', 'GDUT_DRCOM', 'DOGCOM', 'MINIEAP', 'NJIT_CLIENT',
    'SOFTETHERVPN_SERVER', 'SOFTETHERVPN_CLIENT', 'SOFTETHERVPN_CMD',
    'VLMCSD', 'TTYD', 'MSD_LITE', 'LRZSZ', 'HTOP', 'NANO', 'IPERF3',
    'DUMP1090', 'RTL_SDR', 'MTR', 'SOCAT', 'SRELAY', 'MENTOHUST',
    'FRPC', 'FRPS', 'REDSOCKS', 'SHADOWSOCKS', 'XRAY', 'V2RAY', 'TROJAN',
    'SSOBFS', 'SINGBOX', 'NAIVEPROXY', 'ADBYBY', 'DNSFORWARDER', 'SMARTDNS',
    'ADGUARDHOME', 'ZEROTIER', 'ALIDDNS', 'DDNSTO', 'ALDRIVER', 'SQM', 'WIREGUARD',
]

PREFIXES = [
    'CONFIG_FIRMWARE_INCLUDE_',
    'CONFIG_FIRMWARE_ENABLE_',
    'CONFIG_',
]

# Helpers
def build_key_map(lines):
    key_map = {}
    for line in lines:
        m = re.match(r'^#?(CONFIG_\S+?)=', line.strip())
        if not m:
            continue
        full_key = m.group(1)
        for prefix in PREFIXES:
            if full_key.startswith(prefix):
                suffix = full_key[len(prefix):]
                key_map[suffix] = full_key
                break
    return key_map

def set_value(lines, full_key, value):
    pattern = re.compile(rf'^#?{re.escape(full_key)}=(.*)$')
    for i, line in enumerate(lines):
        m = pattern.match(line.strip())
        if m:
            old_value = m.group(1).strip()
            if old_value == value and not line.strip().startswith('#'):
                return lines, False, old_value
            lines[i] = f'{full_key}={value}\n'
            return lines, True, old_value
    lines.append(f'{full_key}={value}\n')
    return lines, True, '(not found)'

def shell_head(s):
    if '.' in s:
        return s.split('.', 1)[0]
    return s

def shell_tail(s):
    if '.' in s:
        return s.split('.', 1)[1]
    return s

def set_macro(lines, macro, value):
    """Anchor '#define <macro>' and replace its value. Return (lines, changed, old)"""
    pattern = re.compile(rf'^(\s*#define\s+{re.escape(macro)}\s+)(.*)$')
    for i, line in enumerate(lines):
        m = pattern.match(line)
        if m:
            old = m.group(2).rstrip('\n')
            new = f'"{value}"'
            if old == new:
                return lines, False, old
            lines[i] = f'{m.group(1)}{new}\n'
            return lines, True, old
    return lines, False, None

def parse_customization(s):
    """Return list of 7 strings, or None if empty/count != 7."""
    if not s:
        return None
    s = normalize(s)
    fields = [x.strip() for x in s.split(',')]
    if len(fields) != 7:
        return None
    return fields

def export_env(s):
    """Write LANIP / SIGNACCOUNT / ... to GITHUB_ENV file."""
    env_file = os.environ.get('GITHUB_ENV')
    if not env_file:
        return
    fields = parse_customization(s)
    if fields is None:
        fields = [''] * 7
    with open(env_file, 'a', encoding='utf-8') as f:
        for k, v in zip(ENV_KEYS, fields):
            f.write(f'{k}={v}\n')

def apply_network_config(lanip, signaccount, signpassword,
                         wifi2g_ssid, wifi2g_psk, wifi5g_ssid, wifi5g_psk):
    """Apply to defaults.h + CN.dict. Empty value = skip.
       result: display values (user input or '默认')."""
    result = {
        'LAN IP': DEFAULT, 'DHCP 起': DEFAULT, 'DHCP 止': DEFAULT,
        '账号': DEFAULT, '密码': DEFAULT,
        '2.4G SSID': DEFAULT, '2.4G 密码': DEFAULT,
        '5G SSID': DEFAULT, '5G 密码': DEFAULT,
    }

    if not os.path.exists(DEFAULTS_H):
        print(f'❌ 找不到 {DEFAULTS_H}')
        return result

    with open(DEFAULTS_H, encoding='utf-8') as f:
        dl = f.readlines()

    print('🔧 网络配置（defaults.h + CN.dict）')

    if lanip:
        oc1 = shell_head(lanip)
        x = shell_tail(lanip)
        oc2 = shell_head(x)
        x = shell_tail(x)
        oc3 = shell_head(x)
        dhcpfrom = f'{oc1}.{oc2}.{oc3}.100'
        dhcpto = f'{oc1}.{oc2}.{oc3}.244'

        dl, ch, old = set_macro(dl, 'DEF_LAN_ADDR', lanip)
        print(f'   ✅ DEF_LAN_ADDR: {old} → "{lanip}"')
        result['LAN IP'] = lanip

        dl, ch, old = set_macro(dl, 'DEF_LAN_DHCP_BEG', dhcpfrom)
        print(f'   ✅ DEF_LAN_DHCP_BEG: {old} → "{dhcpfrom}"')
        result['DHCP 起'] = dhcpfrom

        dl, ch, old = set_macro(dl, 'DEF_LAN_DHCP_END', dhcpto)
        print(f'   ✅ DEF_LAN_DHCP_END: {old} → "{dhcpto}"')
        result['DHCP 止'] = dhcpto

        if os.path.exists(CN_DICT):
            with open(CN_DICT, encoding='utf-8') as f:
                content = f.read()
            content = content.replace('192.168.2.1', lanip)
            with open(CN_DICT, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f'   ✅ CN.dict: 192.168.2.1 → {lanip}')
        else:
            print(f'   ❌ 找不到 {CN_DICT}')
    else:
        for macro in ('DEF_LAN_ADDR', 'DEF_LAN_DHCP_BEG', 'DEF_LAN_DHCP_END'):
            print(f'   ⏭️ {macro}: 未填写，跳过')
        print(f'   ⏭️ CN.dict: 未填写，跳过')

    if signaccount:
        dl, ch, old = set_macro(dl, 'SYS_USER_ROOT', signaccount)
        print(f'   ✅ SYS_USER_ROOT: {old} → "{signaccount}"')
        result['账号'] = signaccount
    else:
        print(f'   ⏭️ SYS_USER_ROOT: 未填写，跳过')

    if signpassword:
        dl, ch, old = set_macro(dl, 'DEF_ROOT_PASSWORD', signpassword)
        print(f'   ✅ DEF_ROOT_PASSWORD: {old} → "{signpassword}"')
        result['密码'] = signpassword
    else:
        print(f'   ⏭️ DEF_ROOT_PASSWORD: 未填写，跳过')

    if wifi2g_ssid:
        dl, ch, old = set_macro(dl, 'DEF_WLAN_2G_SSID', wifi2g_ssid)
        print(f'   ✅ DEF_WLAN_2G_SSID: {old} → "{wifi2g_ssid}"')
        result['2.4G SSID'] = wifi2g_ssid
    else:
        print(f'   ⏭️ DEF_WLAN_2G_SSID: 未填写，跳过')

    if wifi2g_psk:
        dl, ch, old = set_macro(dl, 'DEF_WLAN_2G_PSK', wifi2g_psk)
        print(f'   ✅ DEF_WLAN_2G_PSK: {old} → "{wifi2g_psk}"')
        result['2.4G 密码'] = wifi2g_psk
    else:
        print(f'   ⏭️ DEF_WLAN_2G_PSK: 未填写，跳过')

    if wifi5g_ssid:
        dl, ch, old = set_macro(dl, 'DEF_WLAN_5G_SSID', wifi5g_ssid)
        print(f'   ✅ DEF_WLAN_5G_SSID: {old} → "{wifi5g_ssid}"')
        result['5G SSID'] = wifi5g_ssid
    else:
        print(f'   ⏭️ DEF_WLAN_5G_SSID: 未填写，跳过')

    if wifi5g_psk:
        dl, ch, old = set_macro(dl, 'DEF_WLAN_5G_PSK', wifi5g_psk)
        print(f'   ✅ DEF_WLAN_5G_PSK: {old} → "{wifi5g_psk}"')
        result['5G 密码'] = wifi5g_psk
    else:
        print(f'   ⏭️ DEF_WLAN_5G_PSK: 未填写，跳过')

    with open(DEFAULTS_H, 'w', encoding='utf-8') as f:
        f.writelines(dl)

    return result

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    parser.add_argument('--plugins', default='')
    parser.add_argument('--customization', default='')
    parser.add_argument('--nano', type=lambda x: str(x).lower() == 'true', default=False)
    parser.add_argument('--oc', type=lambda x: str(x).lower() == 'true', default=False)
    parser.add_argument('--oc-value', default=None)
    args = parser.parse_args()

    if not os.path.exists(args.config):
        print(f'❌ 找不到配置文件：{args.config}')
        sys.exit(1)

    export_env(args.customization)

    fields = parse_customization(args.customization)
    if fields is None:
        if args.customization:
            print('⚠️  customization 段数不对（需 7 段），网络配置全部走默认')
        lanip = signaccount = signpassword = ''
        wifi2g_ssid = wifi2g_psk = wifi5g_ssid = wifi5g_psk = ''
    else:
        (lanip, signaccount, signpassword,
         wifi2g_ssid, wifi2g_psk, wifi5g_ssid, wifi5g_psk) = fields

    changes = []

    net_result = apply_network_config(
        lanip, signaccount, signpassword,
        wifi2g_ssid, wifi2g_psk, wifi5g_ssid, wifi5g_psk)

    print()

    with open(args.config, encoding='utf-8') as f:
        lines = f.readlines()

    key_map = build_key_map(lines)
    print(f'📋 模板共 {len(key_map)} 个配置项')

    if args.plugins:
        cleaned = normalize(args.plugins)
        user_items = [x.strip() for x in cleaned.split(',') if x.strip()]
        print(f'🎯 用户输入：{user_items}')

        for raw in user_items:
            if raw.startswith('-'):
                action = 'n'
                name = raw[1:].strip().upper()
            else:
                action = 'y'
                name = raw.upper()

            name = name.replace(' ', '')
            if not name:
                continue

            full_key = key_map.get(name)
            if not full_key:
                for prefix in PREFIXES:
                    candidate = prefix + name
                    if candidate in key_map.values():
                        full_key = candidate
                        break

            if not full_key:
                print(f'   ⚠️  {name} 不存在，跳过')
                continue

            if full_key in BLACKLIST:
                print(f'   🔒 {name} 在黑名单，跳过')
                continue

            lines, changed, old = set_value(lines, full_key, action)
            if changed:
                changes.append(f'{full_key}: {old} → {action}')
                print(f'   ✅ {name} → {action}')
            else:
                print(f'   ⏭️  {name} 已经是 {action}，跳过')

    if args.oc:
        lines, changed, old = set_value(lines, 'CONFIG_FIRMWARE_INCLUDE_OC', 'y')
        if changed:
            changes.append(f'CONFIG_FIRMWARE_INCLUDE_OC: {old} → y')
            print(f'   ✅ OC → y')
        if args.oc_value:
            lines, changed, old = set_value(lines, 'CONFIG_FIRMWARE_MT7621_OC', f'"{args.oc_value}"')
            if changed:
                changes.append(f'CONFIG_FIRMWARE_MT7621_OC: {old} → "{args.oc_value}"')
                print(f'   ✅ OC 频率 → {args.oc_value}')

    if args.nano:
        print(f'🔧 Nano 模式：禁用 {len(NANO_DISABLE)} 个模块')
        disabled = 0
        for name in NANO_DISABLE:
            full_key = key_map.get(name)
            if not full_key:
                continue
            if full_key in BLACKLIST:
                continue
            lines, changed, old = set_value(lines, full_key, 'n')
            if changed:
                disabled += 1
        print(f'   ✅ 共禁用 {disabled} 项')

    with open(args.config, 'w', encoding='utf-8') as f:
        f.writelines(lines)

    print()
    print('=' * 60)

    print('📝 网络配置结果：')
    for label, val in net_result.items():
        print(f'   {label}: {val}')

    print()
    if changes:
        print(f'📝 配置变更清单（{len(changes)} 项）：')
        for c in changes:
            print(f'   {c}')
    else:
        print('📝 配置变更清单：无变更')

if __name__ == '__main__':
    main()
