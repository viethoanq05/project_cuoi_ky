# Supabase Configuration Script for Flutter
# Usage: .\run_app.ps1

# Replace these with your actual Supabase credentials
$SUPABASE_URL = "https://your-project-id.supabase.co"
$SUPABASE_ANON_KEY = "your-anon-key-here"
$SUPABASE_STORAGE_BUCKET = "product-images"

# Check if values are configured
if ($SUPABASE_URL -eq "https://your-project-id.supabase.co" -or $SUPABASE_ANON_KEY -eq "your-anon-key-here") {
    Write-Host "ERROR: Please configure SUPABASE_URL and SUPABASE_ANON_KEY in this script" -ForegroundColor Red
    Write-Host "`nSteps to get your credentials:" -ForegroundColor Yellow
    Write-Host "1. Go to https://supabase.com/dashboard" -ForegroundColor Cyan
    Write-Host "2. Select your project" -ForegroundColor Cyan
    Write-Host "3. Go to Settings > API" -ForegroundColor Cyan
    Write-Host "4. Copy the Project URL and anon (public) key" -ForegroundColor Cyan
    exit 1
}

Write-Host "Running Flutter app with Supabase configuration..." -ForegroundColor Green
Write-Host "SUPABASE_URL: $SUPABASE_URL" -ForegroundColor Cyan
Write-Host "SUPABASE_STORAGE_BUCKET: $SUPABASE_STORAGE_BUCKET" -ForegroundColor Cyan

# Run flutter with dart-define
flutter run `
    --dart-define=SUPABASE_URL=$SUPABASE_URL `
    --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY `
    --dart-define=SUPABASE_STORAGE_BUCKET=$SUPABASE_STORAGE_BUCKET
