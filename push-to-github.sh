#!/bin/bash

# Helper script to push to GitHub after repository creation

echo "===================================="
echo "Push to GitHub Helper"
echo "===================================="
echo ""

# Check if remote exists
if git remote | grep -q origin; then
    echo "Remote 'origin' already configured:"
    git remote -v
else
    echo "No remote configured. Please provide your GitHub username:"
    read -p "GitHub username: " username
    
    if [ -z "$username" ]; then
        echo "Username cannot be empty!"
        exit 1
    fi
    
    echo "Adding remote repository..."
    git remote add origin "https://github.com/$username/makeRetro.git"
    echo "Remote added: https://github.com/$username/makeRetro.git"
fi

echo ""
echo "Pushing to GitHub..."
echo "(You may be prompted for your GitHub credentials)"
echo ""

# Push to GitHub
if git push -u origin master; then
    echo ""
    echo "===================================="
    echo "Success! Code pushed to GitHub"
    echo "===================================="
    echo ""
    echo "Your repository is now available at:"
    git remote -v | grep origin | head -1 | awk '{print $2}' | sed 's/\.git$//'
    echo ""
    echo "Next steps:"
    echo "1. Visit your repository on GitHub"
    echo "2. Add a description and topics (retro, mac-os-9, qemu, emulation)"
    echo "3. Consider adding a LICENSE file"
    echo "4. Share with the retro computing community!"
else
    echo ""
    echo "Push failed. Common issues:"
    echo "1. Repository doesn't exist on GitHub - create it first"
    echo "2. Authentication failed - check your credentials"
    echo "3. Repository name mismatch - verify the URL"
    echo ""
    echo "To try again with a different repository name:"
    echo "  git remote set-url origin https://github.com/USERNAME/REPO_NAME.git"
fi
