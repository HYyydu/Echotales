#!/bin/bash

echo "🚀 Echotales Backend Deployment Script"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="echotales-d23cc"
SERVICE_NAME="echotales-backend"
REGION="us-central1"

echo -e "${YELLOW}📝 Step 1: Setting Google Cloud project...${NC}"
gcloud config set project $PROJECT_ID

echo ""
echo -e "${YELLOW}🔍 Step 2: Checking if required files exist...${NC}"
if [ ! -f "firebase-service-account.json" ]; then
    echo -e "${RED}❌ Error: firebase-service-account.json not found!${NC}"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Error: .env file not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All required files found${NC}"

echo ""
echo -e "${YELLOW}📦 Step 3: Reading environment variables...${NC}"
source .env
if [ -z "$ELEVENLABS_API_KEY" ]; then
    echo -e "${RED}❌ Error: ELEVENLABS_API_KEY not set in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Environment variables loaded${NC}"

echo ""
echo -e "${YELLOW}☁️  Step 4: Enabling required Google Cloud APIs...${NC}"
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

echo ""
echo -e "${YELLOW}🏗️  Step 5: Deploying to Cloud Run...${NC}"
echo "This may take 3-5 minutes..."
echo ""

gcloud run deploy $SERVICE_NAME \
  --source . \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars="ELEVENLABS_API_KEY=$ELEVENLABS_API_KEY,ELEVENLABS_BASE_URL=$ELEVENLABS_BASE_URL,NODE_ENV=production" \
  --memory=512Mi \
  --cpu=1 \
  --timeout=300 \
  --max-instances=10 \
  --min-instances=0

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo ""
    echo -e "${YELLOW}🔗 Getting your service URL...${NC}"
    SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format='value(status.url)')
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}🎉 Your backend is live at:${NC}"
    echo -e "${GREEN}$SERVICE_URL${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "1. Test the health endpoint:"
    echo "   curl $SERVICE_URL/health"
    echo ""
    echo "2. Update your iOS app Config.plist:"
    echo "   <key>BACKEND_URL</key>"
    echo "   <string>$SERVICE_URL</string>"
    echo ""
    echo "3. Rebuild and test your iOS app"
    echo ""
else
    echo -e "${RED}❌ Deployment failed. Please check the errors above.${NC}"
    exit 1
fi

