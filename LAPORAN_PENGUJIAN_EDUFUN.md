# LAPORAN PENGUJIAN APLIKASI EDUFUN BERDASARKAN SOFTWARE TESTING LIFE CYCLE (STLC)

## BAB I PENDAHULUAN

1.1 Latar Belakang

Aplikasi EduFun dikembangkan menggunakan Flutter untuk mendukung pembelajaran interaktif. Pengujian perangkat lunak diperlukan untuk memastikan fitur autentikasi, kuis, dan keamanan berjalan sesuai harapan.

1.2 Rumusan Masalah

- Bagaimana melakukan white-box testing pada validator dan hash password?  
- Bagaimana melakukan black-box testing pada validasi input dan perhitungan skor?  
- Bagaimana melakukan security testing terhadap hashing dan input validation?  
- Bagaimana mengukur performa dengan load dan stress testing?

1.3 Tujuan Penelitian

- Melakukan uji unit pada validasi email, password, dan password hashing.  
- Menguji fungsi model skor kuis tanpa melihat implementasi internal.  
- Menilai kestabilan validator dan hashing pada beban tinggi.

1.4 Manfaat Penelitian

- Menemukan bug pada logika validasi dan hashing.  
- Menilai kekuatan pengujian otomatis untuk fitur kritis.  
- Memberikan dasar pengujian STLC pada aplikasi Flutter.

1.5 Ruang Lingkup Penelitian

Pengujian mencakup: validator email, validator password, password hashing, model skor kuis, dan performa fitur tersebut.

## BAB II TINJAUAN PUSTAKA

2.1 Software Testing Life Cycle (STLC)

STLC dilakukan dengan tahapan: Requirement Analysis, Test Planning, Test Case Development, Environment Setup, Test Execution, Bug Reporting, Test Closure.

2.2 White-Box Testing

Dilakukan pada `Validators` dan `PasswordHashing` untuk menguji kondisi internal: null, format email, aturan password, dan branch hashing.

2.3 Black-Box Testing

Dilakukan pada `ScoreModel` dan validator fungsional agar output sesuai spesifikasi tanpa melihat internal kode.

2.4 Security Testing

Fokus pada kekuatan hash SHA-256, verifikasi hash, serta validasi input terhadap potensi injeksi. Kategori OWASP Mobile Top 10 yang relevan: Insecure Authentication, Insecure Data Storage, Client Code Quality.

2.5 Flutter

Flutter digunakan sebagai framework utama; pengujian dilakukan pada lapisan Dart murni sehingga dapat dijalankan dengan `flutter test`.

## BAB III METODOLOGI PENELITIAN

3.1 Metode Penelitian

Metode pengujian adalah STLC dengan fokus pada kelengkapan test case dan eksekusi otomatis.

3.2 Objek Penelitian

Objek utama adalah modul `core/utils/validators.dart`, `core/security/password_hashing.dart`, dan `data/models/score_model.dart`.

3.3 Metode Pengumpulan Data

Data diperoleh dari hasil eksekusi `flutter test`, inspeksi source code, dan analisis kondisi input-output.

3.4 Environment Pengujian

- OS: Windows 11  
- Flutter SDK: digunakan sesuai proyek  
- IDE: Visual Studio Code  
- Tools: Flutter test

3.5 Tools Pengujian

- `flutter test` untuk eksekusi unit test  
- `package:test` untuk kasus unit murni  
- `dart:crypto` / `package:crypto` untuk hash

3.6 Rancangan Pengujian

Jenis pengujian dan target:
- White-box: `Validators.validateEmail`, `Validators.validatePassword`, `PasswordHashing.hashPassword`, `PasswordHashing.verifyPassword`, model serialization
- Black-box: `Validators.validateConfirmPassword`, `Validators.validateRequired`, `ScoreModel.getPercentage`, `UserModel`/`QuizModel`/`QuizQuestionModel` output
- Integration-like provider tests: `AuthProvider.login`, `AuthProvider.register`, `AuthProvider.setPremiumStatus`, session persistence
- Repository behavior: `UserRepository.registerUser`, `UserRepository.loginUser`, `UserRepository.updateUserXP`
- Load testing: 10.000 iterasi validator email
- Stress testing: 100.000 iterasi password hashing

3.7 Test Case Pengujian

| ID | Test Case | Expected Result | Status |
|---|---|---|---|
| WB-01 | Email null | Error message | PASS |
| WB-02 | Invalid email | Validation error | PASS |
| WB-03 | Password lemah | Validation error | PASS |
| WB-04 | Hash password | 64 karakter hex | PASS |
| BB-01 | Konfirmasi password mismatch | Error | PASS |
| BB-02 | Perhitungan skor | 80% untuk 8/10 | PASS |
| BB-03 | Username validation | Error untuk nama kurang dari 3 karakter | PASS |
| BB-04 | Model serialization | Data preserve toJson/fromJson | PASS |
| BB-05 | AuthProvider login/register | Sesi persistent dan kenaikan XP | PASS |
| BB-06 | UserRepository login/register | Registrasi dan login valid | PASS |
| SEC-01 | Verifikasi hash | True/False sesuai input | PASS |
| LOAD-01 | Validator 10.000 iterasi | Stabil | PASS |
| STR-01 | Hashing 100.000 iterasi | Stabil | PASS |

## BAB IV IMPLEMENTASI DAN HASIL PENGUJIAN

4.1 White-Box Testing

