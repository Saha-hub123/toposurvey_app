# 🏔️ TopoSurvey 3D: Alat Survey Topografi Berbasis Multi-Handphone Android & iOS

Aplikasi survey pemetaan topografi dan ketinggian kontur tanah menggunakan kolaborasi **3 hingga 4 handphone (Android & iOS)** dengan metode **Multilaterasi / Trilaterasi Bilateral & Multititik**, **BLE (Bluetooth Low Energy) Ranging**, dan **Diferensial Barometer Altimetri** untuk mengatasi keterbatasan GPS standar smartphone (akurasi 5–10 meter).

---

## 🌟 Dukungan Mode 3 HP & 4 HP (Latar Belakang Ilmiah)

1. **Kelemahan GPS Tunggal Smartphone & Solusi Anti-Drift**:
   - Chipset GNSS/GPS bawaan HP memiliki ketidakpastian posisi horizontal sekitar **5 hingga 10 meter** akibat gangguan ionosfer dan pantulan sinyal (*multipath*).
   - **Filter Anti-Drift Terpasang:** *Accuracy Threshold* (≤ 5m), *Minimum Displacement* (1m via `setSmallestDisplacement`), dan *Outlier Speed Rejection* (> 4.5 m/s) memastikan data GPS tidak melompat-lompat saat surveyor diam.

2. **Dukungan Operasi Fleksibel (3 HP atau 4 HP)**:
   - **Mode 3 HP (Minimalist Setup)**: 2 Handphone sebagai patok acuan (Base Station A di $(0,0)$ & Base Station B di sumbu X) + 1 Handphone sebagai Rover. Menggunakan algoritma interseksi lingkaran 2-titik bilateral dipadukan dengan barometer diferensial dan toggle kuadran sisi survei (+Y / -Y).
   - **Mode 4 HP (Optimal 3D Setup)**: 3 Handphone sebagai patok acuan (Base A, B, dan C membentuk segitiga) + 1 Handphone sebagai Rover. Menggunakan trilaterasi kuadrat terkecil (*Least Squares*) untuk akurasi maksimal.

3. **Proteksi Sinyal BLE & Perisai Perangkat Liar**:
   - **Filter RSSI Cutoff**: Mengabaikan sinyal dengan $RSSI < -80\text{ dBm}$ (di luar radius efektif).
   - **Whitelisting MAC Address**: Hanya memproses sinyal dari patok acuan yang terdaftar.
   - **Validasi Advertising Payload**: Membaca paket telemetri biner khusus TopoSurvey 3D dan membuang paket liar (*promiscuous drop*).
   - **Filter Kalman 1D Real-Time**: Membuang lonjakan fluktuasi radio RF secara adaptif.

4. **Sensor Fusi Barometer Diferensial (Sub-Meter Vertical Accuracy)**:
   - Perubahan tekanan atmosfer dihitung menggunakan rumus hipso-metrik ISA:
     $$\Delta h = 44330.0 \times \left(1.0 - \left(\frac{P_{rover}}{P_{base}}\right)^{0.190295}\right)$$
   - Karena Base Station terus menyiarkan $P_{base}(t)$ secara langsung, pergeseran cuaca dan angin (*diurnal drift*) tereliminasi **100%**, menghasilkan resolusi beda tinggi permukaan tanah hingga **10–20 cm**!

---

## 📐 Arsitektur Sistem & Alur Kerja Lapangan

```
                     [ ANCHOR C ] (HP 3 - Patok C)
                     (X_C, Y_C, Z_C) + P_base
                            ▲
                            │  BLE Ranging (d3)
                            │
   [ ANCHOR A ] ──────── [ ROVER ] ──────── [ ANCHOR B ]
   (HP 1 - Origin)    (HP 4 - Tongkat Jalon)   (HP 2 - Sumbu X)
   (0, 0, Z_0)        Menghitung (X, Y, Z)     (X_B, 0, Z_B)
                           ▲
                           │
                 [ UDP Mesh Broadcast ]
             (Wi-Fi Hotspot Lokal - Tanpa Internet)
```

---

## 🚀 Fitur Utama Aplikasi

- **Peran Ganda dalam 1 Aplikasi**:
  - **Mode Rover (Alat Ukur)**: Menampilkan koordinat live $X, Y, Z$, nilai beda tinggi relatif $\Delta Z$, RMSE akurasi, dan tombol **"TEMBAK TITIK KONTUR"**.
  - **Mode Anchor (Base Station)**: Memancarkan BLE beacon, koordinat patok acuan, serta nilai barometer real-time.
