#!/usr/bin/env bash
# ================================================================
# Fedora 43 Minimal KDE (X11, Non-Touch, Arch-Style) v5.4
# Author: ChatGPT | System: Dell Inspiron 3542 (i3-4005U, Intel HD 4400)
# Target: Fresh Fedora Base install (no GUI)
# ================================================================

set -e
LOG="$HOME/fedora43-minimal-kde-v5.4.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Fedora 43 Minimal KDE (Arch-style) v5.4 ==="
sudo -v

# ---------- 1️⃣ System update ----------
echo ">>> Updating system..."
sudo dnf upgrade -y --refresh

# ---------- 2️⃣ Enable RPM Fusion ----------
echo ">>> Enabling RPM Fusion repositories..."
FEDVER=$(rpm -E %fedora)
sudo dnf install -y \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDVER}.noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDVER}.noarch.rpm"
sudo dnf clean all && sudo dnf makecache --refresh

# ---------- 3️⃣ Core system tools ----------
echo ">>> Installing essential system utilities..."
sudo dnf install -y --allowerasing \
  NetworkManager curl wget unzip htop fastfetch git neofetch vim nano \
  power-profiles-daemon pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
  bluez bluez-tools ffmpeg-free vlc

sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
sudo systemctl enable --now power-profiles-daemon.service

# ---------- 4️⃣ KDE Plasma (X11 only) ----------
echo ">>> Installing KDE Plasma Desktop (X11, minimal)..."
sudo dnf install -y \
  plasma-desktop plasma-workspace plasma-nm plasma-pa \
  kde-cli-tools plasma-systemsettings powerdevil dolphin konsole kate kscreen \
  plasma-discover xorg-x11-server-Xorg xorg-x11-drivers xorg-x11-xinit \
  sddm kde-settings

# ---------- 5️⃣ Block Wayland / Touch components ----------
echo ">>> Blocking Wayland + touchscreen components..."
sudo bash -c 'cat >> /etc/dnf/dnf.conf <<EOF
exclude=maliit*,plasma-workspace-wayland*,plasma-maliit*,kwayland*,elisa*,skanpage*,kdeconnect*
EOF'

sudo dnf remove -y maliit* plasma-workspace-wayland* kwayland* plasma-maliit* || true

# Disable Wayland in SDDM
sudo mkdir -p /etc/sddm.conf.d
echo -e "[General]\nWaylandEnable=false" | sudo tee /etc/sddm.conf.d/x11-only.conf >/dev/null

# ---------- 6️⃣ Enable GUI login ----------
echo ">>> Enabling graphical target..."
sudo systemctl enable sddm
sudo systemctl set-default graphical.target

# ---------- 7️⃣ Applications ----------
echo ">>> Installing Microsoft Edge + VS Code..."
# Edge
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[edge]\nname=Microsoft Edge\nbaseurl=https://packages.microsoft.com/yumrepos/edge\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
 | sudo tee /etc/yum.repos.d/microsoft-edge.repo >/dev/null
sudo dnf install -y microsoft-edge-stable

# VS Code
echo -e "[vscode]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" \
 | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
sudo dnf install -y code

# ---------- 8️⃣ Intel CPU / GPU tuning ----------
echo ">>> Applying Intel CPU + iGPU optimizations..."
sudo bash -c 'cat > /etc/systemd/system/cpu-tune.service <<EOF
[Unit]
Description=Intel CPU tuning for performance/balance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c "
for c in /sys/devices/system/cpu/cpu[0-9]*; do
  echo schedutil > \$c/cpufreq/scaling_governor 2>/dev/null || true
done
echo balance_performance > /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || true
"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl enable cpu-tune.service

# Intel GPU driver tuning
sudo mkdir -p /etc/modprobe.d
sudo bash -c 'cat > /etc/modprobe.d/i915.conf <<EOF
options i915 enable_psr=1 enable_fbc=1 enable_guc=3 i915_enable_rc6=1
options i915 enable_dc=2 modeset=1 enable_gvt=0
EOF'

# ---------- 9️⃣ Cleanup ----------
echo ">>> Cleaning system..."
sudo dnf autoremove -y
sudo dnf clean all

echo
echo "✅ Fedora 43 Minimal KDE (X11, non-touch) setup complete!"
echo "➡️ Reboot to start KDE Plasma (X11)"
echo "💾 Log saved at $LOG"
echo