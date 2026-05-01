# Cloud Functions for Offline Notifications

Offline notification sekarang berjalan langsung dari aplikasi mobile lewat
listener RTDB + local notification. Cloud Functions di folder ini tidak lagi
dibutuhkan untuk fitur offline notification standar.

## Yang dikerjakan app

App memonitor `device/*/last_seen` secara realtime, menandai device offline
setelah 20 detik tidak ada heartbeat, lalu menampilkan local notification saat
ada device yang baru masuk status offline.

Jika Anda masih ingin memakai FCM untuk use case lain, app tetap bisa menyimpan
token ke:

`iot_power_guard/notification_tokens/{encodedToken}`

Tetapi token itu tidak lagi dipakai untuk offline notification default.

## Yang harus ditulis device atau backend

Agar notifikasi benar-benar merepresentasikan `mode offline`, setiap device perlu
menulis field koneksi yang eksplisit ke RTDB:

`device/{deviceId}/connection/status`
Nilai: `online` atau `offline`

`device/{deviceId}/connection/last_changed`
Nilai: epoch milliseconds, epoch seconds, atau ISO datetime

Cloud Function memprioritaskan `connection/status`, lalu fallback ke `last_seen`
jika device mati mendadak atau tidak sempat menulis status offline.

`last_seen` juga bisa berupa epoch seconds, epoch milliseconds, ISO datetime,
atau nilai millis 32-bit dari device yang nanti di-unwarp relatif terhadap waktu
server/`monitoring.timestamp`.

## Status folder ini

- `functions/index.js` adalah implementasi backend opsional lama.
- Deploy Cloud Function tidak diperlukan agar offline notification di app
  bekerja.
- Jika project Firebase masih plan Spark, fitur offline notification tetap
  berjalan karena sekarang tidak memakai Cloud Scheduler.

## Alternatif backend non-Scheduler

Jika Anda nanti butuh offline notification yang tetap akurat saat app
background/terminated, opsi yang paling masuk akal adalah worker backend
eksternal yang selalu hidup, bukan Cloud Scheduler.

Rancangan yang disarankan:

- Jalankan worker Node.js kecil di Railway, Render, Fly.io, VPS, atau server lain.
- Worker subscribe ke RTDB path `device/` atau polling ringan per beberapa detik.
- Worker hitung status offline dari `connection/status` dan fallback `last_seen`.
- Worker kirim FCM via Firebase Admin SDK saat device baru masuk offline.
- Worker simpan state dedupe di RTDB, misalnya:
  `iot_power_guard/offline_alerts/{deviceId}`
- Saat device online lagi, worker reset state alert agar transisi offline berikutnya
  bisa mengirim notif lagi.

Keuntungan:

- Tidak butuh Cloud Scheduler.
- Tidak tergantung app sedang terbuka.
- Deteksi lebih akurat daripada listener di sisi app.

Konsekuensi:

- Tetap butuh backend yang selalu hidup di luar app.
- Perlu service account Firebase yang aman di server tersebut.
- Biaya pindah dari Firebase Scheduler ke hosting worker eksternal.

## Deploy

1. Install Firebase CLI
2. Login: `firebase login`
3. Dari root repo, jalankan deploy: `firebase deploy --only functions`
4. Jika ingin deploy function ini saja: `firebase deploy --only functions:notifyOfflineDevices`

## Struktur repo

- Konfigurasi Firebase ada di root repo:
  `firebase.json` dan `.firebaserc`
- Source Cloud Functions ada di folder:
  `functions/`
- Jalankan command Firebase dari root repo agar config yang dipakai konsisten.

## Catatan

- Tanpa backend, offline notification hanya andal saat proses app masih hidup.
  Untuk menghindari false positive, listener offline sekarang hanya aktif saat
  app foreground/resumed.
- Jika app ditutup penuh/terminated oleh sistem, tidak ada server yang bisa
  mengirim push offline.
- Jika Anda tetap memakai FCM untuk use case lain, payload foreground masih bisa
  ditampilkan lagi lewat local notification.
