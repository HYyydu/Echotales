#!/bin/bash

# Upload Books to Firebase Storage
# =================================
# 
# This script uploads EPUB files to Firebase Storage
# 
# Prerequisites:
#   1. Install Firebase CLI: npm install -g firebase-tools
#   2. Install Google Cloud SDK (for gsutil)
#   3. Login: firebase login
#
# Usage:
#   ./upload_books.sh [options]
#
# Options:
#   --project-id      Firebase project ID (required)
#   --epubs-dir       Directory containing EPUB files (default: ./Bundle Books)
#   --covers-dir      Directory containing cover images (optional)
#   --dry-run         Show what would be uploaded without uploading

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
PROJECT_ID=""
EPUBS_DIR="./Bundle Books"
COVERS_DIR=""
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project-id)
            PROJECT_ID="$2"
            shift 2
            ;;
        --epubs-dir)
            EPUBS_DIR="$2"
            shift 2
            ;;
        --covers-dir)
            COVERS_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ Error: --project-id is required${NC}"
    echo ""
    echo "Usage: ./upload_books.sh --project-id YOUR_PROJECT_ID [options]"
    echo ""
    echo "Example:"
    echo "  ./upload_books.sh --project-id my-reading-app-12345"
    exit 1
fi

# Check if directories exist
if [ ! -d "$EPUBS_DIR" ]; then
    echo -e "${RED}❌ Error: EPUBs directory not found: $EPUBS_DIR${NC}"
    exit 1
fi

# Storage bucket
BUCKET="gs://${PROJECT_ID}.appspot.com"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Firebase Storage Upload Script${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Project ID:    $PROJECT_ID"
echo "  Bucket:        $BUCKET"
echo "  EPUBs Dir:     $EPUBS_DIR"
echo "  Covers Dir:    ${COVERS_DIR:-"(not provided)"}"
echo "  Dry Run:       $DRY_RUN"
echo ""

# Check if gsutil is available
if ! command -v gsutil &> /dev/null; then
    echo -e "${RED}❌ Error: gsutil not found${NC}"
    echo ""
    echo "Please install Google Cloud SDK:"
    echo "  https://cloud.google.com/sdk/docs/install"
    echo ""
    echo "Or use Firebase CLI upload (slower):"
    echo "  firebase storage:upload FILE_PATH DESTINATION_PATH"
    exit 1
fi

# Authenticate if needed
echo -e "${YELLOW}🔐 Checking authentication...${NC}"
if ! gsutil ls "$BUCKET" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not authenticated. Please login:${NC}"
    echo ""
    gcloud auth login
    echo ""
fi

# Count files
EPUB_COUNT=$(find "$EPUBS_DIR" -name "*.epub" -type f | wc -l | tr -d ' ')
echo -e "${GREEN}📚 Found $EPUB_COUNT EPUB files${NC}"

if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
    COVER_COUNT=$(find "$COVERS_DIR" \( -name "*.jpg" -o -name "*.png" \) -type f | wc -l | tr -d ' ')
    echo -e "${GREEN}🖼️  Found $COVER_COUNT cover images${NC}"
fi

echo ""

# Dry run check
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}📋 DRY RUN - Files that would be uploaded:${NC}"
    echo ""
    echo "EPUBs → ${BUCKET}/epubs/"
    find "$EPUBS_DIR" -name "*.epub" -type f -exec basename {} \; | sort
    
    if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
        echo ""
        echo "Covers → ${BUCKET}/covers/"
        find "$COVERS_DIR" \( -name "*.jpg" -o -name "*.png" \) -type f -exec basename {} \; | sort
    fi
    
    echo ""
    echo -e "${YELLOW}ℹ️  This was a dry run. Remove --dry-run to actually upload.${NC}"
    exit 0
fi

# Confirm upload
echo -e "${YELLOW}⚠️  This will upload files to Firebase Storage.${NC}"
echo -e "${YELLOW}   Existing files with same names will be overwritten.${NC}"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Upload cancelled.${NC}"
    exit 0
fi

echo ""

# Upload EPUBs
echo -e "${BLUE}📤 Uploading EPUBs...${NC}"
echo ""

UPLOADED=0
FAILED=0

while IFS= read -r -d '' epub_file; do
    filename=$(basename "$epub_file")
    echo -n "  Uploading $filename... "
    
    if gsutil -m cp "$epub_file" "${BUCKET}/epubs/" 2>&1 | grep -q "error"; then
        echo -e "${RED}FAILED${NC}"
        ((FAILED++))
    else
        echo -e "${GREEN}✓${NC}"
        ((UPLOADED++))
    fi
done < <(find "$EPUBS_DIR" -name "*.epub" -type f -print0)

echo ""
echo -e "${GREEN}📚 EPUBs uploaded: $UPLOADED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}   Failed: $FAILED${NC}"
fi

# Upload covers if directory provided
if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
    echo ""
    echo -e "${BLUE}📤 Uploading cover images...${NC}"
    echo ""
    
    COVER_UPLOADED=0
    COVER_FAILED=0
    
    while IFS= read -r -d '' cover_file; do
        filename=$(basename "$cover_file")
        echo -n "  Uploading $filename... "
        
        if gsutil -m cp "$cover_file" "${BUCKET}/covers/" 2>&1 | grep -q "error"; then
            echo -e "${RED}FAILED${NC}"
            ((COVER_FAILED++))
        else
            echo -e "${GREEN}✓${NC}"
            ((COVER_UPLOADED++))
        fi
    done < <(find "$COVERS_DIR" \( -name "*.jpg" -o -name "*.png" \) -type f -print0)
    
    echo ""
    echo -e "${GREEN}🖼️  Covers uploaded: $COVER_UPLOADED${NC}"
    if [ $COVER_FAILED -gt 0 ]; then
        echo -e "${RED}   Failed: $COVER_FAILED${NC}"
    fi
fi

# Make files publicly readable (optional)
echo ""
read -p "Make files publicly readable? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🌐 Setting public read permissions...${NC}"
    gsutil -m acl ch -r -u AllUsers:R "${BUCKET}/epubs/*" 2>/dev/null || true
    
    if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
        gsutil -m acl ch -r -u AllUsers:R "${BUCKET}/covers/*" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ Files are now publicly readable${NC}"
    echo -e "${YELLOW}⚠️  Note: It's better to use Firebase Storage Rules for access control${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN}✅ Upload complete!${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "📊 Summary:"
echo "  EPUBs uploaded:     $UPLOADED"
if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
    echo "  Covers uploaded:    $COVER_UPLOADED"
fi
echo ""
echo "🔗 Access files at:"
echo "  ${BUCKET}/epubs/"
if [ -n "$COVERS_DIR" ] && [ -d "$COVERS_DIR" ]; then
    echo "  ${BUCKET}/covers/"
fi
echo ""
echo "🚀 Next steps:"
echo "  1. Update cloud_books_catalog.json with correct storageUrl paths"
echo "  2. Configure Firebase Storage Rules"
echo "  3. Test downloading in your app"
echo ""

