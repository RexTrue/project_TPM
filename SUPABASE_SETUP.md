# Supabase Setup

Proyek ini sudah mendukung penyimpanan data ke Supabase secara remote.

## Langkah-langkah

1. Buka Supabase project Anda.
2. Project baru: jalankan `supabase_schema.sql` di SQL Editor.
3. Project lama: jalankan `supabase_migration_v10.sql` (menambah tabel `feedbacks` + index badge).
   - Otomatis via psql: isi `SUPABASE_DB_URL` di `.env`, lalu `.\run_supabase_migration.ps1`
4. Jalankan aplikasi dengan Supabase backend:
   ```powershell
   .\run_supabase.ps1
   ```

## Keterangan

- `lib/core/constants/app_constants.dart` sekarang default backend-nya `supabase`.
- `run_supabase.ps1` menjalankan `flutter pub get` lalu app dengan `DATABASE_BACKEND=supabase`.
- Jika Supabase tidak tersedia, app akan fallback ke SQLite / memory sesuai implementasi data source.
