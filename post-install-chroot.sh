#!/usr/bin/env bash

set -exo pipefail

usage()
{
   # Display Help
   echo "Run this script as chroot after base arch install."
   echo
   echo "Syntax: post-install-chroot.sh [-h] [-b grub|systemd-boot, -u USER]"
   echo "options:"
   echo "h      Print this Help."
   echo "-b     Supply systemd-boot or grub"
   echo "-u     Set new username"
   echo
}

# check for root
if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root!"
    exit 1
fi

while getopts ":hb:u:" option; do
    case $option in
        h)
            usage
            exit;;
        b)
            bootloader=$OPTARG;;
        u)
            user=$OPTARG;;
        \?)
            echo "Error: Invalid option"
            usage
            exit;;
    esac
done

# install extra packages
pacman -S --noconfirm \
    sudo \
    openssh \
    reflector \
    exa \
    zoxide \
    bat \
    podman \
    podman-compose \
    zsh \
    man-db \
    man-pages \
    plocate \
    neovim \
    polkit

# give wheel group sudo privileges
sed -i '/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/c\%wheel ALL=(ALL:ALL) NOPASSWD: ALL' /etc/sudoers

# add network interface for systemd-networkd
cat <<'EOF' >> /etc/systemd/network/wired.network
[Match]
Name=enp1s0

[Network]
DHCP=yes
EOF

# change ssh settings
sed -i '/#PermitRootLogin prohibit-password/c\PermitRootLogin no' /etc/ssh/sshd_config
sed -i '/#StrictModes yes/c\StrictModes yes' /etc/ssh/sshd_config
sed -i '/#PubkeyAuthentication yes/c\PubkeyAuthentication yes' /etc/ssh/sshd_config
sed -i '/#PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config
sed -i '/#PermitEmptyPasswords no/c\PermitEmptyPasswords no' /etc/ssh/sshd_config

# change pacman settings
sed -i '/#VerbosePkgLists/c\VerbosePkgLists' /etc/pacman.conf
sed -i '/#Color/a\ILoveCandy' /etc/pacman.conf
sed -i '/#Color/c\Color' /etc/pacman.conf

# change reflector settings
cat <<'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol https
--country Netherlands
--latest 5
--sort rate
EOF

# enable systemd services
systemctl enable systemd-networkd systemd-resolved
systemctl enable reflector.timer
systemctl enable sshd

configuki()
{
    sed -i '/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/c\HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)' /etc/mkinitcpio.conf
    echo 'rw' >> /etc/kernel/cmdline
    echo 'KEYMAP=us' >> /etc/vconsole.conf
    sed -i "/PRESETS=('default' 'fallback')/c\PRESETS=('default')" /etc/mkinitcpio.d/linux.preset
    sed -i '/default_image/c\#default_image' /etc/mkinitcpio.d/linux.preset
    sed -i '/#default_uki/c\default_uki="/efi/EFI/Linux/arch-linux.efi"' /etc/mkinitcpio.d/linux.preset
    mkinitcpio -P
    rm -rf /boot/initramfs*
}

intallgrub()
{
    pacman -S --noconfirm grub
    grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=grub
    sed -i '/loglevel=3 quiet/c\loglevel=3 nowatchdog'
    grub-mkconfig -o /boot/grub/grub.cfg
}

installuki()
{
    mkdir -p /efi/EFI/Linux
    configuki
    efibootmgr --create --disk /dev/vda --part 1 --label "Arch Linux" --loader "\EFI\Linux\arch-linux.efi" --unicode
    pacman -S --noconfirm sbctl
    sbctl create-keys
    sbctl enroll-keys -m
    sbctl sign -s /efi/EFI/Linux/arch-linux.efi
}
installsystemdboot()
{
    bootctl install
    configuki
    pacman -S --noconfirm sbctl
    sbctl create-keys
    sbctl enroll-keys -m
    sbctl sign -s /efi/EFI/Linux/arch-linux.efi
    sbctl sign -s /efi/EFI/BOOT/BOOTX64.EFI
    sbctl sign -s /efi/EFI/systemd/systemd-bootx64.efi
    sbctl sign -s /usr/lib/systemd/boot/efi/systemd-bootx64.efi -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed
}

case $bootloader in
    grub) # install grub
        installgrub;;
    uki) # install unified kernel image
        installuki;;
    systemd-boot) # install systemd-boot
        installsystemdboot;;
    *)
        echo "No bootloader installed";;
esac

# add user
useradd -mG wheel -s /usr/bin/zsh $user
passwd $user