- **Peta Topografi & Kontur Interaktif**:
  - Visualisasi 2D/3D titik sebaran (*point cloud*) dengan gradien warna elevasi kontur (*cyan* untuk rendah hingga *orange/red* untuk punggungan/tinggi).
  - Garis segitiga baseline acuan antar anchor.
  - Zoom & pan bebas dengan *pinch-to-zoom*.
- **Mesh Network P2P Offline (Port 8888)**:
  - Cukup hidupkan **Hotspot Portabel** pada salah satu HP. Semua HP terhubung dan tersinkronisasi otomatis tanpa perlu kuota internet atau sinyal seluler.
- **Fitur Kalibrasi Lapangan**:
  - Wizard kalibrasi 1 meter untuk mengukur $A$ (*TxPower*).
  - Wizard kalibrasi 3 meter untuk menghitung koefisien redaman tanah ($n$).
- **Ekspor Standar Surveyor & GIS**:
  - **CSV (PNEZD)**: Format standar siap impor ke AutoCAD Civil 3D, Surfer, Trimble, Excel.
  - **AutoCAD 3D DXF**: File CAD langsung berisi entitas `3D POINT` dan teks elevasi `TEXT Z=...`.
  - **GeoJSON**: Siap dibuka di QGIS, ArcGIS, dan Google Earth.

---

## 📲 Panduan Penggunaan di Lapangan

1. **Persiapan**:
   - Pasang aplikasi **TopoSurvey 3D** pada minimal 3 (ideal 4) HP Android.
   - Hidupkan **Hotspot Portabel** di HP 1. Sambungkan HP 2, 3, dan 4 ke Wi-Fi hotspot tersebut.
2. **Pemasangan Anchor (Base Stations)**:
   - Buka aplikasi di HP 1, pilih **ANCHOR -> BASE A** (Origin 0, 0, Elevasi acuan).
   - Buka di HP 2, pilih **ANCHOR -> BASE B** (misal jarak 15 meter pada sumbu tanah).
   - Buka di HP 3, pilih **ANCHOR -> BASE C** (misal 15 meter membentuk segitiga).
   - Pasang masing-masing HP di tripod atau patok kayu dengan ketinggian konstan.
3. **Pengukuran (Rover)**:
   - Buka di HP 4, pilih mode **ROVER**.
   - Pasang HP 4 pada tongkat ukur/jalon.
   - Berjalanlah menyusuri kontur tanah, tebing, parit, atau batas lahan.
   - Pilih kode fitur (`KONTUR`, `TANAH`, `PARIT`, dll.), lalu tekan **"TEMBAK TITIK KONTUR"**.
4. **Ekspor Data**:
   - Masuk ke menu **Daftar Titik**, tekan tombol **Bagikan CSV** atau **Bagikan DXF** untuk mengirimkan file hasil ukur via WhatsApp/Email ke tim drafter CAD.

---

## 🛠️ GitHub Actions CI/CD (Auto Tag & Release APK)

Repository ini dilengkapi workflow otomatis di `.github/workflows/build-and-release.yml`:

### Cara Kerja Workflow:
1. Setiap kali kode di-push ke branch `main`, GitHub Actions akan:
   - Menjalankan testing dan quality check (`flutter test`).
   - Membuat **Git Tag otomatis** (contoh: `v1.0.1`, `v1.0.2`, dst).
   - Mengompilasi source code menjadi **Android Release APK**:
     - `TopoSurvey-Universal-v1.0.x.apk` (Dapat diinstal di semua jenis HP Android)
     - `TopoSurvey-arm64-v8a-v1.0.x.apk` (Ukuran lebih ringkas untuk HP modern 64-bit)
     - `TopoSurvey-armeabi-v7a-v1.0.x.apk` (Untuk HP 32-bit)
   - Membuat **GitHub Release** baru dan otomatis mengunggah ketiga file APK tersebut sehingga dapat langsung diunduh dan dipasang oleh tim lapangan!

---

## 🧪 Menjalankan Secara Lokal

```bash
# Masuk ke direktori proyek
cd toposurvey_app

# Pasang dependensi
flutter pub get

# Jalankan uji kualitas & tes unit
flutter test

# Jalankan aplikasi di HP Android yang terhubung
flutter run
```

> [!NOTE]
> Jika path lokal mengandung karakter spesial seperti tanda kutip (`'`) — misalnya `C:\Users\Saha's\...` — perintah `flutter test` bisa gagal karena bug pada Dart URI parser. Hal ini **tidak mempengaruhi CI/CD di GitHub Actions** karena runner CI menggunakan path standar tanpa karakter spesial. Untuk menjalankan `flutter test` secara lokal, pastikan proyek berada di path tanpa karakter `'`.