### 4.1.1 Pengujian Validator Email
- Hal yang dilakukan: input null, kosong, format email salah, format valid.  
- Implementasi: `Validators.validateEmail(...)`  
- Hasil: Validator mengembalikan pesan error untuk input invalid, `null` untuk email valid.
- Analisis: Branch internal regex dan kondisi null/empty berhasil tercakup.

### 4.1.2 Pengujian Password Hashing
- Hal yang dilakukan: hashing SHA-256, verifikasi hash, panjang hash, ketahanan pada iterasi tinggi.
- Implementasi: `PasswordHashing.hashPassword(...)`, `PasswordHashing.verifyPassword(...)`  
- Hasil: Hash 64 karakter hexadecimal valid; verifikasi benar untuk password yang cocok dan false untuk yang tidak cocok.
- Analisis: SHA-256 berfungsi, tetapi tidak ada salt adaptif; ini relevan untuk rekomendasi keamanan.

### 4.1.3 Pengujian Model Serialization
- Hal yang dilakukan: `UserModel.toJson/fromJson`, `QuizModel.toJson/fromJson`, `QuizQuestionModel.toJson/fromJson`, `ScoreModel.toJson/fromJson`.
- Implementasi: round-trip JSON serialization dan deserialization.
- Hasil: Semua model mempertahankan nilai field penting dan konversi berjalan tanpa kehilangan data.
- Analisis: Struktur model aman untuk serialisasi persisten, tetapi perlu perhatikan handling boolean dan tanggal.

4.2 Black-Box Testing

### 4.2.1 Pengujian Login
- Hal yang dilakukan: validasi fungsional password/konfirmasi password.  
- Implementasi: `Validators.validateConfirmPassword(...)`, `Validators.validateRequired(...)`  
- Hasil: Input mismatch menghasilkan error; field kosong ditolak.
- Analisis: Mekanisme validasi input bekerja sesuai ekspektasi fungsi eksternal.

### 4.2.2 Pengujian Quiz
- Hal yang dilakukan: perhitungan persentase skor.  
- Implementasi: `ScoreModel.getPercentage()`  
- Hasil: 8 dari 10 menghasilkan 80%; totalQuestions 0 menghasilkan 0%.
- Analisis: Logika tingkat skor berfungsi dengan benar.

### 4.2.3 Pengujian AuthProvider dan UserRepository
- Hal yang dilakukan: registrasi user, login, logout, session persistence, premium status, pencatatan membership, dan update XP.
- Implementasi: `AuthProvider.register`, `AuthProvider.login`, `AuthProvider.logout`, `AuthProvider.setPremiumStatus`, `AuthProvider.recordMembershipPurchase`, `AuthProvider.isMentorMember`, `AuthProvider.addXp`, `UserRepository.registerUser`, `UserRepository.loginUser`, `UserRepository.updateUserXP`.
- Hasil: semua proses berhasil sesuai ekspektasi; registrasi dan login bekerja, session tersimpan di `SharedPreferences`, serta update XP sukses.
- Analisis: lapisan provider dan repository dapat berfungsi bersama tanpa error pada skenario autentikasi dasar dan persistence.

4.3 Security Testing

### 4.3.1 Hash strength
- Pengujian SHA-256 memastikan nilai hash konsisten.
- Hasil: Hash stabil, valid, dan dapat diverifikasi.
- OWASP Mapping: M2 Insecure Authentication, M7 Client Code Quality.

### 4.3.2 Input validation
- Pengujian validasi email/password mencegah input kosong dan format tidak valid.
- Hasil: Validator menolak input invalid.

### 4.3.3 Temuan keamanan kode
- Tidak ada implementasi salt pada hashing password.  
- Tidak ditemukan pengujian SSL pinning atau proteksi reverse engineering melalui unit test.

4.4 Load Testing

- Implementasi: 10.000 iterasi email validator.
- Hasil: Semua iterasi berhasil tanpa error.

4.5 Stress Testing

- Implementasi: 100.000 iterasi hashing password.
- Hasil: Semua iterasi berhasil dan hash tetap benar.

4.6 Coverage Analysis

Analisis dilakukan pada modul yang diuji; cakupan unit test pada branch-validator dan hashing mencakup kondisi dasar. Tambahan pengujian model dan provider meningkatkan cakupan ke:
- `UserModel`, `QuizModel`, `QuizQuestionModel`, `ScoreModel` serialization
- `AuthProvider` state persistence dan session lifecycle
- `UserRepository` login/register dan XP update

4.7 Keterbatasan Pengujian

- Pengujian unit tidak mencakup UI end-to-end.  
- Tidak ada pengujian backend produksi atau multi-user konkuren.  
- Security testing statis hanya di lapisan kode Dart.

## BAB V PENUTUP

5.1 Kesimpulan

- White-box testing berhasil pada validator dan hashing.  
- Black-box testing berhasil pada validasi fungsional dan perhitungan skor.  
- Load dan stress testing dasar menunjukkan kestabilan modul validator dan hashing.  
- Ditemukan area keamanan: penggunaan SHA-256 tanpa salt adaptif.

5.2 Saran

- Gunakan bcrypt atau Argon2 untuk hashing password.  
- Tambahkan salt dan proteksi storage sensitif.  
- Tambahkan pengujian UI/integrasi dan pengujian keamanan mobile dengan Burp/MobSF.  
- Terapkan obfuscation dan SSL pinning untuk rilisan produksi.

## Lampiran

- Lampiran C – Source Code Pengujian: `test/stlc_test.dart`, `test/model_test.dart`, `test/auth_provider_test.dart`, `test/user_repository_test.dart`
