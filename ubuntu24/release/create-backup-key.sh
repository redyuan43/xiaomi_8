#!/bin/sh
set -eu

KEY_UID=${KEY_UID:?set KEY_UID, for example 'Xiaomi 8 backup <backup@example.invalid>'}
OFFLINE_DIR=${OFFLINE_DIR:?set OFFLINE_DIR to an existing offline-media directory}
EXPIRY=${EXPIRY:-2y}

[ -d "$OFFLINE_DIR" ] || {
    echo "Offline directory does not exist: $OFFLINE_DIR" >&2
    exit 1
}
[ "$(find "$OFFLINE_DIR" -mindepth 1 -maxdepth 1 -print -quit)" = "" ] || {
    echo "Offline directory must be empty: $OFFLINE_DIR" >&2
    exit 1
}

gpg --quick-generate-key "$KEY_UID" rsa4096 sign "$EXPIRY"
fingerprint=$(
    gpg --with-colons --list-keys "$KEY_UID" |
        awk -F: '$1 == "fpr" {print $10; exit}'
)
[ -n "$fingerprint" ] || {
    echo "Unable to read generated key fingerprint" >&2
    exit 1
}
gpg --quick-add-key "$fingerprint" rsa4096 encr "$EXPIRY"

gpg --armor --export "$fingerprint" > "$OFFLINE_DIR/equuleus-release-and-backup.pub.asc"
gpg --armor --export-secret-keys "$fingerprint" \
    > "$OFFLINE_DIR/equuleus-release-and-backup.private.asc"
gpg --armor --export-secret-subkeys "$fingerprint" \
    > "$OFFLINE_DIR/equuleus-release-and-backup.subkeys.asc"
printf '%s\n' "$fingerprint" > "$OFFLINE_DIR/FINGERPRINT"
sha256sum "$OFFLINE_DIR"/* > "$OFFLINE_DIR/SHA256SUMS"
printf 'Fingerprint: %s\n' "$fingerprint"
printf 'Private-key export written only to: %s\n' "$OFFLINE_DIR"
