#!/bin/bash

echo "🚀 Setting up Git for your Echotales project..."
echo ""

# Initialize git if not already done
if [ ! -d .git ]; then
    echo "📦 Initializing Git repository..."
    git init
    git branch -M main
else
    echo "✅ Git already initialized"
fi

# Add all files
echo "📁 Adding files to Git..."
git add .

# Create first commit
echo "💾 Creating initial commit..."
git commit -m "Initial commit - Echotales AI Reading App

Features:
- iOS app with Voice Recorder and Book Reader tabs
- Firebase integration for book storage
- ElevenLabs voice cloning integration
- Web admin panel for managing books
- React web app"

echo ""
echo "✅ Local Git repository ready!"
echo ""
echo "📤 Next steps:"
echo "1. Go to https://github.com/new"
echo "2. Create a new repository named 'echotales'"
echo "3. DON'T initialize with README, .gitignore, or license"
echo "4. Copy the repository URL (it will look like: https://github.com/YOUR_USERNAME/echotales.git)"
echo "5. Run these commands:"
echo ""
echo "   git remote add origin YOUR_REPOSITORY_URL"
echo "   git push -u origin main"
echo ""
