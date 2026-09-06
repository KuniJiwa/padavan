#!/bin/sh

set -eu

DEFAULT_VERSION="2026-05-14"
DEFAULT_SHA256="86a1f3366afac7c6f8ae9f3c779ac221129328c43f0ab2b8817eb2f362a5025c"

version="${1:-$DEFAULT_VERSION}"
expected_sha256="${2:-}"

if [ -z "$expected_sha256" ]; then
	if [ "$version" != "$DEFAULT_VERSION" ]; then
		echo "Usage: $0 [VERSION SHA256]" >&2
		echo "A reviewed SHA256 is required when VERSION is changed." >&2
		exit 2
	fi
	expected_sha256="$DEFAULT_SHA256"
fi

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
destination="$script_dir/files/etc_ro/ssl/certs/ca-certificates.crt"
url="https://curl.se/ca/cacert-$version.pem"

mkdir -p "$(dirname "$destination")"
temporary=$(mktemp "$destination.tmp.XXXXXX")
trap 'rm -f "$temporary"' EXIT HUP INT TERM

curl --proto '=https' --tlsv1.2 -fsSL "$url" -o "$temporary"
printf '%s  %s\n' "$expected_sha256" "$temporary" | sha256sum -c -

begin_count=$(grep -c '^-----BEGIN CERTIFICATE-----$' "$temporary")
end_count=$(grep -c '^-----END CERTIFICATE-----$' "$temporary")
if [ "$begin_count" -ne "$end_count" ] || [ "$begin_count" -lt 100 ] || [ "$begin_count" -gt 200 ]; then
	echo "Unexpected certificate count: begin=$begin_count end=$end_count" >&2
	exit 1
fi

chmod 0644 "$temporary"
mv -f "$temporary" "$destination"
trap - EXIT HUP INT TERM

echo "Updated $destination ($begin_count certificates, Mozilla $version)."
