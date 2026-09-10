#!/usr/bin/env python3
# gen_config.py - Apply user-selected plugins to .config
#
# Rules:
#   1. Input is comma-separated plugin names
#   2. Prefix "-" means disable (set to n)
#   3. Unlisted plugins stay at template default
#   4. Blacklisted plugins are never modified
#   5. Unknown plugin names are silently skipped
#   6. Case-insensitive, Chinese punctuation auto-normalized
#   7. Nano mode force-disables a batch of modules
#   8. Backup before change, print changelog after
#
# Usage:
#   python3 gen_config.py --config <path> --plugins "xray,-smartdns"
#                         [--nano true] [--oc true] [--oc-value 0x362]

import argparse
import os
import re
import shutil
import sys

# Chinese punctuation normalization
def normalize(s):
    """Convert full-width punctuation to half-width"""
    trans = {
        '－': '-',    # full-width minus
        '—': '-',    # em dash
        '–': '-',    # en dash
        '，': ',',    # full-width comma
        '、': ',',    # ideographic comma
    }
    for k, v in trans.items():
        s = s.replace(k, v)
    return s

# Blacklist - never modified even if user requests
BLACKLIST = {
    # Structural config
    'CONFIG_VENDOR',
    'CONFIG_PRODUCT',
    'CONFIG_FIRMWARE_PRODUCT_ID',
    'CONFIG_LINUXDIR',
    'CONFIG_KERNEL_NO_COMPRESS',
    'CONFIG_32M_REBOOT_FIXUP',

    # Core features (must keep)
    'CONFIG_FIRMWARE_ENABLE_IPV6',
    'CONFIG_FIRMWARE_INCLUDE_SFE',
    'CONFIG_FIRMWARE_INCLUDE_CURL',

    # Filesystem (use template default)
    'CONFIG_FIRMWARE_ENABLE_EXT2',
    'CONFIG_FIRMWARE_ENABLE_EXT3',
    'CONFIG_FIRMWARE_ENABLE_EXT4',
    'CONFIG_FIRMWARE_ENABLE_XFS',
    'CONFIG_FIRMWARE_ENABLE_FAT',
    'CONFIG_FIRMWARE_ENABLE_EXFAT',
    'CONFIG_FIRMWARE_ENABLE_FUSE',
    'CONFIG_FIRMWARE_ENABLE_SWAP',

    # Niche features (use template default)
    'CONFIG_FIRMWARE_INCLUDE_DUMP1090',
    'CONFIG_FIRMWARE_INCLUDE_RTL_SDR',
}

# Nano mode disable list
NANO_DISABLE = [
    # ENABLE keys
    'ANTFS', 'FAT', 'EXFAT', 'EXT2', 'EXT3', 'EXT4', 'XFS', 'FUSE', 'SWAP',
    # INCLUDE keys
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
    """Build suffix -> full key map from template"""
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
    """Set key to value. Return (lines, changed, old_value)"""
    pattern = re.compile(rf'^#?{re.escape(full_key)}=(.*)$')
    for i, line in enumerate(lines):
        m = pattern.match(line.strip())
        if m:
            old_value = m.group(1).strip()
            if old_value == value and not line.strip().startswith('#'):
                return lines, False, old_value
            lines[i] = f'{full_key}={value}\n'
            return lines, True, old_value
    # Append if not exists
    lines.append(f'{full_key}={value}\n')
    return lines, True, '(not found)'

# Main
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', required=True)
    parser.add_argument('--plugins', default='')
    parser.add_argument('--nano', type=lambda x: str(x).lower() == 'true', default=False)
    parser.add_argument('--oc', type=lambda x: str(x).lower() == 'true', default=False)
    parser.add_argument('--oc-value', default=None)
    args = parser.parse_args()

    if not os.path.exists(args.config):
        print(f'❌ 找不到配置文件：{args.config}')
        sys.exit(1)

    # Backup
    backup = args.config + '.bak'
    shutil.copy2(args.config, backup)
    print(f'📦 已备份：{backup}')

    with open(args.config, encoding='utf-8') as f:
        lines = f.readlines()

    key_map = build_key_map(lines)
    print(f'📋 模板共 {len(key_map)} 个配置项')

    changes = []

    # 1. Apply user plugins
    if args.plugins:
        cleaned = normalize(args.plugins)
        user_items = [x.strip() for x in cleaned.split(',') if x.strip()]
        print(f'🎯 用户输入：{user_items}')

        for raw in user_items:
            # Prefix "-" means disable
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

    # 2. CPU overclocking
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

    # 3. Nano mode (overrides user settings)
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

    # Write back
    with open(args.config, 'w', encoding='utf-8') as f:
        f.writelines(lines)

    # Print changelog
    print()
    print('=' * 60)
    if changes:
        print(f'📝 变更清单（{len(changes)} 项）：')
        for c in changes:
            print(f'   {c}')
    else:
        print('📝 无变更（用户没填，或全在黑名单）')
    print('=' * 60)

if __name__ == '__main__':
    main()
