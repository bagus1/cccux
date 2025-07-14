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
echo "Don't forget to run 'bundle install' to install the gem" 