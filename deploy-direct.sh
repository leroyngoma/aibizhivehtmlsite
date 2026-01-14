#!/bin/bash

# Direct Azure Static Web App Deployment via API
# Bypasses the buggy SWA CLI

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE=".azure-static-config"

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found. Run deploy-azure-static.sh first."
    exit 1
fi

source "$CONFIG_FILE"

print_status "Loading configuration..."
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Static Web App: $STATIC_WEB_APP_NAME"
echo ""

# Get deployment token
print_status "Retrieving deployment token..."
DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.apiKey" -o tsv)

if [ -z "$DEPLOYMENT_TOKEN" ]; then
    print_error "Failed to retrieve deployment token"
    exit 1
fi

print_success "Deployment token retrieved"

# Create deployment package
print_status "Creating deployment package..."
TEMP_DIR=$(mktemp -d)
DEPLOY_ZIP="$TEMP_DIR/deployment.zip"

# Create zip with all files
cd "$(dirname "$0")"
zip -r "$DEPLOY_ZIP" . \
    -x "*.sh" \
    -x ".azure-static-config" \
    -x ".git/*" \
    -x "node_modules/*" \
    -x "*.zip" \
    -x "swa-cli.config.json" \
    -x ".github/*" \
    -x "DEPLOYMENT.md" \
    -q

print_success "Deployment package created: $(du -h "$DEPLOY_ZIP" | cut -f1)"

# Upload via Azure deployment API
print_status "Uploading to Azure Static Web Apps..."

# Get the deployment endpoint
SITE_URL=$(az staticwebapp show \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "defaultHostname" -o tsv)

# Use the deployment API
DEPLOY_URL="https://${SITE_URL}/.auth/login/github"

print_warning "Direct API upload is not supported without GitHub integration."
print_warning "The SWA CLI bug prevents command-line deployment."
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Recommended Solution: GitHub Actions${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Your Azure Static Web App is created and ready:"
echo -e "${BLUE}https://$SITE_URL${NC}"
echo ""
echo "To deploy your files, follow these steps:"
echo ""
echo "1. Initialize Git repository:"
echo "   git init"
echo "   git add ."
echo "   git commit -m 'Initial commit'"
echo ""
echo "2. Create GitHub repository and push:"
echo "   # Create repo at https://github.com/new"
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Add deployment token as GitHub secret:"
echo "   # Go to repo Settings → Secrets → Actions"
echo "   # Add secret: AZURE_STATIC_WEB_APPS_API_TOKEN"
echo "   # Value: (run command below)"
echo ""
echo "   az staticwebapp secrets list \\"
echo "       --name $STATIC_WEB_APP_NAME \\"
echo "       --resource-group $RESOURCE_GROUP \\"
echo "       --query 'properties.apiKey' -o tsv"
echo ""
echo "4. GitHub Actions will automatically deploy on push"
echo ""
echo "The .github/workflows/azure-static-web-apps.yml file is already configured."
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
