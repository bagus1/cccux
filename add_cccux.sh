#!/bin/bash

# Script to add cccux gem to Gemfile in current directory
# Usage: ../cccux/add_cccux.sh

# Check if we're in a Rails project directory
if [ ! -f "Gemfile" ]; then
    echo "Error: No Gemfile found in current directory"
    echo "Make sure you're in a Rails project directory"
    exit 1
fi

# Check if cccux gem is already in Gemfile
if grep -q "gem 'cccux'" Gemfile; then
    echo "cccux gem is already in Gemfile"
    exit 0
fi

# Add the gem line to Gemfile
echo "gem 'cccux', path: '../cccux'" >> Gemfile

echo "Added 'gem \"cccux\", path: \"../cccux\"' to Gemfile"
echo "Installing CCCUX gem..."

# Run bundle install
bundle install

if [ $? -eq 0 ]; then
    echo "✅ CCCUX gem installed successfully"
else
    echo "❌ Failed to install CCCUX gem"
    echo "💡 Try running 'bundle install' manually"
    exit 1
fi

echo ""
echo "🔧 Setting up CCCUX authorization..."
echo "===================================="

# Run CCCUX setup
bundle exec rake cccux:setup

if [ $? -eq 0 ]; then
    echo "✅ CCCUX setup completed successfully"
else
    echo "❌ CCCUX setup failed"
    exit 1
fi

echo ""
echo "🔧 Initializing MegaBar with authorization..."
echo "============================================="

# Run MegaBar engine init
bundle exec rake mega_bar:engine_init

if [ $? -eq 0 ]; then
    echo "✅ MegaBar engine initialized successfully"
else
    echo "❌ MegaBar engine initialization failed"
    exit 1
fi

echo ""
echo "🔧 Creating Mega Role for MegaBar permissions..."
echo "==============================================="

# Create Mega Role
bundle exec rake cccux:megabar:create_mega_role

if [ $? -eq 0 ]; then
    echo "✅ Mega Role created with full MegaBar permissions"
else
    echo "❌ Mega Role creation failed"
    exit 1
fi

echo ""
echo "🎉 Complete setup finished!"
echo "=========================="
echo ""
echo "🚀 Starting Rails server..."
echo "   Visit admin interfaces:"
echo "   - MegaBar: http://localhost:3000/mega-bar"
echo "   - CCCUX: http://localhost:3000/cccux"
echo ""
echo "💡 Users with 'Mega Role' have full MegaBar access!"
echo "   Press Ctrl+C to stop the server"
echo ""

# Start the Rails server
rails server 