#!/bin/bash
# Generate Secure Secrets Script
# Generates all required secrets for the FKS platform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRETS_FILE="${PROJECT_ROOT}/.env.secrets"

echo "🔐 FKS Platform - Secret Generation"
echo "===================================="
echo ""

# Check if secrets file exists
if [ -f "$SECRETS_FILE" ]; then
    echo "⚠️  Secrets file already exists: $SECRETS_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    echo ""
fi

# Generate secrets using Python
echo "Generating secure random secrets..."
SECRETS=$(python3 <<EOF
import secrets
from cryptography.fernet import Fernet

def generate_jwt_secret():
    return secrets.token_urlsafe(32)

def generate_django_secret_key():
    return secrets.token_urlsafe(50)

def generate_encryption_key():
    return Fernet.generate_key().decode()

def generate_redis_password():
    return secrets.token_urlsafe(32)

def generate_auth_secret():
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return ''.join(secrets.choice(alphabet) for _ in range(64))

def generate_database_password():
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(32))

secrets_dict = {
    "DJANGO_SECRET_KEY": generate_django_secret_key(),
    "JWT_SECRET": generate_jwt_secret(),
    "AUTH_SECRET": generate_auth_secret(),
    "ENCRYPTION_KEY": generate_encryption_key(),
    "REDIS_PASSWORD": generate_redis_password(),
    "POSTGRES_PASSWORD": generate_database_password(),
}

for key, value in secrets_dict.items():
    print(f"{key}={value}")
EOF
)

# Write to secrets file
echo "# Auto-generated secrets - DO NOT COMMIT TO GIT" > "$SECRETS_FILE"
echo "# This file contains sensitive credentials" >> "$SECRETS_FILE"
echo "# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> "$SECRETS_FILE"
echo "" >> "$SECRETS_FILE"
echo "$SECRETS" >> "$SECRETS_FILE"

# Set secure permissions (read/write for owner only)
chmod 600 "$SECRETS_FILE"

echo "✅ Secrets generated successfully!"
echo ""
echo "📁 Secrets saved to: $SECRETS_FILE"
echo ""
echo "🔒 Security:"
echo "   - File permissions set to 600 (owner read/write only)"
echo "   - File is in .gitignore (will not be committed)"
echo ""
echo "📋 Next steps:"
echo "   1. Review the secrets file: cat $SECRETS_FILE"
echo "   2. Copy to your .env file or set as environment variables"
echo "   3. Restart services to pick up new secrets"
echo ""
echo "⚠️  IMPORTANT: Keep this file secure and never commit it to version control!"
