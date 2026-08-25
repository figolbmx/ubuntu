#!/bin/bash
# ============================================================
#  UBUNTU SETUP TOOL — All-in-One
#  Install XFCE + XRDP + Tailscale
#  Install Apps: Chromium, Firefox ESR, Node.js, VSCode, Kiro, OpenCode
#  Fix / Troubleshoot RDP
#  Tested on: Ubuntu 20.04 / 22.04 / 24.04
#  Run as root or with sudo
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()     { echo -e "${GREEN}[OK]${NC} $1"; }
info()    { echo -e "${CYAN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }
section() {
  echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"
}

# ── Check root ───────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Jalankan sebagai root:${NC} sudo bash $0"
  exit 1
fi

# ── Detect user asli (bukan root) ────────────────────────────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
REAL_HOME=$(getent passwd "$REAL_USER" 2>/dev/null | cut -d: -f6 || echo "/root")

# ════════════════════════════════════════════════════════════
#  BAGIAN 1 — SETUP: XFCE + XRDP + TAILSCALE
# ════════════════════════════════════════════════════════════

set_timezone() {
  section "Set Timezone Asia/Jakarta (WIB)"
  timedatectl set-timezone Asia/Jakarta
  log "Timezone diset ke: $(timedatectl | grep 'Time zone')"
}

update_system() {
  section "Update & Upgrade Sistem"
  apt-get update -y
  apt-get upgrade -y
  log "Sistem berhasil diupdate."
}

install_xfce() {
  section "Install XFCE4 Desktop Environment"
  info "Menginstall XFCE4 dan paket pendukung..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils
  log "XFCE4 berhasil diinstall."
}

install_xrdp() {
  section "Install & Konfigurasi XRDP"

  info "Menginstall XRDP..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp

  info "Menambahkan user xrdp ke grup ssl-cert..."
  adduser xrdp ssl-cert 2>/dev/null || true

  info "Konfigurasi startwm.sh untuk menggunakan XFCE..."
  cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec /usr/bin/startxfce4
EOF
  chmod +x /etc/xrdp/startwm.sh

  info "Set .xsession untuk semua user..."
  [[ -n "$SUDO_USER" ]] && {
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    echo "startxfce4" > "$USER_HOME/.xsession"
    chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.xsession"
    log "Set .xsession untuk user: $SUDO_USER"
  }
  for USER_HOME in /home/*; do
    [[ -d "$USER_HOME" ]] || continue
    USERNAME=$(basename "$USER_HOME")
    echo "startxfce4" > "$USER_HOME/.xsession"
    chown "$USERNAME:$USERNAME" "$USER_HOME/.xsession" 2>/dev/null || true
  done
  echo "startxfce4" > /root/.xsession

  info "Konfigurasi Polkit (mencegah popup auth di sesi RDP)..."
  mkdir -p /etc/polkit-1/localauthority/50-local.d/
  cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla << 'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

  info "Enable dan start service XRDP..."
  systemctl enable xrdp
  systemctl restart xrdp

  info "Mengecek firewall UFW..."
  if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
    ufw allow 3389/tcp && ufw reload
    log "Port 3389 dibuka di UFW."
  else
    warn "UFW tidak aktif. Pastikan port 3389 terbuka di firewall/security group Anda."
  fi

  log "XRDP berhasil diinstall dan dikonfigurasi."
  systemctl status xrdp --no-pager | head -10
}

install_tailscale() {
  section "Install Tailscale VPN"
  info "Menginstall Tailscale via script resmi..."
  apt-get install -y curl
  curl -fsSL https://tailscale.com/install.sh | sh

  if command -v tailscale &>/dev/null; then
    log "Tailscale berhasil diinstall."
    info "Versi: $(tailscale version 2>/dev/null | head -1)"
    systemctl enable tailscaled
    systemctl start tailscaled
    echo ""
    echo -e "  ${YELLOW}Jalankan perintah berikut untuk login Tailscale:${NC}"
    echo -e "  ${CYAN}tailscale up${NC}"
    echo ""
    read -rp "  Jalankan 'tailscale up' sekarang? (y/N): " RUN_UP
    [[ "$RUN_UP" == "y" || "$RUN_UP" == "Y" ]] && tailscale up
  else
    err "Tailscale gagal diinstall."
  fi
}

show_connection_info() {
  section "Info Koneksi RDP"
  IP_LOCAL=$(hostname -I | awk '{print $1}')
  IP_TAILSCALE=$(tailscale ip -4 2>/dev/null || echo "Belum terkoneksi")
  echo ""
  echo -e "  ${BOLD}Koneksikan via Remote Desktop (RDP):${NC}"
  echo ""
  echo -e "  ${YELLOW}IP Lokal     :${NC} $IP_LOCAL"
  echo -e "  ${YELLOW}IP Tailscale :${NC} $IP_TAILSCALE"
  echo -e "  ${YELLOW}Port         :${NC} 3389"
  echo -e "  ${YELLOW}Username     :${NC} (user Ubuntu Anda)"
  echo -e "  ${YELLOW}Password     :${NC} (password user Ubuntu Anda)"
  echo ""
  echo -e "  ${BOLD}Gunakan aplikasi RDP:${NC}"
  echo -e "  - Windows : Remote Desktop Connection (mstsc)"
  echo -e "  - macOS   : Microsoft Remote Desktop"
  echo -e "  - Linux   : Remmina / FreeRDP"
  echo ""
  echo -e "  ${YELLOW}[NOTE]${NC} Jika login gagal: sudo passwd <username>"
  echo ""
  echo -e "  ${BOLD}Status Services:${NC}"
  echo -e "  XRDP      : $(systemctl is-active xrdp 2>/dev/null)"
  echo -e "  Tailscale : $(systemctl is-active tailscaled 2>/dev/null)"
  echo -e "  Timezone  : $(timedatectl | grep 'Time zone' | awk '{print $3}')"
}

setup_xfce_xrdp_full() {
  section "Install Lengkap: XFCE + XRDP"
  warn "Akan menginstall: Timezone, Update sistem, XFCE4, XRDP"
  read -rp "Lanjutkan? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Dibatalkan."; return; }
  set_timezone; update_system; install_xfce; install_xrdp
  show_connection_info
}

setup_all() {
  section "Install Semua: XFCE + XRDP + Tailscale"
  warn "Akan menginstall: Timezone, Update sistem, XFCE4, XRDP, Tailscale"
  read -rp "Lanjutkan? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Dibatalkan."; return; }
  set_timezone; update_system; install_xfce; install_xrdp; install_tailscale
  show_connection_info
}

# ════════════════════════════════════════════════════════════
#  BAGIAN 2 — INSTALL APLIKASI
# ════════════════════════════════════════════════════════════

install_chromium() {
  section "Install Chromium Browser"
  info "Menginstall Chromium..."
  apt-get update -y
  apt-get install -y chromium-browser 2>/dev/null || \
  apt-get install -y chromium 2>/dev/null || \
  snap install chromium

  if command -v chromium-browser &>/dev/null || command -v chromium &>/dev/null; then
    log "Chromium berhasil diinstall."
    info "Versi: $(chromium-browser --version 2>/dev/null || chromium --version 2>/dev/null)"
  else
    err "Chromium gagal diinstall."
  fi
}

install_firefox_esr() {
  section "Install Firefox ESR"
  info "Menambahkan repository Mozilla PPA..."
  apt-get install -y software-properties-common
  add-apt-repository -y ppa:mozillateam/ppa

  cat > /etc/apt/preferences.d/mozilla-firefox << 'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF

  apt-get update -y
  apt-get install -y firefox-esr

  if command -v firefox-esr &>/dev/null || command -v firefox &>/dev/null; then
    log "Firefox ESR berhasil diinstall."
    info "Versi: $(firefox-esr --version 2>/dev/null || firefox --version 2>/dev/null)"
  else
    err "Firefox ESR gagal diinstall."
  fi
}

install_nodejs() {
  section "Install Node.js LTS Terbaru + NPM"
  apt-get remove -y nodejs npm 2>/dev/null || true
  apt-get install -y curl ca-certificates gnupg

  info "Mendeteksi versi LTS terbaru..."
  NODE_MAJOR=$(curl -fsSL https://resolve.nodesource.com/v1/latest-lts | \
    grep -oP '"version"\s*:\s*"\K[0-9]+' | head -1 2>/dev/null || echo "20")

  info "Menginstall Node.js v$NODE_MAJOR LTS..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
  apt-get install -y nodejs

  if command -v node &>/dev/null; then
    log "Node.js berhasil diinstall."
    info "Node: $(node --version) | NPM: $(npm --version)"
    info "Update NPM ke versi terbaru..."
    npm install -g npm@latest
    log "NPM diupdate: $(npm --version)"
  else
    err "Node.js gagal diinstall."
  fi
}

install_vscode() {
  section "Install Visual Studio Code"
  apt-get install -y wget gpg apt-transport-https

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor > /etc/apt/keyrings/microsoft.gpg
  chmod go+r /etc/apt/keyrings/microsoft.gpg

  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
    > /etc/apt/sources.list.d/vscode.list

  apt-get update -y
  apt-get install -y code

  if command -v code &>/dev/null; then
    log "VSCode berhasil diinstall."
    info "Versi: $(code --version | head -1)"
  else
    err "VSCode gagal diinstall."
  fi
}

install_kiro() {
  section "Install Kiro (AWS AI IDE)"
  apt-get install -y wget curl

  KIRO_URL="https://desktop-release.kiro.dev/latest/linux/kiro-latest-amd64.deb"
  KIRO_DEB="/tmp/kiro-latest.deb"

  info "Download dari: $KIRO_URL"
  wget -q --show-progress -O "$KIRO_DEB" "$KIRO_URL"

  if [[ -f "$KIRO_DEB" ]]; then
    apt-get install -y "$KIRO_DEB" 2>/dev/null || dpkg -i "$KIRO_DEB" && apt-get install -f -y
    rm -f "$KIRO_DEB"
    if command -v kiro &>/dev/null; then
      log "Kiro berhasil diinstall."
      info "Versi: $(kiro --version 2>/dev/null || echo 'Cek via aplikasi')"
    else
      warn "Kiro mungkin terinstall. Cari di: /usr/share/kiro atau /opt/Kiro"
    fi
  else
    err "Gagal mendownload Kiro. Download manual: https://kiro.dev"
  fi
}

install_opencode() {
  section "Install OpenCode (AI Terminal Coding Agent)"
  if ! command -v npm &>/dev/null; then
    warn "NPM tidak ditemukan. Install Node.js + NPM dulu (menu 3)."
    return
  fi
  npm install -g opencode-ai@latest
  if command -v opencode &>/dev/null; then
    log "OpenCode berhasil diinstall."
    info "Versi: $(opencode --version 2>/dev/null || echo 'Cek: opencode --version')"
  else
    err "OpenCode gagal diinstall. Coba: npm install -g opencode-ai"
  fi
}

apps_install_all() {
  section "Install Semua Aplikasi"
  warn "Akan menginstall: Chromium, Firefox ESR, Node.js+NPM, VSCode, Kiro, OpenCode"
  read -rp "Lanjutkan? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Dibatalkan."; return; }

  install_chromium
  install_firefox_esr
  install_nodejs
  install_vscode
  install_kiro
  install_opencode

  section "Ringkasan Instalasi Aplikasi"
  echo ""
  command -v chromium-browser &>/dev/null && echo -e "  ${GREEN}✔${NC} Chromium  : $(chromium-browser --version 2>/dev/null)"
  command -v chromium &>/dev/null         && echo -e "  ${GREEN}✔${NC} Chromium  : $(chromium --version 2>/dev/null)"
  command -v firefox-esr &>/dev/null      && echo -e "  ${GREEN}✔${NC} Firefox   : $(firefox-esr --version 2>/dev/null)"
  command -v node &>/dev/null             && echo -e "  ${GREEN}✔${NC} Node.js   : $(node --version)"
  command -v npm &>/dev/null              && echo -e "  ${GREEN}✔${NC} NPM       : $(npm --version)"
  command -v code &>/dev/null             && echo -e "  ${GREEN}✔${NC} VSCode    : $(code --version | head -1)"
  command -v kiro &>/dev/null             && echo -e "  ${GREEN}✔${NC} Kiro      : $(kiro --version 2>/dev/null || echo 'Terinstall')"
  command -v opencode &>/dev/null         && echo -e "  ${GREEN}✔${NC} OpenCode  : $(opencode --version 2>/dev/null || echo 'Terinstall')"
  echo ""
}

apps_show_status() {
  section "Status Aplikasi Terinstall"
  echo ""
  _chk() {
    local label="$1" cmd="$2" vcmd="$3"
    if command -v "$cmd" &>/dev/null; then
      echo -e "  ${GREEN}✔${NC} $label — $(eval "$vcmd" 2>/dev/null | head -1 || echo 'Terinstall')"
    else
      echo -e "  ${RED}✘${NC} $label — Belum diinstall"
    fi
  }
  _chk "Chromium"    "chromium-browser" "chromium-browser --version"
  _chk "Chromium"    "chromium"         "chromium --version"
  _chk "Firefox ESR" "firefox-esr"      "firefox-esr --version"
  _chk "Node.js"     "node"             "node --version"
  _chk "NPM"         "npm"              "npm --version"
  _chk "VSCode"      "code"             "code --version"
  _chk "Kiro"        "kiro"             "kiro --version"
  _chk "OpenCode"    "opencode"         "opencode --version"
  echo ""
}

# ════════════════════════════════════════════════════════════
#  BAGIAN 3 — FIX / TROUBLESHOOT RDP
# ════════════════════════════════════════════════════════════

fix_restart_xrdp() {
  section "Restart XRDP Service"
  systemctl stop xrdp xrdp-sesman 2>/dev/null || true
  sleep 2
  systemctl start xrdp
  sleep 2
  if systemctl is-active --quiet xrdp; then
    log "XRDP berhasil di-restart dan berjalan normal."
  else
    err "XRDP gagal start. Cek log: journalctl -xe | grep xrdp"
  fi
  systemctl status xrdp --no-pager | head -15
}

fix_black_screen() {
  section "Fix Black Screen / Layar Hitam RDP"
  info "Memperbaiki konfigurasi startwm.sh..."
  cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec /usr/bin/startxfce4
EOF
  chmod +x /etc/xrdp/startwm.sh
  log "startwm.sh diperbaiki."

  info "Memperbaiki .xsession untuk semua user..."
  echo "startxfce4" > /root/.xsession
  for USER_HOME in /home/*; do
    USERNAME=$(basename "$USER_HOME")
    if id "$USERNAME" &>/dev/null; then
      echo "startxfce4" > "$USER_HOME/.xsession"
      chown "$USERNAME:$USERNAME" "$USER_HOME/.xsession"
      log "Set .xsession untuk user: $USERNAME"
    fi
  done

  info "Menghapus file lock X yang tersisa..."
  rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
  log "File lock X dihapus."

  systemctl restart xrdp
  log "Fix black screen selesai. Coba koneksi ulang."
}

fix_authentication_failed() {
  section "Fix Authentication / Login Gagal"
  info "Mengecek PAM XRDP..."
  if ! grep -q "auth required pam_succeed_if.so" /etc/pam.d/xrdp-sesman 2>/dev/null; then
    warn "Konfigurasi PAM mungkin bermasalah."
  else
    log "PAM XRDP tampak normal."
  fi

  adduser xrdp ssl-cert 2>/dev/null && log "User xrdp ditambahkan ke ssl-cert." || warn "Sudah ada atau gagal."

  echo ""
  echo -e "${YELLOW}Daftar user yang ada:${NC}"
  awk -F: '$3 >= 1000 && $1 != "nobody" {print "  - " $1}' /etc/passwd
  echo ""
  echo -e "${YELLOW}Jika login gagal, set password:${NC} sudo passwd <username>"
  echo ""
  systemctl restart xrdp
  log "Fix authentication selesai."
}

fix_connection_refused() {
  section "Fix Connection Refused (Port 3389)"
  info "Mengecek apakah XRDP listening di port 3389..."
  if ss -tlnp | grep -q ':3389'; then
    log "XRDP sudah listen di port 3389."
  else
    warn "XRDP tidak listen. Mencoba restart..."
    systemctl restart xrdp; sleep 3
    if ss -tlnp | grep -q ':3389'; then
      log "Sekarang XRDP listen di port 3389."
    else
      err "XRDP tetap tidak bisa start. Cek: journalctl -xe | grep xrdp"
    fi
  fi

  if command -v ufw &>/dev/null; then
    UFW_STATUS=$(ufw status)
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
      if echo "$UFW_STATUS" | grep -q "3389"; then
        log "Port 3389 sudah dibuka di UFW."
      else
        ufw allow 3389/tcp && ufw reload
        log "Port 3389 berhasil dibuka di UFW."
      fi
    else
      info "UFW tidak aktif, skip."
    fi
  fi
  echo -e "\n  ${YELLOW}Coba koneksi ke:${NC} $(hostname -I | awk '{print $1}'):3389"
}

fix_many_sessions() {
  section "Fix Too Many Sessions / Session Menumpuk"
  pkill -f "Xvnc"         2>/dev/null && log "Proses Xvnc dihentikan."         || info "Tidak ada Xvnc berjalan."
  pkill -f "xrdp-chansrv" 2>/dev/null && log "Proses xrdp-chansrv dihentikan." || info "Tidak ada xrdp-chansrv berjalan."
  rm -f /tmp/.xrdp* /tmp/xrdp_* 2>/dev/null || true
  log "File sesi lama dihapus."
  systemctl restart xrdp
  log "Fix sesi menumpuk selesai."
}

fix_xfce_not_loading() {
  section "Fix XFCE Tidak Load / Desktop Kosong"
  info "Reinstall paket XFCE..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y --reinstall \
    xfce4 xfce4-session xfwm4 xfce4-panel thunar 2>&1 | tail -5
  log "Paket XFCE di-reinstall."

  info "Reset konfigurasi XFCE untuk semua user..."
  for USER_HOME in /home/* /root; do
    if [[ -d "$USER_HOME/.config/xfce4" ]]; then
      mv "$USER_HOME/.config/xfce4" "$USER_HOME/.config/xfce4.bak.$(date +%s)" 2>/dev/null || true
      log "Konfigurasi XFCE di-reset untuk: $(stat -c '%U' "$USER_HOME") (backup dibuat)"
    fi
  done

  cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec /usr/bin/startxfce4
EOF
  chmod +x /etc/xrdp/startwm.sh
  systemctl restart xrdp
  log "Fix XFCE tidak load selesai."
}

fix_reinstall_xrdp() {
  section "Reinstall XRDP (Full)"
  warn "Ini akan menghapus dan install ulang XRDP sepenuhnya."
  read -rp "Lanjutkan? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Dibatalkan."; return; }

  systemctl stop xrdp 2>/dev/null || true
  apt-get purge -y xrdp && apt-get autoremove -y
  apt-get install -y xrdp
  adduser xrdp ssl-cert 2>/dev/null || true
  cat > /etc/xrdp/startwm.sh << 'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec /usr/bin/startxfce4
EOF
  chmod +x /etc/xrdp/startwm.sh
  systemctl enable xrdp && systemctl start xrdp
  log "XRDP berhasil di-reinstall."
}

fix_show_status() {
  section "Status & Diagnostik XRDP"

  echo -e "\n${BOLD}[ Service XRDP ]${NC}"
  systemctl status xrdp --no-pager | head -20

  echo -e "\n${BOLD}[ Port Listening ]${NC}"
  ss -tlnp | grep ':3389' || warn "XRDP tidak listen di port 3389"

  echo -e "\n${BOLD}[ Log Terakhir XRDP (20 baris) ]${NC}"
  journalctl -u xrdp --no-pager -n 20 2>/dev/null \
    || tail -20 /var/log/xrdp.log 2>/dev/null \
    || warn "Log tidak ditemukan."

  echo -e "\n${BOLD}[ Firewall UFW ]${NC}"
  command -v ufw &>/dev/null && ufw status || info "UFW tidak terinstall."

  echo -e "\n${BOLD}[ IP Address ]${NC}"
  echo "  Lokal     : $(hostname -I | awk '{print $1}')"
  echo "  Tailscale : $(tailscale ip -4 2>/dev/null || echo 'Tidak aktif')"

  echo -e "\n${BOLD}[ Timezone ]${NC}"
  timedatectl | grep "Time zone"
}

fix_all() {
  section "Fix All — Jalankan Semua Perbaikan"
  warn "Ini akan menjalankan semua fix secara otomatis."
  read -rp "Lanjutkan? (y/N): " CONFIRM
  [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && { info "Dibatalkan."; return; }
  fix_black_screen
  fix_many_sessions
  fix_xfce_not_loading
  fix_connection_refused
  fix_authentication_failed
  fix_restart_xrdp
  log "Semua fix selesai dijalankan."
}

# ════════════════════════════════════════════════════════════
#  SUB-MENU 1 — SETUP XFCE + XRDP + TAILSCALE
# ════════════════════════════════════════════════════════════

menu_setup() {
  while true; do
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   SETUP — XFCE + XRDP + Tailscale        ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}Pilih opsi instalasi:${NC}\n"
    echo -e "  ${GREEN}1)${NC} Set Timezone → Asia/Jakarta (WIB)"
    echo -e "  ${GREEN}2)${NC} Update & Upgrade Sistem"
    echo -e "  ${GREEN}3)${NC} Install XFCE4 Desktop"
    echo -e "  ${GREEN}4)${NC} Install & Konfigurasi XRDP"
    echo -e "  ${GREEN}5)${NC} Install Tailscale VPN"
    echo -e "  ${YELLOW}6)${NC} Install Lengkap: XFCE + XRDP"
    echo -e "  ${YELLOW}7)${NC} Install Semua: XFCE + XRDP + Tailscale"
    echo -e "  ${CYAN}8)${NC} Info Koneksi RDP"
    echo -e "  ${RED}0)${NC} Kembali ke Menu Utama"
    echo ""
    read -rp "  Masukkan pilihan [0-8]: " CHOICE
    case "$CHOICE" in
      1) set_timezone ;;
      2) update_system ;;
      3) install_xfce ;;
      4) install_xrdp ;;
      5) install_tailscale ;;
      6) setup_xfce_xrdp_full ;;
      7) setup_all ;;
      8) show_connection_info ;;
      0) return ;;
      *) warn "Pilihan tidak valid." ;;
    esac
    echo ""; read -rp "  Tekan Enter untuk kembali ke menu..."
  done
}

# ════════════════════════════════════════════════════════════
#  SUB-MENU 2 — INSTALL APLIKASI
# ════════════════════════════════════════════════════════════

menu_apps() {
  while true; do
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   INSTALL APLIKASI                       ║"
    echo "  ║   Browser · Node · VSCode · Kiro         ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}Pilih aplikasi yang ingin diinstall:${NC}\n"
    echo -e "  ${GREEN}1)${NC} Chromium Browser"
    echo -e "  ${GREEN}2)${NC} Firefox ESR"
    echo -e "  ${GREEN}3)${NC} Node.js LTS Terbaru + NPM"
    echo -e "  ${GREEN}4)${NC} Visual Studio Code (VSCode)"
    echo -e "  ${GREEN}5)${NC} Kiro (AWS AI IDE)"
    echo -e "  ${GREEN}6)${NC} OpenCode (AI Terminal Agent)"
    echo -e "  ${YELLOW}7)${NC} Install Semua Aplikasi"
    echo -e "  ${CYAN}8)${NC} Cek Status Aplikasi"
    echo -e "  ${RED}0)${NC} Kembali ke Menu Utama"
    echo ""
    read -rp "  Masukkan pilihan [0-8]: " CHOICE
    case "$CHOICE" in
      1) install_chromium ;;
      2) install_firefox_esr ;;
      3) install_nodejs ;;
      4) install_vscode ;;
      5) install_kiro ;;
      6) install_opencode ;;
      7) apps_install_all ;;
      8) apps_show_status ;;
      0) return ;;
      *) warn "Pilihan tidak valid." ;;
    esac
    echo ""; read -rp "  Tekan Enter untuk kembali ke menu..."
  done
}

# ════════════════════════════════════════════════════════════
#  SUB-MENU 3 — FIX RDP
# ════════════════════════════════════════════════════════════

menu_fix() {
  while true; do
    clear
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║   FIX / TROUBLESHOOT RDP                 ║"
    echo "  ║   XFCE + XRDP Troubleshooter             ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${BOLD}Pilih opsi perbaikan:${NC}\n"
    echo -e "  ${GREEN}1)${NC} Restart XRDP Service"
    echo -e "  ${GREEN}2)${NC} Fix Layar Hitam (Black Screen)"
    echo -e "  ${GREEN}3)${NC} Fix Login / Authentication Gagal"
    echo -e "  ${GREEN}4)${NC} Fix Connection Refused (Port 3389)"
    echo -e "  ${GREEN}5)${NC} Fix Sesi Menumpuk (Too Many Sessions)"
    echo -e "  ${GREEN}6)${NC} Fix XFCE Tidak Load / Desktop Kosong"
    echo -e "  ${GREEN}7)${NC} Reinstall XRDP (Full)"
    echo -e "  ${CYAN}8)${NC} Tampilkan Status & Diagnostik"
    echo -e "  ${YELLOW}9)${NC} Fix All (Jalankan Semua Perbaikan)"
    echo -e "  ${RED}0)${NC} Kembali ke Menu Utama"
    echo ""
    read -rp "  Masukkan pilihan [0-9]: " CHOICE
    case "$CHOICE" in
      1) fix_restart_xrdp ;;
      2) fix_black_screen ;;
      3) fix_authentication_failed ;;
      4) fix_connection_refused ;;
      5) fix_many_sessions ;;
      6) fix_xfce_not_loading ;;
      7) fix_reinstall_xrdp ;;
      8) fix_show_status ;;
      9) fix_all ;;
      0) return ;;
      *) warn "Pilihan tidak valid." ;;
    esac
    echo ""; read -rp "  Tekan Enter untuk kembali ke menu..."
  done
}

# ════════════════════════════════════════════════════════════
#  MENU UTAMA
# ════════════════════════════════════════════════════════════

while true; do
  clear
  echo -e "${BOLD}${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║        UBUNTU SETUP TOOL                 ║"
  echo "  ║   All-in-One · RDP · Apps · Fix          ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  ${BOLD}Pilih kategori:${NC}\n"
  echo -e "  ${GREEN}1)${NC} 🖥️   Setup   — XFCE + XRDP + Tailscale"
  echo -e "  ${GREEN}2)${NC} 📦  Aplikasi — Chromium, Firefox, Node, VSCode, Kiro, OpenCode"
  echo -e "  ${GREEN}3)${NC} 🔧  Fix RDP  — Troubleshoot & Repair"
  echo -e "  ${RED}0)${NC} ❌  Keluar"
  echo ""
  read -rp "  Masukkan pilihan [0-3]: " MAIN_CHOICE
  case "$MAIN_CHOICE" in
    1) menu_setup ;;
    2) menu_apps ;;
    3) menu_fix ;;
    0) echo -e "\n${GREEN}Keluar.${NC}\n"; exit 0 ;;
    *) warn "Pilihan tidak valid. Coba lagi."; sleep 1 ;;
  esac
done
