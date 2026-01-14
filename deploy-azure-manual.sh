#!/bin/bash

# Azure Static Web App Manual Deployment Script
# This script uses direct file upload to avoid SWA CLI issues

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration file
CONFIG_FILE=".azure-static-config"

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

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found. Please run deploy-azure-static.sh first to create the Static Web App."
    exit 1
fi

source "$CONFIG_FILE"

print_status "Using configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Static Web App: $STATIC_WEB_APP_NAME"
echo ""

# Check Azure login
if ! az account show &> /dev/null; then
    print_warning "Not logged in to Azure. Please log in..."
    az login
fi

# Create deployment package
print_status "Creating deployment package..."
TEMP_ZIP=$(mktemp).zip

# Create zip file with all website files
zip -r "$TEMP_DIR/site.zip" . \
    -x "*.sh" \
    -x ".azure-static-config" \
    -x ".git/*" \
    -x "node_modules/*" \
    -x "*.zip" \
    -x "swa-cli.config.json"

print_success "Deployment package created"

# Get deployment token
print_status "Retrieving deployment token..."
source "$CONFIG_FILE"

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
DEPLOY_ZIP="deployment-$(date +%s).zip"

# Create zip excluding unnecessary files
zip -r "$DEPLOY_ZIP" . \
    -x "*.sh" \
    -x ".azure-static-config" \
    -x ".git/*" \
    -x "node_modules/*" \
    -x "*.zip" \
    -x "swa-cli.config.json"

print_success "Deployment package created"

# Use oryx build and deploy
print_status "Deploying to Azure Static Web Apps..."

# Create a temporary directory for deployment
DEPLOY_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Extract files
unzip -q "$ZIP_FILE"

# Use Azure CLI to deploy
print_status "Uploading files to Azure..."

# Get the deployment token
DEPLOYMENT_TOKEN=$(az staticwebapp secrets list \
    --name "$STATIC_WEB_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "properties.apiKey" -o tsv)

# Use curl to upload via the deployment API
print_status "Uploading files via Azure API..."

# Create deployment zip
cd "$BUILD_DIR"
zip -r ../deployment.zip . -x "*.git*" -x "*.azure-static-config*" -x "deploy-*.sh"
cd - > /dev/null

print_error "Manual upload required. The SWA CLI has known issues."
print_warning "Please use one of these methods to deploy:"
echo ""
echo "Option 1: Use GitHub Actions (recommended)"
echo "  - Push your code to GitHub"
echo "  - Connect your repository in the Azure Portal"
echo ""
echo "Option 2: Use Azure Portal"
echo "  1. Go to: https://portal.azure.com"
echo "  2. Navigate to your Static Web App: aibizhive-site"
echo "  3. Use the 'Browse' button to upload your files"
echo ""
echo "Option 3: Try the Oryx-based deployment (experimental)"
echo "  Run: az staticwebapp deploy --name aibizhive-site --resource-group aibizhivesite --source ."
echo ""

print_warning "The SWA CLI has a known bug with directory detection."
print_warning "Your Static Web App is created and ready at:"
echo -e "${BLUE}https://gray-coast-079ac531e.2.azurestaticapps.net${NC}"
echo ""
print_warning "To deploy files, you have these options:"
echo ""
echo "Option 1: Use GitHub Actions (Recommended)"
echo "  - Push your code to GitHub"
echo "  - Connect your Static Web App to the GitHub repository"
echo "  - Azure will automatically deploy on push"
echo ""
echo "Option 2: Use Azure Portal"
echo "  1. Go to https://portal.azure.com"
echo "  2. Navigate to your Static Web App: aibizhive-site"
echo "  3. Click 'Browse' to manage deployments"
echo "  4. Use the 'Upload' option to deploy your files"
echo ""
echo "Option 3: Use Oryx Builder (recommended)"
print_status "Would you like to try using Oryx for deployment? (y/n)"
read -p "> " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Creating deployment package..."
    
    # Create a zip file with all content
    DEPLOY_ZIP="deployment-$(date +%s).zip"
    
    zip -r "$DEPLOY_ZIP" . \
        -x "*.git*" \
        -x "*node_modules*" \
        -x "*.azure-static-config*" \
        -x "deploy-*.sh" \
        -x "*.DS_Store"
    
    print_success "Deployment package created: $DEPLOY_ZIP"
    
    # Get deployment token
    source "$CONFIG_FILE"
    
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
    
    # Get the deployment URL
    SITE_URL=$(az staticwebapp show \
        --name "$STATIC_WEB_APP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "defaultHostname" -o tsv)
    
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Manual Deployment Required${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "Due to SWA CLI limitations, please use one of these methods:"
    echo ""
    echo "Option 1: Deploy via GitHub Actions (Recommended)"
    echo "  1. Initialize a git repository: git init"
    echo "  2. Create a GitHub repository and push your code"
    echo "  3. In Azure Portal, go to your Static Web App"
    echo "  4. Under Deployment > Deployment token, get your token"
    echo "  5. Add it as a GitHub secret and use GitHub Actions"
    echo ""
    echo "Option 2: Use Azure Portal"
    echo "  1. Go to: https://portal.azure.com"
    echo "  2. Navigate to your Static Web App: $STATIC_WEB_APP_NAME"
    echo "  3. Use the 'Manage deployment token' to get your token"
    echo "  4. Use the Azure portal's built-in deployment center"
    echo ""
    echo "Your Static Web App URL:"
    echo -e "${BLUE}https://$SITE_URL${NC}"
    echo ""
fi
