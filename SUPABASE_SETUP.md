# Supabase Setup

Proyek ini sudah mendukung penyimpanan data ke Supabase secara remote.

## Langkah-langkah

1. Buka Supabase project Anda.
2. Pergi ke SQL Editor dan jalankan `supabase_schema.sql` dari root proyek.
3. Jalankan aplikasi dengan Supabase backend:
   ```powershell
   .\run_supabase.ps1
   ```

## Keterangan

- `lib/core/constants/app_constants.dart` sekarang default backend-nya `supabase`.
- `run_supabase.ps1` menjalankan `flutter pub get` lalu app dengan `DATABASE_BACKEND=supabase`.
- Jika Supabase tidak tersedia, app akan fallback ke SQLite / memory sesuai implementasi data source.
