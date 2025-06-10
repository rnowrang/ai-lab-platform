# Automatic SSL Renewal Setup Guide

## 🔍 **Current Situation**
- **Current certificate:** Self-signed for IP `143.197.122.165`
- **Challenge:** Let's Encrypt requires domain names, not IP addresses
- **Goal:** Automatic SSL certificate renewal

## 🎯 **Recommended Solutions**

### **Option 1: Domain Name + Let's Encrypt (RECOMMENDED)**

#### **Step 1: Get a Domain Name**
You can:
- Register a domain (e.g., `ailab.example.com`)
- Use a free subdomain service (e.g., `yourlab.ddns.net`)
- Use dynamic DNS services (DuckDNS, No-IP, etc.)

#### **Step 2: Point Domain to Your IP**
Create an A record: `ailab.example.com` → `143.197.122.165`

#### **Step 3: Install Certbot and Get Certificate**
```bash
# Install certbot
sudo apt update
sudo apt install certbot

# Stop nginx temporarily
docker stop ai-lab-nginx

# Get Let's Encrypt certificate
sudo certbot certonly --standalone \
  --email admin@institution.local \
  --agree-tos \
  --no-eff-email \
  -d ailab.example.com

# Copy certificates to project
sudo cp /etc/letsencrypt/live/ailab.example.com/fullchain.pem ssl/
sudo cp /etc/letsencrypt/live/ailab.example.com/privkey.pem ssl/

# Restart nginx
docker start ai-lab-nginx
```

#### **Step 4: Setup Auto-Renewal**
```bash
# Test renewal
sudo certbot renew --dry-run

# Add cron job for automatic renewal
sudo crontab -e
# Add this line:
# 0 3 * * * certbot renew --quiet --post-hook "cp /etc/letsencrypt/live/ailab.example.com/*.pem /path/to/ai-lab-platform/ssl/ && docker restart ai-lab-nginx"
```

---

### **Option 2: Dynamic DNS + Let's Encrypt**

#### **Step 1: Setup DuckDNS (Free)**
1. Go to https://www.duckdns.org
2. Create account and subdomain: `yourlab.duckdns.org`
3. Get your token

#### **Step 2: Update DNS automatically**
```bash
# Install DuckDNS update script
sudo tee /usr/local/bin/duckdns-update.sh << 'EOF'
#!/bin/bash
echo url="https://www.duckdns.org/update?domains=yourlab&token=YOUR_TOKEN&ip=" | curl -k -o /tmp/duck.log -K -
EOF

sudo chmod +x /usr/local/bin/duckdns-update.sh

# Add to crontab for IP updates
echo "*/5 * * * * /usr/local/bin/duckdns-update.sh" | sudo crontab -
```

#### **Step 3: Get Let's Encrypt Certificate**
```bash
sudo certbot certonly --standalone \
  --email admin@institution.local \
  --agree-tos \
  --no-eff-email \
  -d yourlab.duckdns.org
```

---

### **Option 3: Self-Signed Certificate Auto-Renewal**

If you must stay with IP-only access:

#### **Step 1: Create Self-Signed Certificate Generator**
```bash
#!/bin/bash
# generate-self-signed.sh

DOMAIN="143.197.122.165"
SSL_DIR="/home/llurad/ai-lab-platform/ssl"
DAYS=365

# Generate new certificate
sudo openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
  -keyout "$SSL_DIR/privkey.pem" \
  -out "$SSL_DIR/fullchain.pem" \
  -subj "/C=US/ST=State/L=City/O=Institution/CN=$DOMAIN"

# Set permissions
sudo chmod 600 "$SSL_DIR/privkey.pem"
sudo chmod 644 "$SSL_DIR/fullchain.pem"

# Restart nginx
docker restart ai-lab-nginx

echo "Self-signed certificate renewed for $DOMAIN"
```

#### **Step 2: Setup Auto-Renewal**
```bash
# Add to crontab (renew every 11 months)
sudo crontab -e
# Add: 0 3 1 */11 * /path/to/generate-self-signed.sh
```

---

## 🚀 **Quick Setup Scripts**

### **For Let's Encrypt with Domain:**
```bash
#!/bin/bash
# setup-letsencrypt.sh

DOMAIN="$1"
EMAIL="admin@institution.local"

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

# Install certbot
sudo apt update
sudo apt install certbot -y

# Stop nginx
docker stop ai-lab-nginx

# Get certificate
sudo certbot certonly --standalone \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

# Copy to project
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/

# Setup renewal cron
echo "0 3 * * * certbot renew --quiet --post-hook \"cp /etc/letsencrypt/live/$DOMAIN/*.pem $(pwd)/ssl/ && docker restart ai-lab-nginx\"" | sudo crontab -

# Restart nginx
docker start ai-lab-nginx

echo "✅ Let's Encrypt SSL setup complete for $DOMAIN"
```

### **For Self-Signed Auto-Renewal:**
```bash
#!/bin/bash
# setup-self-signed-renewal.sh

# Create generator script
sudo tee /usr/local/bin/renew-self-signed-ssl.sh << 'EOF'
#!/bin/bash
DOMAIN="143.197.122.165"
SSL_DIR="/home/llurad/ai-lab-platform/ssl"
DAYS=365

sudo openssl req -x509 -nodes -days $DAYS -newkey rsa:2048 \
  -keyout "$SSL_DIR/privkey.pem" \
  -out "$SSL_DIR/fullchain.pem" \
  -subj "/C=US/ST=State/L=City/O=Institution/CN=$DOMAIN"

sudo chmod 600 "$SSL_DIR/privkey.pem"
sudo chmod 644 "$SSL_DIR/fullchain.pem"
docker restart ai-lab-nginx
echo "Self-signed certificate renewed"
EOF

sudo chmod +x /usr/local/bin/renew-self-signed-ssl.sh

# Setup cron job (renew every 11 months)
echo "0 3 1 */11 * /usr/local/bin/renew-self-signed-ssl.sh" | sudo crontab -

echo "✅ Self-signed SSL auto-renewal setup complete"
```

## 🎯 **Recommendation**

**Best approach for production:**
1. **Get a domain name** (even a free subdomain)
2. **Use Let's Encrypt** for trusted certificates
3. **Setup automatic renewal**

**For development/internal use:**
- **Self-signed auto-renewal** is acceptable

Would you like me to help you implement any of these options? 