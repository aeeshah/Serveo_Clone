### Tunneling Script

TunnelPrime is a custom tunneling service that uses SSH reverse forwarding to create dynamic public URLs for accessing local applications over the internet. The service is designed to handle port forwarding, wildcard domains, and SSL termination through an automated setup.

---

### Key Features

1. **Dynamic SSH Reverse Forwarding**:
   - TunnelPrime uses SSH reverse forwarding to create public URLs dynamically. This allows users to expose their local applications to the internet securely.

2. **Proxy Management**:
   - The service includes built-in proxy management using Nginx and iptables, ensuring that traffic on port 80 and port 443 is properly routed to the local application.

3. **Wildcard Domains**:
   - TunnelPrime supports wildcard domains, enabling users to create subdomains dynamically, allowing for multiple services to be exposed under a single primary domain.

4. **SSL Termination**:
   - SSL certificates are automatically managed using Let's Encrypt, ensuring that all connections are secured without manual intervention.

---

### How TunnelPrime Works

TunnelPrime operates on a server where it listens for SSH commands from a local machine. When a user connects, the script dynamically assigns an available port, configures the necessary Nginx and iptables rules, and provides the user with a public URL to access their application.

---

### Configuration Details

#### 1. Dynamic Port Allocation

TunnelPrime dynamically allocates an available port for each new connection:

```bash
DOMAIN="tunnelprime.online"
PORTS_FILE="/home/tunnel/used_ports.txt"
BASE_PORT=10000
SUBDOMAIN=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
```

The `getport` function ensures that a unique and available port is assigned to each connection:

```bash
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
```

#### 2. Setting Up Nginx and iptables

When a new connection is established, TunnelPrime sets up the required iptables rules and Nginx configuration for the assigned subdomain:

```bash
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
    ssl_certificate_key /etc/letsencrypt/live/tunnelprime.online/privkey.pem;

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
}
```

- **iptables**: Redirects traffic from the subdomain to the dynamically assigned port.
- **Nginx**: Configures SSL termination and proxy settings, ensuring secure traffic routing to the application.


#### 3. Automation and Persistence

TunnelPrime is designed to run automatically whenever a user establishes an SSH connection. The script remains active, continuously listening for new connections:

```bash
while true; do
    sleep 10
done
```

### Service Development

#### 1. Script Creation

The core of the TunnelPrime service is a script designed to listen for incoming SSH commands from a client’s local machine. Upon receiving a connection, the script identifies the port on which the local application is running and dynamically generates a link and port number, allowing the user to access their application via a public URL.

#### Location
- The script is stored on the server for easy access:
  ```
  /usr/local/bin/tunnel_service.sh
  ```

#### File Permissions
- To ensure the script is executable, the following command is used:
  ```bash
  chmod +x /usr/local/bin/tunnel_service.sh
  ```

#### 2. SSH Server Configuration (`sshd_config`)

For the TunnelPrime service to function seemlessly, several key configurations were made to the SSH server configuration file (`/etc/ssh/sshd_config`).

#### Enable TCP Forwarding
- **Purpose**: Allow the SSH server to support SSH reverse tunneling by forwarding ports from the local machine to the remote host.
- **Configuration**: Add the following lines to `sshd_config`:
  ```bash
  AllowTcpForwarding yes
  GatewayPorts yes
  ```

#### Permit User Environment
- **Purpose**: Allows the SSH server to execute custom scripts or commands upon user login using environment variables.
- **Configuration**: Enable this feature by adding:
  ```bash
  PermitUserEnvironment yes
  ```

#### Disable Password Authentication
- **Purpose**: Bypasses the need for password entry during the tunneling setup, streamlining the connection process.
- **Configuration**: Disable password authentication with:
  ```bash
  PasswordAuthentication no
  ```

#### Force Command Execution
- **Purpose**: Automatically executes the TunnelPrime script whenever a user connects via SSH.
- **Configuration**: Add the following line:
  ```bash
  ForceCommand /usr/local/bin/tunnel_service.sh
  ```

#### Restart the SSH Service
- **Purpose**: Apply the new configurations by restarting the SSH service.
- **Command**: 
  ```bash
  sudo systemctl restart sshd
  ```

These configurations ensure that the SSH server is fully prepared to handle the TunnelPrime tunneling service, providing a seamless and automatic reverse SSH tunnel setup for users.

### Command for Client-Side Usage

The user on the local machine can establish a tunnel to TunnelPrime using the following SSH command:

```bash
ssh -R 8080:localhost:3000 server@tunnelprime.online
```

This command forwards the local port `3000` to port `80` on the TunnelPrime server, making the local application accessible via the provided subdomain.

---

