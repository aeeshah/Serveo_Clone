#!/bin/bash

DOMAIN="tunnelprime.online"
PORTS_FILE="/home/tunnel/used_ports.txt"
BASE_PORT=10000
SUBDOMAIN=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)

function getport() {
    while true; do
        PORT=$((BASE_PORT + RANDOM % 55535))
        if ! grep -q "^$PORT$" "$PORTS_FILE" 2>/dev/null; then
            echo "$PORT" >> "$PORTS_FILE"
            echo "$PORT"
            return
        fi
    done
}


function newconnection() {
    local remote_port=$(getport)

    # Set up iptables rule for this specific SUBDOMAIN
    sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 80 -j REDIRECT --to-port $remote_port
    sudo iptables -t nat -A PREROUTING -p tcp -d "$SUBDOMAIN.$DOMAIN" --dport 443 -j REDIRECT --to-port $remote_port

    # Update Nginx configuration
    sudo tee /etc/nginx/sites-available/$SUBDOMAIN.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $SUBDOMAIN.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $SUBDOMAIN.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/tunnelprime.online/fullchain.pem
    ssl_certificate_key /etc/letsencrypt/live/tunnelprime.online/privkey.pem

    location / {
        proxy_pass http://localhost:$remote_port;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    sudo ln -s /etc/nginx/sites-available/$SUBDOMAIN.conf /etc/nginx/sites-enabled/
    sudo nginx -s reload

    # Keep the script running
    while true; do
        sleep 10
    done 
}


newconnection 3000
