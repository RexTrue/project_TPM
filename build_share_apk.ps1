$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}

$requiredVariables = 'GEMINI_API_KEY', 'SUPABASE_URL', 'SUPABASE_ANON_KEY'
foreach ($variable in $requiredVariables) {
  if (-not [Environment]::GetEnvironmentVariable($variable, 'Process')) {
    Write-Host "Missing $variable. Add it to the local .env file first."
    exit 1
  }
}

flutter build apk --debug `
  --dart-define=DATABASE_BACKEND=supabase `
  --dart-define=GEMINI_API_KEY=$env:GEMINI_API_KEY `
  --dart-define=GEMINI_MODEL=gemini-2.5-flash `
  --dart-define=SUPABASE_URL=$env:SUPABASE_URL `
  --dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY

if ($LASTEXITCODE -eq 0) {
  Write-Host 'APK ready: build\app\outputs\flutter-apk\app-debug.apk'
}
