# Terapkan migrasi Supabase v10 (feedbacks + badge unique index).
# Butuh SUPABASE_DB_URL di .env, contoh:
# SUPABASE_DB_URL=postgresql://postgres.[ref]:[PASSWORD]@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres

$envFile = Join-Path $PSScriptRoot '.env'
if (Test-Path $envFile) {
  Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
      [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), 'Process')
    }
  }
}

$migrationFile = Join-Path $PSScriptRoot 'supabase_migration_v10.sql'
if (-not (Test-Path $migrationFile)) {
  Write-Error "File migrasi tidak ditemukan: $migrationFile"
  exit 1
}

if ($env:SUPABASE_URL -match 'https://([^.]+)\.supabase\.co') {
  $projectRef = $Matches[1]
  Write-Host "Supabase project: $projectRef"
  Write-Host "SQL Editor: https://supabase.com/dashboard/project/$projectRef/sql/new"
}

if ($env:SUPABASE_DB_URL) {
  $psql = Get-Command psql -ErrorAction SilentlyContinue
  if (-not $psql) {
    Write-Host "psql tidak ditemukan. Install PostgreSQL client atau jalankan SQL manual."
    exit 1
  }

  Write-Host "Menjalankan migrasi via psql..."
  & psql $env:SUPABASE_DB_URL -f $migrationFile
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Migrasi Supabase v10 selesai."
    exit 0
  }

  Write-Error "Migrasi gagal. Coba jalankan SQL manual di Supabase SQL Editor."
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "SUPABASE_DB_URL belum di-set di .env."
Write-Host "Salin isi supabase_migration_v10.sql lalu jalankan di SQL Editor Supabase."
Write-Host "Atau tambahkan SUPABASE_DB_URL ke .env (Connection string dari Dashboard > Settings > Database)."
exit 0
