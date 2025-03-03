#!/bin/bash

set -e

DISK="/dev/nvme0n1"
BOOT_DRIVE="${DISK}p1"
ROOT_DRIVE="${DISK}p2"
HOME_DRIVE="${DISK}p3"
USERNAME="host"
HOSTNAME="desktop"
PASSWORD="password"

read -p 'Wipe /home? [y/n] ' wipe

fdisk -W always $DISK

mkfs.fat -F 32 $BOOT_DRIVE
mkfs.ext4 -q $ROOT_DRIVE

if [[ $wipe == "y" ||  $wipe == "Y" ]]; then
	mkfs.ext4 -q $HOME_DRIVE
fi

mount $ROOT_DRIVE /mnt

mkdir -pv /mnt/boot
mkdir -pv /mnt/home

mount $BOOT_DRIVE /mnt/boot
mount $HOME_DRIVE /mnt/home

sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

reflector --latest 50 --sort rate --save /etc/pacman.d/mirrorlist

pacman -Sy archlinux-keyring --noconfirm

pacstrap /mnt base base-devel linux linux-firmware helix networkmanager grub efibootmgr polkit git

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash << EOF

sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen

locale-gen

echo $HOSTNAME >> /etc/hostname
echo "root:$PASSWORD" | chpasswd

mkinitcpio -P

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable fstrim.timer

if [ ! -d /home/$USERNAME ]; then
	useradd -m -G wheel -s /bin/bash $USERNAME
else
	useradd -G wheel -s /bin/bash $USERNAME
fi

echo "$USERNAME:$PASSWORD" | chpasswd

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/ %wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

EOF

umount -R /mnt

sleep 4

poweroff
