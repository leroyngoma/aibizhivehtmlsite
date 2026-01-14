#!/bin/bash

# Azure Static Web App Deployment Script
# This script deploys the static website to Azure Static Web Apps

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file
CONFIG_FILE=".azure-static-config"

# Helper functions
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

print_success "Azure CLI found"

# Check Azure login
print_status "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Please log in..."
    az login
fi

ACCOUNT_NAME=$(az account show --query name -o tsv)
print_success "Logged in as: $ACCOUNT_NAME"

# Load or create configuration
if [ -f "$CONFIG_FILE" ]; then
    print_status "Found existing configuration file"
    source "$CONFIG_FILE"
    
    echo ""
    echo "Current configuration:"
    echo "  Resource Group: $RESOURCE_GROUP"
    echo "  Static Web App: $STATIC_WEB_APP_NAME"
    echo "  Location: $LOCATION"
    echo ""
    
    read -p "Do you want to use this configuration? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        rm "$CONFIG_FILE"
        print_status "Configuration cleared. Creating new deployment..."
    fi
fi

# Prompt for configuration if not exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_status "Setting up new deployment configuration..."
    
    read -p "Enter Resource Group name (default: aibizhive-rg): " RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-aibizhive-rg}
    
    read -p "Enter Static Web App name (default: aibizhive-site): " STATIC_WEB_APP_NAME
    STATIC_WEB_APP_NAME=${STATIC_WEB_APP_NAME:-aibizhive-site}
    
    read -p "Enter Azure location (default: eastus): " LOCATION
    LOCATION=${LOCATION:-eastus}
    
    # Save configuration
    cat > "$CONFIG_FILE" << EOF
RESOURCE_GROUP="$RESOURCE_GROUP"
STATIC_WEB_APP_NAME="$STATIC_WEB_APP_NAME"
LOCATION="$LOCATION"
EOF
    
    print_success "Configuration saved to $CONFIG_FILE"
fi

# Create resource group if it doesn't exist
print_status "Ensuring resource group exists..."
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    print_status "Creating resource group: $RESOURCE_GROUP"
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    print_success "Resource group created"
else
    print_success "Resource group already exists"
fi

# Check if Static Web App exists
print_status "Checking if Static Web App exists..."
if az staticwebapp show --name "$STATIC_WEB_APP_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    print_success "Static Web App already exists"
    EXISTING_APP=true
else
    print_status "Creating Static Web App: $STATIC_WEB_APP_NAME"
    az staticwebapp create \
        --name "$STATIC_WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Free
    print_success "Static Web App created"
    EXISTING_APP=false
fi

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

# Create a temporary deployment directory
print_status "Preparing deployment package..."
TEMP_DIR=$(mktemp -d)
BUILD_DIR="$TEMP_DIR/build"
mkdir -p "$BUILD_DIR"

# Copy all files except config and script files
rsync -av --exclude='.azure-static-config' \
    --exclude='deploy-azure-static.sh' \
    --exclude='.git' \
    --exclude='node_modules' \
    ./ "$BUILD_DIR/"

print_success "Files prepared for deployment"

# Install SWA CLI if not present
if ! command -v swa &> /dev/null; then
    print_warning "Azure Static Web Apps CLI not found. Installing..."
    npm install -g @azure/static-web-apps-cli
    print_success "SWA CLI installed"
fi

# Deploy from the build directory
print_status "Deploying static site to Azure..."
echo ""

cd "$BUILD_DIR"
swa deploy . \
    --deployment-token "$DEPLOYMENT_TOKEN" \
    --env production \
    --no-use-keychain

cd - > /dev/null

# Cleanup
rm -rf "$TEMP_DIR"

print_success "Deployment completed!"

# Get the URL
print_status "Retrieving site URL..."
SITE_URL=$(az staticwebapp show \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "defaultHostname" -o tsv)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Successful!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Your site is available at:"
echo -e "${BLUE}https://$SITE_URL${NC}"
echo ""
echo "Configuration saved in: $CONFIG_FILE"
echo ""
echo "To update your site in the future, simply run this script again."
echo ""
echo "Useful commands:"
echo "  View logs:    az staticwebapp show --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP"
echo "  Delete app:   az staticwebapp delete --name $STATIC_WEB_APP_NAME --resource-group $RESOURCE_GROUP"
echo ""
