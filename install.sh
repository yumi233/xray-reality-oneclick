#!/bin/bash
set -e

VERSION="2.0-alma-fix"
echo "Xray Reality Oneclick $VERSION"

if [ "$EUID" -ne 0 ]; then
 echo "Please run as root"
 exit 1
fi

OS_ID=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')

case "$OS_ID" in
 ubuntu|debian)
   apt update -y
   apt install -y curl openssl jq
   ;;
 almalinux|rocky|centos|rhel|fedora)
   dnf install -y curl openssl jq || yum install -y curl openssl jq
   ;;
 *)
   echo "Unsupported Linux: $OS_ID"
   exit 1
   ;;
esac

bash <(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)

UUID=$(cat /proc/sys/kernel/random/uuid)
KEY=$(xray x25519)
PRIVATE_KEY=$(echo "$KEY" | grep Private | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEY" | grep Password | awk '{print $3}')
SHORT_ID=$(openssl rand -hex 8)
SERVER_IP=$(curl -s ipv4.icanhazip.com)

mkdir -p /usr/local/etc/xray

cat > /usr/local/etc/xray/config.json <<EOF
{
 "inbounds":[{
  "port":443,
  "protocol":"vless",
  "settings":{"clients":[{"id":"$UUID","flow":"xtls-rprx-vision"}],"decryption":"none"},
  "streamSettings":{"network":"tcp","security":"reality","realitySettings":{"dest":"www.cloudflare.com:443","serverNames":["www.cloudflare.com"],"privateKey":"$PRIVATE_KEY","shortIds":["$SHORT_ID"]}}
 }],
 "outbounds":[{"protocol":"freedom"}]
}
EOF

if command -v firewall-cmd >/dev/null; then
 firewall-cmd --permanent --add-port=443/tcp || true
 firewall-cmd --reload || true
fi

systemctl enable xray
systemctl restart xray

echo "===== DONE ====="
echo "IP: $SERVER_IP"
echo "PORT: 443"
echo "UUID: $UUID"
echo "PUBLIC KEY: $PUBLIC_KEY"
echo "SHORT ID: $SHORT_ID"
echo "vless://$UUID@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#REALITY"
