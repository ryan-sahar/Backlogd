# GitHub Setup Guide

This guide will help you create a **private** GitHub repository to protect your code.

## Why Private?

- ✅ **Protect your code**: Keep your intellectual property safe
- ✅ **Control access**: Only you (and people you invite) can see it
- ✅ **Future-proof**: Perfect if you plan to commercialize later
- ✅ **Professional**: Many developers keep their work-in-progress code private

## Step-by-Step Instructions

### Step 1: Create a GitHub Account (if you don't have one)

1. Go to [github.com](https://github.com)
2. Click "Sign up" in the top right
3. Follow the prompts to create your account

### Step 2: Create a New Private Repository

1. **Click the "+" icon** in the top right corner of GitHub
2. Select **"New repository"**
3. Fill out the form:
   - **Repository name**: `backlogd` (or `backlog-d` if that's taken)
   - **Description**: "iOS app for tracking game backlogs - class project"
   - **Visibility**: 
     - ⚠️ **IMPORTANT**: Select **"Private"** (this keeps your code secret!)
   - **DO NOT** check "Initialize with README" (we already have one)
   - **DO NOT** add .gitignore or license (we already have them)
4. Click **"Create repository"**

### Step 3: Connect Your Local Project to GitHub

After creating the repo, GitHub will show you commands. **Don't run them yet!** Instead, follow these steps:

#### Option A: If you haven't committed anything yet
(Ignore this - you already have commits)

#### Option B: If you already have commits (your situation)

Run these commands in your terminal (I'll help you with this):

```bash
# Make sure you're in the project directory
cd "/Users/ryansahar/Documents/Xcode/Backlog'd"

# Add the GitHub repository as a remote
git remote add origin https://github.com/YOUR_USERNAME/backlogd.git

# Push your code to GitHub
git push -u origin main
```

Replace `YOUR_USERNAME` with your actual GitHub username!

### Step 4: Verify It's Private

1. Go to your repository page on GitHub
2. Check the top right - it should say **"Private"** (not "Public")
3. If it says "Public", you can change it:
   - Go to **Settings** → **General**
   - Scroll down to **"Danger Zone"**
   - Click **"Change visibility"** → **"Make private"**

## Important Security Notes

✅ **Already Protected:**
- `GoogleService-Info.plist` - Contains Firebase credentials (ignored by git)
- `Services/APIKeys.swift` - Contains your RAWG API key (ignored by git)

✅ **Your code is safe:**
- Private repos can only be seen by you (and collaborators you invite)
- No one can copy your code without access
- You can make it public later if you want (or keep it private forever)

## Getting the Repository URL for RAWG API Application

Once your repo is created, you can use this URL:
```
https://github.com/YOUR_USERNAME/backlogd
```

Replace `YOUR_USERNAME` with your actual GitHub username!

## Need Help?

If you run into any issues, I can help you troubleshoot. Just let me know what step you're on!

