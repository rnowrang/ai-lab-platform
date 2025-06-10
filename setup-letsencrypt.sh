#!/bin/bash
# LET'S ENCRYPT SSL AUTO-RENEWAL SETUP
# Sets up Let's Encrypt certificates with automatic renewal

set -e

DOMAIN="$1"
EMAIL="admin@institution.local"
SSL_DIR="/home/llurad/ai-lab-platform/ssl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$DOMAIN" ]; then
    echo "❌ Usage: $0 <domain>"
    echo "   Example: $0 ailab.example.com"
    echo "   Example: $0 yourlab.duckdns.org"
    exit 1
fi

echo "🔐 Setting up Let's Encrypt SSL for $DOMAIN..."

# Check if domain resolves to this server
echo "🔍 Checking domain resolution..."
DOMAIN_IP=$(nslookup "$DOMAIN" | grep -A1 "Name:" | tail -1 | awk '{print $2}' || echo "")
SERVER_IP=$(curl -s https://ipinfo.io/ip || echo "")

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    echo "⚠️  Warning: Domain $DOMAIN resolves to $DOMAIN_IP"
    echo "   But this server's public IP is $SERVER_IP"
    echo "   Make sure the domain points to this server before continuing"
    read -p "   Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "📦 Installing certbot..."
    sudo apt update
    sudo apt install certbot -y
else
    echo "✅ Certbot already installed"
fi

# Stop nginx temporarily for standalone mode
echo "⏸️  Stopping nginx temporarily..."
docker stop ai-lab-nginx

# Get Let's Encrypt certificate
echo "🏆 Obtaining Let's Encrypt certificate..."
sudo certbot certonly --standalone \
  --email "$EMAIL" \
  --agree-tos \
  --no-eff-email \
  -d "$DOMAIN"

# Copy certificates to project
echo "📋 Copying certificates to project..."
sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/"
sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/"

# Set proper permissions
sudo chmod 600 "$SSL_DIR/privkey.pem"
sudo chmod 644 "$SSL_DIR/fullchain.pem"

# Create renewal script
echo "📝 Creating renewal script..."
sudo tee /usr/local/bin/renew-letsencrypt-ssl.sh << EOF
#!/bin/bash
# Auto-generated Let's Encrypt renewal script
DOMAIN="$DOMAIN"
SSL_DIR="$SSL_DIR"

echo "\$(date): Renewing Let's Encrypt certificate for \$DOMAIN"

# Renew certificate
certbot renew --quiet

# Copy renewed certificates
cp "/etc/letsencrypt/live/\$DOMAIN/fullchain.pem" "\$SSL_DIR/"
cp "/etc/letsencrypt/live/\$DOMAIN/privkey.pem" "\$SSL_DIR/"

# Set permissions
chmod 600 "\$SSL_DIR/privkey.pem"
chmod 644 "\$SSL_DIR/fullchain.pem"

# Restart nginx
docker restart ai-lab-nginx

echo "\$(date): Let's Encrypt certificate renewed successfully"
EOF

sudo chmod +x /usr/local/bin/renew-letsencrypt-ssl.sh

# Setup cron job for automatic renewal (twice daily, Let's Encrypt recommendation)
echo "⏰ Setting up automatic renewal cron job..."
(sudo crontab -l 2>/dev/null || echo "") | grep -v "renew-letsencrypt-ssl.sh" | sudo crontab -
(sudo crontab -l 2>/dev/null; echo "0 3,15 * * * /usr/local/bin/renew-letsencrypt-ssl.sh >> /var/log/letsencrypt-renewal.log 2>&1") | sudo crontab -

# Test renewal (dry run)
echo "🧪 Testing renewal process..."
sudo certbot renew --dry-run

# Start nginx with new certificate
echo "▶️  Starting nginx with new certificate..."
docker start ai-lab-nginx

# Wait for nginx to start
sleep 5

# Test HTTPS
echo "🔗 Testing HTTPS connection..."
if curl -s -k "https://$DOMAIN/" > /dev/null; then
    echo "✅ HTTPS is working!"
else
    echo "⚠️  HTTPS test failed - check nginx logs"
fi

echo ""
echo "🎉 Let's Encrypt SSL setup complete!"
echo ""
echo "📋 Summary:"
echo "  - Domain: $DOMAIN"
echo "  - Certificate: /etc/letsencrypt/live/$DOMAIN/"
echo "  - Renewal script: /usr/local/bin/renew-letsencrypt-ssl.sh"
echo "  - Cron job: Runs twice daily (3 AM and 3 PM)"
echo "  - Log file: /var/log/letsencrypt-renewal.log"
echo "  - Certificate valid for: 90 days (auto-renewed)"
echo ""
echo "🔍 To check certificate:"
echo "  sudo certbot certificates"
echo ""
echo "🔄 To manually renew:"
echo "  sudo /usr/local/bin/renew-letsencrypt-ssl.sh" 