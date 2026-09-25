# CA certificate bundle

The firmware uses curl's PEM conversion of Mozilla's public root store:

- Source: `https://curl.se/ca/cacert-2026-08-13.pem`
- SHA-256: `f66dff1bdf8f96060b8177976f8b7d9254bc89bc4db933d769f7384d28480bc9`
- Mozilla data date: 2026-08-13
- Certificate count: 121

The bundle is stored once in read-only ROMFS at
`/etc_ro/ssl/certs/ca-certificates.crt`. Early boot creates these compatibility
links before services start:

- `/etc/ssl/certs/ca-certificates.crt`
- `/etc/ssl/cert.pem`

This replaces the old `certs.tgz` extraction into `/etc` tmpfs. It avoids an
asynchronous startup race and does not duplicate the certificate store in RAM.

To reinstall the pinned bundle, run:

```sh
./update-ca-bundle.sh
```

For a reviewed update, obtain the versioned PEM and SHA-256 from
`https://curl.se/docs/caextract.html`, then run:

```sh
./update-ca-bundle.sh YYYY-MM-DD REVIEWED_SHA256
```

Do not update the trust store from the router at boot. Firmware builds must
remain reproducible, and an online boot update is vulnerable to incorrect time,
network failure, partial writes, and trust-bootstrap failures.
