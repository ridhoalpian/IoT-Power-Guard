# Cloud Functions for Notifications

## Classification alert via FCM

Function `classifyDeviceMonitoring` memantau perubahan monitoring:

`device/{deviceId}/monitoring`

Saat monitoring berubah, function memanggil endpoint KNN Render:

`https://hetrack-knn.onrender.com/predict`

Payload prediksi memakai 2 fitur sesuai model terbaru:

`features: [voltage, current]`

Lalu hasilnya ditulis ke canonical path:

`device/{deviceId}/knn/classification`

Function `notifyClassificationChange` memantau canonical path tersebut. Jika
nilainya berubah ke `waspada` atau `boros`, function akan mengambil token dari:

`iot_power_guard/notification_tokens/{encodedToken}`

lalu mengirim Firebase Cloud Messaging ke semua token terdaftar.

State dedupe disimpan di:

`iot_power_guard/classification_alerts/{deviceId}`

Channel Android yang dipakai:

- `waspada_channel` untuk klasifikasi Waspada
- `boros_channel` untuk klasifikasi Boros

Di sisi app, local notification untuk klasifikasi tidak lagi dipicu langsung dari
listener realtime agar tidak dobel dengan FCM. Snackbar di dashboard tetap
ditampilkan sebagai feedback saat user sedang membuka halaman Home. App tidak
lagi memanggil endpoint Render atau menulis hasil klasifikasi ke RTDB.

## Offline alert via FCM

Function `notifyOfflineDevices` berjalan terjadwal setiap 1 menit. Function ini
membaca:

`device/{deviceId}`

lalu menghitung status offline dari `connection/status` dan fallback
`last_seen`. Saat perangkat baru masuk offline, function mengambil token dari:

`iot_power_guard/notification_tokens/{encodedToken}`

lalu mengirim Firebase Cloud Messaging ke semua token terdaftar.

State dedupe disimpan di:

`iot_power_guard/offline_alerts/{deviceId}`

Channel Android yang dipakai:

- `device_offline_channel` untuk perangkat offline

## Yang dikerjakan app

App menyimpan token FCM ke:

`iot_power_guard/notification_tokens/{encodedToken}`

Saat app sedang foreground, payload FCM `type=device_offline` tetap ditampilkan
ulang lewat local notification supaya channel dan tampilan Android konsisten.
Listener local offline lama tidak lagi diinisialisasi setelah login agar tidak
ada notifikasi ganda.

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

- `functions/index.js` adalah backend untuk klasifikasi KNN, notifikasi
  klasifikasi, dan notifikasi offline via FCM.
- Deploy Cloud Function diperlukan agar offline notification via FCM bekerja
  saat app background atau terminated.
- `notifyOfflineDevices` memakai Cloud Scheduler. Jika project Firebase masih
  plan Spark dan Scheduler tidak tersedia, gunakan alternatif worker backend di
  bawah.

## Alternatif backend non-Scheduler

Jika Anda butuh offline notification tanpa Cloud Scheduler, opsi yang paling
masuk akal adalah worker backend eksternal yang selalu hidup.

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
4. Jika ingin deploy function offline saja:
   `firebase deploy --only functions:notifyOfflineDevices`

## Struktur repo

- Konfigurasi Firebase ada di root repo:
  `firebase.json` dan `.firebaserc`
- Source Cloud Functions ada di folder:
  `functions/`
- Jalankan command Firebase dari root repo agar config yang dipakai konsisten.

## Catatan

- Tanpa deploy function atau worker backend, tidak ada server yang bisa
  mengirim push offline saat app ditutup penuh/terminated.
- Karena `notifyOfflineDevices` berjalan setiap 1 menit, notifikasi offline bisa
  terlambat sampai sekitar 1 menit walaupun threshold offline app adalah 20
  detik.
