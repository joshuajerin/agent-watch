# Server Setup Guide — Agent Watch VPS

## Requirements

- Ubuntu 22.04 LTS (or Debian 12)
- Docker + Docker Compose v2
- Domain name or static IP with TLS certificate (Let's Encrypt recommended)
- Anthropic API key (or substitute your preferred AI provider)

---

## 1. Clone & Configure

```bash
git clone https://github.com/yourname/agent-watch.git
cd agent-watch/agent-watch-server
cp .env.example .env
chmod 600 .env
nano .env   # Fill in AUTH_TOKEN and ANTHROPIC_API_KEY
```

Generate a secure auth token:
```bash
python3 ../scripts/gen_token.py
```

---

## 2. TLS Certificate

### Option A: Let's Encrypt (recommended)
```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d your-vps.example.com
```

### Option B: Self-signed (development only)
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

---

## 3. nginx Configuration

```nginx
# /etc/nginx/sites-available/agent-watch
server {
    listen 443 ssl http2;
    server_name your-vps.example.com;

    ssl_certificate /etc/letsencrypt/live/your-vps.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-vps.example.com/privkey.pem;
    ssl_protocols TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers on;
    server_tokens off;

    location /ws {
        proxy_pass http://127.0.0.1:8000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 120s;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
ln -s /etc/nginx/sites-available/agent-watch /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

---

## 4. Deploy with Docker Compose

```bash
cd agent-watch/agent-watch-server
docker compose up -d
docker compose logs -f    # verify startup
curl http://localhost:8000/health
```

---

## 5. Firewall

```bash
ufw allow 22/tcp    # SSH
ufw allow 443/tcp   # HTTPS / WSS
ufw enable
```

---

## 6. Fail2ban for Auth Failures

Create `/etc/fail2ban/filter.d/agent-watch.conf`:
```ini
[Definition]
failregex = .*AUTH_FAIL.*<HOST>
ignoreregex =
```

Add to `/etc/fail2ban/jail.local`:
```ini
[agent-watch]
enabled  = true
filter   = agent-watch
logpath  = /var/log/nginx/access.log
maxretry = 3
bantime  = 3600
```

```bash
systemctl restart fail2ban
```

---

## 7. Get Your Cert Fingerprint (for cert pinning)

```bash
bash ../scripts/pin_cert.sh your-vps.example.com
# Output: SHA-256 fingerprint → paste into AgentWatch/Info.plist → VPSCertSHA256
```

---

## 8. Updating the AI Backend

Edit `agent-watch-server/.env`:
```env
# Switch from Anthropic to Ollama:
AI_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama3.2
```

Restart: `docker compose restart`
