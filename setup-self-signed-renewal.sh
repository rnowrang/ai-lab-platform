#!/bin/bash
# SELF-SIGNED SSL AUTO-RENEWAL SETUP
# Sets up automatic renewal of self-signed SSL certificates

set -e

DOMAIN="143.197.122.165"
SSL_DIR="/home/llurad/ai-lab-platform/ssl"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔐 Setting up automatic self-signed SSL renewal..."

# Create the renewal script
echo "📝 Creating SSL renewal script..."
sudo tee /usr/local/bin/renew-self-signed-ssl.sh << EOF
#!/bin/bash
# Auto-generated SSL renewal script
DOMAIN="$DOMAIN"
SSL_DIR="$SSL_DIR"
DAYS=365

echo "\$(date): Renewing self-signed SSL certificate for \$DOMAIN"

# Generate new certificate
sudo openssl req -x509 -nodes -days \$DAYS -newkey rsa:2048 \\
  -keyout "\$SSL_DIR/privkey.pem" \\
  -out "\$SSL_DIR/fullchain.pem" \\
  -subj "/C=US/ST=State/L=City/O=Institution/CN=\$DOMAIN"

# Set proper permissions
sudo chmod 600 "\$SSL_DIR/privkey.pem"
sudo chmod 644 "\$SSL_DIR/fullchain.pem"

# Restart nginx to load new certificate
docker restart ai-lab-nginx

echo "\$(date): Self-signed certificate renewed successfully"
EOF

# Make the renewal script executable
sudo chmod +x /usr/local/bin/renew-self-signed-ssl.sh

# Test the renewal script
echo "🧪 Testing SSL renewal script..."
sudo /usr/local/bin/renew-self-signed-ssl.sh

# Setup cron job for automatic renewal (every 11 months)
echo "⏰ Setting up automatic renewal cron job..."
(sudo crontab -l 2>/dev/null || echo "") | grep -v "renew-self-signed-ssl.sh" | sudo crontab -
(sudo crontab -l 2>/dev/null; echo "0 3 1 */11 * /usr/local/bin/renew-self-signed-ssl.sh >> /var/log/ssl-renewal.log 2>&1") | sudo crontab -

echo "✅ Self-signed SSL auto-renewal setup complete!"
echo ""
echo "📋 Summary:"
echo "  - Renewal script: /usr/local/bin/renew-self-signed-ssl.sh"
echo "  - Cron job: Runs 1st day of every 11th month at 3 AM"
echo "  - Log file: /var/log/ssl-renewal.log"
echo "  - Certificate valid for: 365 days"
echo ""
echo "🔍 To check cron job:"
echo "  sudo crontab -l"
echo ""
echo "🔄 To manually renew certificate:"
echo "  sudo /usr/local/bin/renew-self-signed-ssl.sh" 