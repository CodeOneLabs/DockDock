#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CERT_DIR="$ROOT_DIR/.local-codesign"
KEYCHAIN="$CERT_DIR/DockDock.keychain-db"
IDENTITY="DockDock Local Code Signing"
PASSWORD="DockDock"
P12_PASSWORD="DockDock"

mkdir -p "$CERT_DIR"

if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY"; then
  security unlock-keychain -p "$PASSWORD" "$KEYCHAIN" >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
  if ! security list-keychains -d user | grep -Fq "$KEYCHAIN"; then
    current_keychains=()
    while IFS= read -r keychain; do
      current_keychains+=("$keychain")
    done < <(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')
    security list-keychains -d user -s "$KEYCHAIN" "${current_keychains[@]}"
  fi
  printf '%s\n' "$KEYCHAIN"
  exit 0
fi

rm -f "$CERT_DIR/$IDENTITY.key" "$CERT_DIR/$IDENTITY.crt" "$CERT_DIR/$IDENTITY.p12" "$KEYCHAIN"

cat >"$CERT_DIR/openssl.cnf" <<'OPENSSL'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[ dn ]
CN = DockDock Local Code Signing

[ v3_req ]
basicConstraints = critical, CA:TRUE
keyUsage = critical, digitalSignature, keyCertSign
extendedKeyUsage = codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
OPENSSL

openssl req -new -newkey rsa:2048 -nodes -x509 -days 3650 \
  -config "$CERT_DIR/openssl.cnf" \
  -keyout "$CERT_DIR/$IDENTITY.key" \
  -out "$CERT_DIR/$IDENTITY.crt" >/dev/null 2>&1

openssl pkcs12 -legacy -export \
  -inkey "$CERT_DIR/$IDENTITY.key" \
  -in "$CERT_DIR/$IDENTITY.crt" \
  -name "$IDENTITY" \
  -out "$CERT_DIR/$IDENTITY.p12" \
  -passout "pass:$P12_PASSWORD"

security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
security import "$CERT_DIR/$IDENTITY.p12" \
  -k "$KEYCHAIN" \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$CERT_DIR/$IDENTITY.crt" >/dev/null 2>&1 || true

current_keychains=()
while IFS= read -r keychain; do
  current_keychains+=("$keychain")
done < <(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')
security list-keychains -d user -s "$KEYCHAIN" "${current_keychains[@]}"

if ! security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "$IDENTITY"; then
  echo "Could not create a valid local code signing identity." >&2
  exit 1
fi

printf '%s\n' "$KEYCHAIN"
