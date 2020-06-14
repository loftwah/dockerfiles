#!/bin/sh

set -xe

if [ -n "$(id -u pureftpd)" ]; then
  deluser pureftpd
fi

if [ -n "$(id -g pureftpd)" ]; then
  delgroup pureftpd
fi

addgroup -g "$GID" pureftpd
adduser -u "$UID" -G pureftpd -D pureftpd

if [ -z "$PURE_PASSIVIP" ]; then
  #PURE_PASSIVIP="$(/sbin/ip route | awk '/default/ { print $3 }')"
  PURE_PASSIVIP="$(dig +short -4 myip.opendns.com @resolver1.opendns.com 2>/dev/null)"
  [ -z "$PURE_PASSIVIP" ] && PURE_PASSIVIP="127.0.0.1"
fi

if [ -z "${PURE_CERTFILE}" ] || [ -z "${PURE_KEYFILE}" ]; then
    PURE_CERTFILE="/config/certs/cert.pem"
    PURE_KEYFILE="/config/certs/key.pem"
fi

# create missing directories
mkdir -p "$(dirname "$PURE_CERTFILE")"
mkdir -p "$(dirname "$PURE_KEYFILE")"
mkdir -p "$(dirname "$PURE_PASSWDFILE")"
mkdir -p "$(dirname "$PURE_CONFIGFILE")"

# generate selfsigned certificate if needed
if ! [ -f "${PURE_CERTFILE}" ] || ! [ -f "${PURE_KEYFILE}" ]; then
    openssl req -new -x509 -days 3650 -nodes \
        -out "${PURE_CERTFILE}" -newkey rsa:4096 \
        -keyout "${PURE_KEYFILE}" -subj "/CN=${DOMAIN}"
fi

if ! [ -f "${PURE_CONFIGFILE}" ]; then
  cp /etc/pure-ftpd.conf "$PURE_CONFIGFILE"
fi

sed -i \
  -e "s|<PURE_PASSIVIP>|${PURE_PASSIVIP}|g" \
  -e "s|<PURE_CERTFILE>|${PURE_CERTFILE}|g" \
  -e "s|<PURE_KEYFILE>|${PURE_KEYFILE}|g" \
  -e "s|<PURE_QUOTA>|${PURE_QUOTA}|g" \
  "$PURE_CONFIGFILE"

if [ -f "$PURE_PASSWDFILE" ]; then
  pure-pw mkdb "$PURE_PDBFILE" -f "$PURE_PASSWDFILE"
fi

chown pureftpd:pureftpd -R /config/*
chmod 755 -R /config/*

exec /bin/s6-svscan /etc/s6.d
