# Azure Static Web App Deployment Guide

## Current Status

Your Azure Static Web App has been created successfully:
- **Resource Group**: aibizhivesite
- **Static Web App Name**: aibizhive-site
- **Location**: West US 2
- **URL**: https://gray-coast-079ac531e.2.azurestaticapps.net

## Deployment Issue

The Azure Static Web Apps CLI (SWA CLI) has a known bug that prevents direct deployment from the command line. The error "Current directory cannot be identical to or contained within artifact folders" is a persistent issue with the CLI tool.

## Recommended Deployment Method: GitHub Actions

### Step 1: Initialize Git Repository

```bash
cd "/Users/user/Desktop/aibizhive site"
git init
git add .
git commit -m "Initial commit"
```

### Step 2: Create GitHub Repository

1. Go to https://github.com/new
2. Create a new repository (e.g., "aibizhive-site")
3. **Do NOT** initialize with README, .gitignore, or license

### Step 3: Push Your Code

```bash
git remote add origin https://github.com/YOUR_USERNAME/aibizhive-site.git
git branch -M main
git push -u origin main
```

### Step 4: Get Your Deployment Token

```bash
az staticwebapp secrets list \
    --name aibizhive-site \
    --resource-group aibizhivesite \
    --query "properties.apiKey" -o tsv
```

Copy the output token.

### Step 5: Add GitHub Secret

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AZURE_STATIC_WEB_APPS_API_TOKEN`
5. Value: Paste the deployment token from Step 4
6. Click **Add secret**

### Step 6: Deploy

The GitHub Actions workflow (`.github/workflows/azure-static-web-apps.yml`) is already configured. Simply push any changes to the `main` branch:

```bash
git add .
git commit -m "Deploy to Azure"
git push
```

GitHub Actions will automatically build and deploy your site to Azure.

## Alternative Method: Azure Portal

If you prefer not to use GitHub:

1. Go to https://portal.azure.com
2. Navigate to **Static Web Apps** → **aibizhive-site**
3. Click on **Manage deployment token** to get your token
4. Use the Azure Portal's deployment center to upload your files manually

## Verifying Deployment

After deployment, visit your site at:
https://gray-coast-079ac531e.2.azurestaticapps.net

## Useful Commands

### View Static Web App Details
```bash
az staticwebapp show \
    --name aibizhive-site \
    --resource-group aibizhivesite
```

### List Deployment Tokens
```bash
az staticwebapp secrets list \
    --name aibizhive-site \
    --resource-group aibizhivesite
```

### Delete Static Web App
```bash
az staticwebapp delete \
    --name aibizhive-site \
    --resource-group aibizhivesite
```

### Delete Resource Group (removes everything)
```bash
az group delete --name aibizhivesite
```

## Configuration Files

- **staticwebapp.config.json**: Azure Static Web Apps configuration with routing rules, caching, and security headers
- **.github/workflows/azure-static-web-apps.yml**: GitHub Actions workflow for automated deployment
- **.azure-static-config**: Local configuration file with Azure resource details

## Troubleshooting

### SWA CLI Error
If you encounter "Current directory cannot be identical to or contained within artifact folders", this is a known bug with the SWA CLI. Use GitHub Actions instead.

### Deployment Not Working
1. Verify your GitHub secret is named exactly: `AZURE_STATIC_WEB_APPS_API_TOKEN`
2. Check the Actions tab in your GitHub repository for deployment logs
3. Ensure your deployment token is valid (regenerate if needed)

### Site Not Loading
1. Wait 2-3 minutes after deployment for changes to propagate
2. Clear your browser cache
3. Check the Azure Portal for deployment status

## Support

For Azure Static Web Apps documentation, visit:
https://docs.microsoft.com/en-us/azure/static-web-apps/
