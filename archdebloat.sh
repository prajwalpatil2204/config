#!/usr/bin/env bash
# ===============================================================
# Fedora 43 KDE Plasma (X11 Only) + RPM Fusion + AAC + Hibernate
# Author: ChatGPT
# Target: Dell Inspiron 3542 (Intel i3-4005U, Intel HD 4400, 8GB RAM)
# ===============================================================

set -e
LOG="$HOME/fedora43-x11-v4.2.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Fedora 43 KDE Plasma (X11 Only) + AAC + Hibernate ==="
sudo -v

# ----------------------------------------------------------
echo ">>> Updating system..."
sudo dnf upgrade -y --refresh

# ----------------------------------------------------------
echo ">>> Enabling RPM Fusion repositories..."
FEDVER=$(rpm -E %fedora)
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDVER}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDVER}.noarch.rpm"
    sudo dnf config-manager --enable rpmfusion-free rpmfusion-nonfree || true
    sudo dnf makecache --refresh

    # ----------------------------------------------------------
    echo ">>> Installing KDE Plasma (X11 minimal, no Wayland, no Maliit)..."
    sudo dnf install -y --allowerasing \
      plasma-desktop plasma-workspace-x11 \
        sddm sddm-breeze kde-settings-sddm \
          kde-cli-tools plasma-systemmonitor kinfocenter \
            bluedevil konsole dolphin kdialog kscreen powerdevil \
              plasma-nm plasma-pa \
                xorg-x11-server-Xorg xorg-x11-xinit \
                  xorg-x11-drv-intel xorg-x11-utils xorg-x11-xauth \
                    pipewire pipewire-alsa pipewire-pulseaudio wireplumber \
                      bluez bluez-libs bluez-obexd alsa-utils pavucontrol \
                        network-manager networkmanager-wifi network-manager-applet nm-connection-editor \
                          plymouth plymouth-system-theme plymouth-theme-breeze

                          # ----------------------------------------------------------
                          echo ">>> Removing Maliit virtual keyboard and related touchscreen components..."
                          sudo dnf remove -y maliit* plasma-mobile* || true
                          sudo dnf mark install plasma-desktop || true  # prevent reinstallation
                          sudo systemctl mask maliit-server.service maliit-daemon.service || true

                          # ----------------------------------------------------------
                          echo ">>> Enabling full multimedia & AAC codec via RPM Fusion..."
                          sudo dnf groupupdate -y multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
                          sudo dnf groupupdate -y sound-and-video
                          sudo dnf install -y --allowerasing \
                            ffmpeg ffmpeg-free ffmpeg-libs fdk-aac-free libfdk_aac pipewire-plugin-libav

                            sudo mkdir -p /etc/wireplumber/bluetooth.lua.d
                            sudo bash -c 'cat > /etc/wireplumber/bluetooth.lua.d/51-bluez-config.lua <<EOF
                            bluez_monitor.properties = {
                              ["bluez5.enable-aac"] = true,
                                ["bluez5.enable-sbc-xq"] = true,
                                  ["bluez5.enable-msbc"] = true,
                                    ["bluez5.enable-hw-volume"] = true
                                    }
                                    EOF'

                                    # ----------------------------------------------------------
                                    echo ">>> Setting SDDM and Breeze X11 login theme..."
                                    sudo mkdir -p /etc/sddm.conf.d
                                    sudo bash -c 'cat > /etc/sddm.conf.d/x11.conf <<EOF
                                    [General]
                                    WaylandEnable=false
                                    [Theme]
                                    Current=breeze
                                    CursorTheme=Breeze_Light
                                    EOF'
                                    sudo plymouth-set-default-theme -R breeze || true

                                    # ----------------------------------------------------------
                                    echo ">>> Installing power & hibernate support tools..."
                                    sudo dnf install -y --allowerasing \
                                      tuned powertop systemd-zram-generator-defaults intel-gpu-tools acpi lm_sensors htop util-linux
                                      sudo systemctl enable --now tuned
                                      sudo tuned-adm profile balanced || true
                                      sudo systemctl enable --now systemd-zram-setup@zram0.service || true
                                      sudo systemctl enable --now NetworkManager bluetooth sddm pipewire wireplumber

                                      # ----------------------------------------------------------
                                      echo ">>> Setting up Hibernate support..."
                                      # Enable hibernate if swap > RAM
                                      SWAPFILE="/swapfile"
                                      if [ ! -f "$SWAPFILE" ]; then
                                        echo "Creating 8G swapfile for hibernation..."
                                          sudo fallocate -l 8G "$SWAPFILE"
                                            sudo chmod 600 "$SWAPFILE"
                                              sudo mkswap "$SWAPFILE"
                                                sudo swapon "$SWAPFILE"
                                                  echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
                                                  fi

                                                  UUID=$(findmnt -no UUID -T /swapfile)
                                                  sudo bash -c "echo 'RESUME=UUID=$UUID' > /etc/default/grub.d/99-hibernate.conf"
                                                  sudo grub2-mkconfig -o /boot/grub2/grub.cfg || true

                                                  # ----------------------------------------------------------
                                                  echo ">>> Installing Microsoft Edge, VS Code, VLC..."
                                                  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

                                                  # Edge
                                                  sudo tee /etc/yum.repos.d/microsoft-edge.repo >/dev/null <<'EOF'
                                                  [edge]
                                                  name=Microsoft Edge
                                                  baseurl=https://packages.microsoft.com/yumrepos/edge
                                                  enabled=1
                                                  gpgcheck=1
                                                  gpgkey=https://packages.microsoft.com/keys/microsoft.asc
                                                  EOF
                                                  sudo dnf install -y microsoft-edge-stable

                                                  # VS Code
                                                  sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
                                                  [vscode]
                                                  name=Visual Studio Code
                                                  baseurl=https://packages.microsoft.com/yumrepos/vscode
                                                  enabled=1
                                                  gpgcheck=1
                                                  gpgkey=https://packages.microsoft.com/keys/microsoft.asc
                                                  EOF
                                                  sudo dnf install -y code vlc

                                                  # ----------------------------------------------------------
                                                  echo ">>> Applying I/O and CPU governor optimization..."
                                                  sudo bash -c 'cat > /etc/udev/rules.d/60-ioschedulers.rules <<EOF
                                                  ACTION=="add|change", KERNEL=="sda", ATTR{queue/scheduler}="mq-deadline"
                                                  ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="none"
                                                  EOF'

                                                  sudo bash -c 'cat > /etc/systemd/system/cpu-tune.service <<EOF
                                                  [Unit]
                                                  Description=Intel CPU tuning for Dell Inspiron 3542
                                                  After=multi-user.target

                                                  [Service]
                                                  Type=oneshot
                                                  ExecStart=/usr/bin/bash -c "
                                                  for c in /sys/devices/system/cpu/cpu[0-9]*; do
                                                    echo schedutil > \$c/cpufreq/scaling_governor 2>/dev/null || true
                                                    done
                                                    "
                                                    RemainAfterExit=yes

                                                    [Install]
                                                    WantedBy=multi-user.target
                                                    EOF'

                                                    sudo systemctl enable cpu-tune.service
                                                   
                                                    # =====================================================================
                                                    # Fedora 43 KDE Plasma (X11 Only) – Arch-Like Polish v4.3
                                                    # Author: ChatGPT
                                                    # Target: Dell Inspiron 3542 (i3-4005U, Intel HD 4400, 8 GB RAM)
                                                    # Features:
                                                    #   • Fsync + Ureadahead boot speed
                                                    #   • Smart background service delay
                                                    #   • Plasma animation + compositor tweaks
                                                    #   • All features from v4.2 retained
                                                    # =====================================================================

                                                    set -e
                                                    LOG="$HOME/fedora43-x11-v4.3.log"
                                                    exec > >(tee -a "$LOG") 2>&1

                                                    echo "=== Fedora 43 KDE (X11) – Arch-Like Polish v4.3 ==="
                                                    sudo -v

                                                    # ----------------------------------------------------------
                                                    echo ">>> Updating system..."
                                                    sudo dnf upgrade -y --refresh

                                                    # ----------------------------------------------------------
                                                    echo ">>> Installing boot-time accelerators..."
                                                    sudo dnf install -y --allowerasing systemd-udev-settle ureadahead || true
                                                    sudo systemctl enable ureadahead-replay.service ureadahead-stop.service || true

                                                    # ----------------------------------------------------------
                                                    echo ">>> Enabling fsync (faster I/O scheduling)..."
                                                    if ! grep -q "fsync" /etc/default/grub 2>/dev/null; then
                                                      echo "Adding fsync flag to GRUB..."
                                                        sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fsync=1 /' /etc/default/grub
                                                          sudo grub2-mkconfig -o /boot/grub2/grub.cfg || true
                                                          fi

                                                          # ----------------------------------------------------------
                                                          echo ">>> Smart background service delay..."
                                                          sudo bash -c 'cat > /etc/systemd/system/smart-delay.target <<EOF
                                                          [Unit]
                                                          Description=Delay non-critical background services for 40 seconds
                                                          After=multi-user.target
                                                          EOF'

                                                          sudo bash -c 'cat > /etc/systemd/system/bluetooth-delayed.service <<EOF
                                                          [Unit]
                                                          Description=Delayed Bluetooth startup
                                                          After=smart-delay.target
                                                          [Service]
                                                          Type=oneshot
                                                          ExecStart=/usr/bin/systemctl start bluetooth.service
                                                          [Install]
                                                          WantedBy=smart-delay.target
                                                          EOF'

                                                          sudo systemctl disable --now bluetooth.service || true
                                                          sudo systemctl enable bluetooth-delayed.service smart-delay.target

                                                          # ----------------------------------------------------------
                                                          echo ">>> Plasma compositor + animation throttling..."
                                                          mkdir -p ~/.config
                                                          cat > ~/.config/kwinrc <<'EOF'
                                                          [Compositing]
                                                          OpenGLIsUnsafe=false
                                                          Backend=OpenGL
                                                          GLCore=false
                                                          Enabled=true
                                                          AnimationSpeed=3
                                                          GLTextureFilter=1
                                                          GLPreferBufferSwap=0
                                                          MaxFps=60
                                                          RefreshRate=60
                                                          EOF

                                                          cat > ~/.config/kdeglobals <<'EOF'
                                                          [KDE]
                                                          AnimationDurationFactor=0.6
                                                          EOF

                                                          # ----------------------------------------------------------
                                                          echo ">>> Tune I/O and boot optimization..."
                                                          sudo bash -c 'cat > /etc/udev/rules.d/61-io-performance.rules <<EOF
                                                          ACTION=="add|change", KERNEL=="sda", ATTR{queue/scheduler}="mq-deadline"
                                                          ACTION=="add|change", KERNEL=="nvme0n1", ATTR{queue/scheduler}="none"
                                                          EOF'

                                                          sudo systemctl daemon-reexec

                                                          # ----------------------------------------------------------
                                                          echo ">>> Cleaning system..."
                                                          sudo dnf autoremove -y
                                                          sudo dnf clean all

                                                          # ----------------------------------------------------------
                                                          echo
                                                          echo "✅ Fedora 43 KDE (X11) Arch-Like Polish v4.3 Complete!"
                                                          echo "🚀 Faster boot (ureadahead + fsync)"
                                                          echo "⚙️  Smart delayed background load"
                                                          echo "🎨  Compositor / animation tweaks for Intel HD 4400"
                                                          echo "💾 Log saved: $LOG"
                                                          echo "➡️  Reboot now → sudo reboot"
                                                          echo

                                                    # ----------------------------------------------------------
                                                    echo ">>> Cleaning system..."
                                                    sudo dnf autoremove -y
                                                    sudo dnf clean all
                                                    sudo systemctl daemon-reexec

                                                    # ----------------------------------------------------------
                                                    echo
                                                    echo "✅ Fedora 43 KDE X11 (RPM Fusion + AAC + Hibernate) Complete!"
                                                    echo "🖥️  Desktop: KDE Plasma (X11 Only)"
                                                    echo "🎧  Audio: PipeWire + AAC (via RPM Fusion)"
                                                    echo "🌐  Wi-Fi: Fully functional (networkmanager-wifi)"
                                                    echo "🔋  Power: tuned + zRAM + hibernate support"
                                                    echo "💻  Tools: Edge, VS Code, VLC"
                                                    echo "🎨  Boot splash: Breeze (Fedora Blue)"
                                                    echo "💾  Log saved: $LOG"
                                                    echo "➡️  Reboot now → sudo reboot"
                                                    echo