#!/bin/bash

# Supabase Configuration Script for Flutter
# Usage: bash run_app.sh

# Replace these with your actual Supabase credentials
SUPABASE_URL="https://your-project-id.supabase.co"
SUPABASE_ANON_KEY="your-anon-key-here"
SUPABASE_STORAGE_BUCKET="product-images"

# Check if values are configured
if [ "$SUPABASE_URL" = "https://your-project-id.supabase.co" ] || [ "$SUPABASE_ANON_KEY" = "your-anon-key-here" ]; then
    echo -e "\033[0;31mERROR: Please configure SUPABASE_URL and SUPABASE_ANON_KEY in this script\033[0m"
    echo -e "\n\033[0;33mSteps to get your credentials:\033[0m"
    echo -e "\033[0;36m1. Go to https://supabase.com/dashboard\033[0m"
    echo -e "\033[0;36m2. Select your project\033[0m"
    echo -e "\033[0;36m3. Go to Settings > API\033[0m"
    echo -e "\033[0;36m4. Copy the Project URL and anon (public) key\033[0m"
    exit 1
fi

echo -e "\033[0;32mRunning Flutter app with Supabase configuration...\033[0m"
echo -e "\033[0;36mSUPABASE_URL: $SUPABASE_URL\033[0m"
echo -e "\033[0;36mSUPABASE_STORAGE_BUCKET: $SUPABASE_STORAGE_BUCKET\033[0m"

# Run flutter with dart-define
flutter run \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=SUPABASE_STORAGE_BUCKET="$SUPABASE_STORAGE_BUCKET"
