#!/bin/sh
set -eu
DEFAULT_VERSION="2026-08-13"
DEFAULT_SHA256="f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9"
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
md_file="$script_dir/CA_CERTIFICATES.md"
if [ -f "$md_file" ]; then
sed -i \
  -e "s|^- Source:.*|- Source: \`https://curl.se/ca/cacert-${version}.pem\`|" \
  -e "s|^- SHA-256:.*|- SHA-256: \`$expected_sha256\`|" \
  -e "s|^- Mozilla data date:.*|- Mozilla data date: ${version}|" \
  -e "s|^- Certificate count:.*|- Certificate count: ${begin_count}|" \
  "$md_file"
fi
echo "Updated $destination ($begin_count certificates, Mozilla $version)."
