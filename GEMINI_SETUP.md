# Gemini API Setup

Panduan ini memakai Gemini API dari Google AI Studio. Menurut dokumentasi resmi Google AI for Developers, API key dapat dibuat di Google AI Studio dan free tier tersedia untuk testing dengan rate limit lebih rendah. Jangan menaruh API key langsung di source code.

Sumber resmi:
- https://ai.google.dev/gemini-api/docs/api-key
- https://ai.google.dev/gemini-api/docs/pricing

## 1. Buat API Key Gratis

1. Buka https://aistudio.google.com/apikey
2. Login dengan akun Google.
3. Klik `Create API key`.
4. Pilih project yang ada atau buat project baru.
5. Copy API key yang dibuat.

Free tier cocok untuk pengembangan dan demo. Untuk production, cek limit dan billing di halaman pricing resmi.

## 2. Jalankan App Dengan API Key

Android phone:

```bash
flutter run -d 29a7fa8e --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU
```

Chrome:

```bash
flutter run -d chrome --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU
```

Build APK debug:

```bash
flutter build apk --debug --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU
```

Build APK release:

```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=ISI_API_KEY_KAMU
```

## 3. File Yang Membaca Key

`lib/core/constants/api_constants.dart` membaca key dari:

```dart
String.fromEnvironment('GEMINI_API_KEY')
```

Jika key kosong, chatbot akan menampilkan pesan bahwa Gemini belum dikonfigurasi.

## 4. Model

Project ini memakai:

```dart
gemini-2.5-flash
```

Model ini berhasil diuji dengan API key EduFun dan mendukung `generateContent`. Jika ingin mengganti model, ubah `geminiModel` di `lib/core/constants/api_constants.dart`.

## 5. Catatan Keamanan

- Jangan commit API key ke Git.
- Jangan hardcode API key di `api_constants.dart`.
- Jika key pernah terlanjur bocor, hapus key tersebut di Google AI Studio dan buat key baru.
- Untuk production, sebaiknya request AI diproxy lewat backend agar API key tidak tertanam di aplikasi mobile.

## 6. Troubleshooting

- `Gemini API belum dikonfigurasi`: jalankan app dengan `--dart-define=GEMINI_API_KEY=...`.
- `Invalid API Key`: pastikan key aktif dan disalin lengkap.
- `Rate limit exceeded`: tunggu beberapa saat atau gunakan tier berbayar.
- Tidak ada internet: chatbot akan gagal memanggil Gemini.
