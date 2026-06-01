# Run the EduFun app with Supabase backend enabled.
# Ensure you have Flutter installed and the current directory is the project root.

$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}

if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
  Write-Host "Set SUPABASE_URL and SUPABASE_ANON_KEY first."
  Write-Host "Example:"
  Write-Host '$env:SUPABASE_URL="https://your-project.supabase.co"'
  Write-Host '$env:SUPABASE_ANON_KEY="your_publishable_or_anon_key"'
  exit 1
}

flutter pub get
flutter run `
  --dart-define=DATABASE_BACKEND=supabase `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY `
  --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY `
  --dart-define=GEMINI_MODEL=gemini-2.5-flash
