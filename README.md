# Ubuntu Setup Tool — All-in-One

Script bash interaktif untuk setup Ubuntu VPS dengan cepat. Satu file, semua kebutuhan.

```bash
curl -fsSL https://raw.githubusercontent.com/figolbmx/ubuntu/main/install.sh -o install.sh && chmod +x install.sh && sudo bash install.sh
```

---

## Fitur

| Kategori | Isi |
|----------|-----|
| 🖥️ **Setup RDP** | Desktop Environment + XRDP + Tailscale |
| 📦 **Aplikasi** | Browser, Node.js, VSCode, Kiro, OpenCode, GitHub, Cockpit Tools |
| 🔧 **Fix RDP** | Troubleshoot & repair masalah RDP umum |
| 📱 **APK Tools** | apktool, jadx, dex2jar, apksigner, zipalign |

---

## Cara Pakai

**Metode 1 — Langsung dari GitHub (Tercepat):**
```bash
curl -fsSL https://raw.githubusercontent.com/figolbmx/ubuntu/main/install.sh | sudo bash
```

**Metode 2 — Download dulu, baru jalankan:**
```bash
curl -fsSL https://raw.githubusercontent.com/figolbmx/ubuntu/main/install.sh -o install.sh && chmod +x install.sh && sudo bash install.sh
```

**Metode 3 — Jika sudah ada file-nya:**
```bash
chmod +x install.sh
sudo bash install.sh
```

> Tested on: Ubuntu 20.04 / 22.04 / 24.04

---

## Menu

```
UBUNTU SETUP TOOL
├── 1) 🖥️  Setup       — Desktop + XRDP + Tailscale
├── 2) 📦  Aplikasi    — Browser, Node, IDE, Tools
├── 3) 🔧  Fix RDP     — Troubleshoot & Repair
└── 4) 📱  APK Tools   — Decompile, Recompile, Sign
```

---

### 1) Setup — Desktop + XRDP + Tailscale

```
── Install ──────────────────────────────────────
1) Pilih Desktop Environment (XFCE4 / LXDE / LXQt)
2) Set Timezone → Asia/Jakarta (WIB)
3) Update & Upgrade Sistem
4) Install Desktop (sesuai pilihan)
5) Install & Konfigurasi XRDP
6) Install Tailscale VPN
7) Install Lengkap: Desktop + XRDP
8) Install Semua: Desktop + XRDP + Tailscale
9) Info Koneksi RDP (IP Publik + Private + Tailscale)

── Uninstall / Clean ────────────────────────────
A) Hapus XRDP
B) Hapus Desktop Environment
C) Hapus Semua (Desktop + XRDP) — Clean Install
```

**Pilihan Desktop Environment:**

| DE | RAM Idle | Keterangan |
|----|----------|------------|
| **XFCE4** | ~300MB | Ringan, stabil, direkomendasikan |
| **LXDE** | ~200MB | Paling ringan, tampilan simpel |
| **LXQt** | ~250MB | Modern, lebih rapi dari LXDE |

Koneksi RDP menggunakan protokol Microsoft RDP (port 3389) — bisa langsung dari Windows via `mstsc` tanpa software tambahan.

---

### 2) Aplikasi

```
1) Chromium Browser
2) Firefox ESR
3) Node.js LTS Terbaru + NPM
4) Visual Studio Code (VSCode)
5) Kiro (AWS AI IDE)
6) OpenCode (AI Terminal Agent)
7) GitHub (Git + GitHub CLI + SSH Key)
8) Cockpit Tools (AI IDE Account Manager)
9) Install Semua Aplikasi
A) Cek Status Aplikasi
```

---

### 3) Fix RDP — Troubleshoot

```
1) Restart XRDP Service
2) Fix Layar Hitam (Black Screen)
3) Fix Login / Authentication Gagal
4) Fix Connection Refused (Port 3389)
5) Fix Sesi Menumpuk (Too Many Sessions)
6) Fix XFCE Tidak Load / Desktop Kosong
7) Reinstall XRDP (Full)
8) Tampilkan Status & Diagnostik
9) Fix All (Jalankan Semua Perbaikan)
```

---

### 4) APK Tools

```
1) Install Java JDK 17 (Wajib)
2) Install apktool   — Decompile & Recompile APK
3) Install jadx      — Decompile APK/DEX ke Java source
4) Install dex2jar   — Convert DEX → JAR
5) Install apksigner & zipalign — Sign & align APK
6) Install Semua APK Tools
7) Status & Quick Reference
```

**Quick Reference APK Workflow:**
```bash
# Decompile
apktool d app.apk -o output/

# Edit smali / resource di output/

# Recompile
apktool b output/ -o rebuilt.apk

# Lihat source Java
jadx app.apk -d jadx_out/

# Convert DEX ke JAR
d2j-dex2jar.sh app.apk -o out.jar

# Sign APK
apksigner sign --ks debug.keystore --ks-key-alias debugkey \
  --ks-pass pass:android rebuilt.apk

# Zipalign
zipalign -v 4 rebuilt.apk aligned.apk
```

---

## Koneksi RDP

Setelah install, koneksikan dari:

| Platform | Aplikasi |
|----------|----------|
| Windows | Remote Desktop Connection (`mstsc`) |
| macOS | Microsoft Remote Desktop |
| Linux | Remmina / FreeRDP |

```
Host : IP Publik VPS
Port : 3389
User : username Ubuntu
Pass : password Ubuntu
```

> Jika login gagal: `sudo passwd <username>`

---

## Requirements

- Ubuntu 20.04 / 22.04 / 24.04
- Akses root atau sudo
- Koneksi internet

---

## License

MIT
