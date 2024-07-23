# 42 Born2BeRoot

**Disclaimer: This is only a quick and dirty writeup which was done
along the way. There might be things missing, and some things might be
wrong, or just don't work on other systems.**

I always dreamed about publishing all my passwords on github. So here are at
least the ones i used on the VM:

- root/fmaurer pw: "SuperRuut12"
- wp-admin: fmaurer / 42friedemann

## workflow

00) Boot live-cd, f.ex. https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/debian-live-12.6.0-amd64-lxqt.iso

0) Maybe... first of all... ssh to that (live cd) box in order to have copy paste
   working!! Then exec as root inside the VM:

   ```sh
   apt install openssh-server ssh
   passwd # set root pw
   echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
   systemctl start sshd
   ```
   That's it. You need to have a *bridge network* interface configured in
   VirtualBox.

1) Partition stuff with `fdisk -n`. The `-n` is short-option for `--noauto-pt`
   which is an option for not creating default (msdos) partition tables on new
   devices. I specified partition sizes using blocks to get the exact sizes (8])

2) Encrypt `/dev/sda5` using: `cryptsetup luksFormat --hash=sha512
   --key-size=512 --cipher=aes-xts-plain64 --verify-passphrase /dev/sda`

3) `cryptsetup luksOpen /dev/sda5 sda5_crypt`

4) Do the LVM stuff:
    - `pvcreate /dev/mapper/sda5_crypt`
    - `vgcreate LVMGroup /dev/mapper/sda5_crypt`
    - `lvcreate -n root -L 10G LVMGroup`
    - `lvcreate -n swap -L 2.3G LVMGroup`
    - `lvcreate -n home -L 5G LVMGroup`
    - `lvcreate -n var -L 3G LVMGroup`
    - `lvcreate -n srv -L 3G LVMGroup`
    - `lvcreate -n tmp -L 3G LVMGroup`
    - `lvcreate -n var-log -l 100%FREE LVMGroup`

41) Format partitions:
    ```sh
    mkfs.ext4 /dev/mapper/LVMGroup-root 
    mkfs.ext4 /dev/mapper/LVMGroup-home
    mkfs.ext4 /dev/mapper/LVMGroup-tmp 
    mkfs.ext4 /dev/mapper/LVMGroup-var 
    mkfs.ext4 /dev/mapper/LVMGroup-var-log
    mkswap /dev/mapper/LVMGroup-swap
    ```
42) Format EFI boot partition FAT32: `mkfs.fat -F 32 /dev/sda1`

5) `mount /dev/mapper/LVMGroup-root /mnt`

6) `debootstrap --arch amd64 stable /mnt https://deb.debian.org/debian`
   ... a lot of stuffing being installed

60) Command cluster for one-after-the-other copy-paste-use over ssh:

    ```sh
    cryptsetup luksOpen /dev/sda5 sda5_crypt
    mount /dev/LVMGroup/root /mnt
    mount --make-rslave --rbind /proc /mnt/proc
    mount --make-rslave --rbind /sys /mnt/sys
    mount --make-rslave --rbind /dev /mnt/dev
    mount --make-rslave --rbind /run /mnt/run
    chroot /mnt /bin/bash
    mount /boot

    ```
61) Mount boot-efi partition to /boot: `mount -t vfat /dev/sda1 /boot`

7) Install vim: `apt install vim` :D

8) Edit `/etc/fstab` using UUIDs for all partitions. Little trick: `lsblk -f
   /dev/sda5 >> /etc/fstab && vim /etc/fstab`. There you have all the UUIDs
   where you need them. Only root-partition gets '0 1' in field 5 & 6. voilà, le
   `/etc/fstab`:

        UUID=6278304e-a4d8-4798-b862-2c337b70c2aa / ext4 errors=remount-ro 0 1
        UUID=e791c065-cc7f-4e36-8ecf-8b0120d6db27 none swap defaults
        UUID=a7abb4a0-0a81-49f0-96a0-b081334344e2 /home ext4 defaults 0 2
        UUID=5e5671d8-db6d-4417-ae15-c381d2d45ca3 /var ext4 defaults 0 2
        UUID=48f94b9b-4e40-47f9-8e15-ce9b3c46f5db /srv ext4 defaults 0 2
        UUID=eb3867b1-94b4-471e-8762-2f74e85b1253 /tmp ext4 defaults 0 2
        UUID=4ea050bc-5431-4390-8178-54fac25bb0c5 /var/log ext4 defaults 0 2
        UUID=BC45-6D83 /boot vfat defaults 0 2

9) Set up package sources:
    ```sh
    apt install lsb-release
    export CODENAME=$(lsb_release --codename --short)
    cat > /etc/apt/sources.list << HEREDOC
    deb https://deb.debian.org/debian/ $CODENAME main contrib non-free-frimware
    deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free-frimware
    HEREDOC
    apt update

    ```
10) Config timezone & locale & ... & hostname & keyboard

    ```sh
    dpkg-reconfigure tzdata
    apt install locales
    dpkgs-reconfigure locales
    apt-search linux-image
    apt install linux-image-amd64
    apt install firmware-linux
    echo "fmaurer42" > /etc/hostname
    apt install console-setup console-setup-linux
    dpkg-reconfigure keyboard-configuration
    systemctl restart console-setup
    ```
11) Install grub, kernel image & enable OS_prober as well as crypto support in
    grub cfg. Suuuuuper hyper important first step which took me days to
    figure out:
    ```sh
    echo "sda5_crypt UUID=44c59961-7aa7-4dc9-9fcf-be283bfa93fe none luks,discard" >> /etc/crypttab
    apt install cryptsetup-initramfs
    ```

    This little `cryptsetup-initramfs` package was everything that was missing
    all the time! I am not really sure if the order is important here.. i.e.
    maybe you would have to do a little `apt install --reinstall
    cryptsetup-initramfs` somewhere again.

    ```sh
    apt install grub-efi-amd64 linux-image-amd64
    echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub 
    echo "GRUB_ENABLE_CRYPTODISK=true" >> /etc/default/grub 
    update-grub
    grub-install --target=x86_64-efi --efi-directory=/boot --recheck
    ```
    This will create /boot/grub. Ah! i forgot to mention some things i had to
    put into `/etc/default/grub`, so here is a complete listing of that file:

        GRUB_DEFAULT=0
        GRUB_TIMEOUT=5
        GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
        GRUB_ENABLE_CRYPTODISK=y
        GRUB_PRELOAD_MODULES="luks2 cryptodisk lvm"
        GRUB_CMDLINE_LINUX_DEFAULT="quiet"
        GRUB_CMDLINE_LINUX="cryptdevice=UUID=44c59961-7aa7-4dc9-9fcf-be283bfa93fe:sda5_crypt root=/dev/mapper/LVMGroup-root"

    The UUID belongs to `/dev/sda5` but the "sda5_crypt" after the colon i also
    added to `/etc/crypttab`:

        sda5_crypt UUID=44c59961-7aa7-4dc9-9fcf-be283bfa93fe none luks,discard

    **questions:** do i need this? otherwise, how will grub know what is
    sda5_crypt? find the minimal set of configuration! f.ex. do i need that
    GRUB_PRELOAD_MODULES ?!

## finally working on the system \o/

### ssh stuff

- First of all, to be able to rech the VM you have to set "Intel PRO/1000 MT
  Server (82545EM)" as Netork Interface and the "bridge" option in VirtualBox.
  Otherwise I could ssh to VM but not reach the internet from inside the VM.

- Maybe now you have to add the changed interface name to
  /etc/network/interfaces followed by a `systemctl restart networking`. Find the
  new network interface name either by `ip address` or `hwinfo --network`

- Copy ssh key to vm:
    ```sh
    ssh-copy-id -i /path/to/id_rsa.pub -p 4242 root@192.168.2.46
    ```
- Maybe put covenience in Host-`ssh_config`:

        Host 192.168.2.46
        Port 4242
        IdentityFile /path/to/id_rsa.pub

- Make sshd save again on VM. Edit `/etc/sshd_config`

        PermitRootLogin prohibit-password
        StrictModes yes
        MaxAuthTries 3
        PubkeyAuthentication yes

### ufw stuff

- Install ufw: `apt install ufw`
- Deny and allow some stuff:

    ```sh
    ufw default deny incoming
    ufw default deny outgoing # breaks everything network related...
    ufw allow 4242
    ufw enable
    ufw status verbose
    ```
- I'd like to be able to ping, buuuuut.. you cannot set ICMP related rules from
  CLI. so: edit /etc/ufw/before.rules, and add

        # allow outgoing icmp
        -A ufw-before-output -p icmp --icmp-type echo-request -j ACCEPT

  After that do a little `ufw reload` and it worghs!

- Also i like to have dns out, https & http in both directions

    ```sh
    ufw allow out dns
    ufw allow http
    ufw allow https
    ```
### appamor & selinux

- Install stuff: `apt install apparmor apparmor-utils`
- https://wiki.debian.org/AppArmor/HowToUse says, in order to activate apparmor
  add kernel cmdline:

    ```sh
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT apparmor=1 security=apparmor"' > /etc/default/grub.d/apparmor.cfg 
    
    ## alternatively, if you work with sudo all the time:
    # echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT apparmor=1 \
    # security=apparmor"' | sudo tee /etc/default/grub.d/apparmor.cfg

    update-grub
    ```
- (i did not need to add kernel cmdline... apparmor still seemed to be running)
  appamor is already installed. Find out status:

    ```sh
    # returns 'Y' if true
    cat /sys/module/apparmor/parameters/enabled

    # list all loaded appamor profiles end detail status (enforced, complain,
    # unconfined):
    aa-status

    # list running exes which are currently confined
    ps auxZ | grep -v '^unconfined'

    # list of processes with tcp or udp ports that do not have appamor profiles
    # loaded:
    aa-unconfined
    aa-unconfined --paranoid

    ```
- Well, SElinux (https://wiki.debian.org/SELinux/Setup):

    ```sh
    apt-get install selinux-basics selinux-policy-default auditd
    selinux-activate
    # reboot.. and check
    check-selinux-installation # or more communicative:
    sestatus

    # see logged denials:
    audit2why -al
    ```
    more literature: [SELinux vs. AppArmor](https://www.computerweekly.com/de/tipp/SELinux-vs-AppArmor-Vergleich-der-Linux-Sicherheitssysteme)

### sudo, etc...

- `addgroup user42 && usermod -aG user42,sudo fmaurer`
- Password stuff:

    ```sh
    vim /etc/login.defs

    ...
    PASS_MAX_DAYS 30
    PASS_MIN_DAYS 2
    PASS_WARN_AGE 7
    ```
- Install libpam-pwquality and cracklib:
  `apt install -y libpam-pwquality cracklib-runtime`

- Edit `/etc/pam.d/common-password`:

        password        requisite                       pam_pwquality.so retry=3 minlen=10 maxrepeat=3 ucredit=-1 lcredit=-1 dcredit=-1 difok=7 gecoscheck=1 reject_username enforce_for_root
    + difok: the number of chars not present in the old pw
    + u/l/dcredit: =-1 is minimum number of upper/lower/digits
    + another option - ocredit: other chars, f.ex. '#' 

- Add with visudo:

        # Born2BeRoot stuff
        Defaults        requiretty
        Defaults        logfile="/var/log/sudo/sudo.log"
        Defaults        passwd_tries=3
        Defaults        badpass_message="Forgot pw? One hint: it is not 42!"
        Defaults        log_input,log_output
        Defaults        iolog_dir=/var/log/sudo/sudo-io/%{user}

        # User privilege specification
        root    ALL=(ALL:ALL) LOG_INPUT: LOG_OUTPUT: ALL

        # Allow members of group sudo to execute any command
        %sudo   ALL=(ALL:ALL) LOG_INPUT: LOG_OUTPUT: ALL

- For daily rotation of sudo.log add to `/etc/logrotate.d/sudo`:

        /var/log/sudo/sudo.log {
        rotate 12
        daily
        compress
        missingok
        notifempty
        }

### monitoring.sh

- 1KB = 1 kilobyte = 1000 bytes. However in reference to RAM: 1 KB = 1
  **kibibyte** = 1024 bytes = 2^10 bytes. normally this should be denoted by
  1KiB **not** 1KB to emphasize the difference.

  So, as we are talking about memory here i will use kibi- and mebibytes: 1 KiB
  = 1024 Bytes and 1 MiB = 1024 KiB. Also, values in `/proc/meminfo` are also in
  KiB

- Nice cmdlines for testing load on VM:

    ```sh
    cat /dev/urandom | gzip -9 > /dev/null

    # even more load:
    cat /dev/urandom | gzip -9 | gzip -d | gzip -9 | gzip -d > /dev/null
    ```
- General note on cpu load:

        a cpu load of 1.0 means that one core is working at 100%. a load of 2.0
        means that 2 cores are working 100% and so on, if you are on multi-core
        system. on a single-core system a load of <1.0 means that there are still
        free computing ressources left. if you reach load >1.0 on single-core
        then tasks will have to wait for their compute time.


### lighttpd & wordpress

 - wpdb-user: wpuse, pw: wortpresse

 everything i have done:

 ```sh
 apt-get install mariadb-server lighttpd php php-fpm php-mysql php-cli php-curl php-xml php-json php-zip php-mbstring php-gd php-intl php-cgi -y

# apache is automatically installed, so: remove
apt-get remove apache2 -y
systemctl stop apache2

systemctl start lighttpd
systemctl enable lighttpd

vim /etc/php/8.2/fpm/pool.d/www.conf
# replace the line
#   listen = /run/php/php7.4-fpm.sock
# by
#   listen = 127.0.0.1:9000

vim /etc/lighttpd/conf-available/15-fastcgi-php.conf
# find following lines:
#   "bin-path" => "/usr/bin/php-cgi",
#   "socket" => "/var/run/lighttpd/php.socket",
# an replace with:
#   "host" => "127.0.0.1",
#   "port" => "9000",

# create wpdb:

mysql
#   CREATE DATABASE wpdb;
#   GRANT ALL PRIVILEGES on wpdb.* TO 'wpuser'@'localhost' IDENTIFIED BY 'password';
#   FLUSH PRIVILEGES;
#   EXIT;

# install wp:

cd /srv
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
cd wordpress
mv wp-config-sample.php wp-config.php
vim wp-config.php
#    /** The name of the database for WordPress */
#    define( 'DB_NAME', 'wpdb' );
#   
#    /** MySQL database username */
#    define( 'DB_USER', 'wpuser' );
#   
#    /** MySQL database password */
#    define( 'DB_PASSWORD', 'password' );
#   
#    /** MySQL hostname */
#    define( 'DB_HOST', 'localhost' );
#   
#    /** Database Charset to use in creating database tables. */
#    define( 'DB_CHARSET', 'utf8' );
chown -R www-data:www-data /srv/wordpress
chmod -R 755 /srv/wordpress

# configure lighty for wp:

mkdir -p /etc/lighttpd/vhosts/
vim /etc/lighttpd/lighttpd.conf
# insert:
#    server.modules = (
#            "mod_access",
#            "mod_alias",
#            "mod_compress",
#            "mod_redirect",
#            "mod_rewrite",
#    )
#   include "cat /etc/lighttpd/vhosts/*.conf"

# ssl stuff:

mkdir -p /etc/lighttpd/ssl/fmaurer42 && cd !$
openssl req -new -newkey rsa:2048 -nodes -keyout server.com.key -out server.com.csr
openssl x509 -req -days 365 -in server.com.csr -signkey server.com.key -out server.com.crt
cat server.com.key server.com.crt > server.pem

vim /etc/lighttpd/vhosts/wordpress.conf
# insert:
#   $HTTP["scheme"] == "http" {
#           $HTTP["host"] == "fmaurer42" {
#                   url.redirect = ("/.*" => "https://fmaurer42$0")
#           }
#   }
#   $SERVER["socket"] == ":443" {
#   ssl.engine = "enable"
#   ssl.pemfile = "/etc/lighttpd/ssl/fmaurer42/server.pem"
#   ssl.ca-file = "/etc/lighttpd/ssl/fmaurer42/server.com.crt"
#
#   server.name = "fmaurer42"
#   server.document-root = "/srv/wordpress"
#   server.errorlog = "/var/log/lighttpd/wp-error.log"
#   accesslog.filename = "/var/log/lighttpd/wp-access.log"
#   }

lighty-enable-mod fastcgi
lighty-enable-mod fastcgi-php
lighty-enable-mod ssl

# test lighty config
sudo lighttpd -t -f /etc/lighttpd/lighttpd.conf

# go!
systemctl restart php8.2-fpm
systemctl restart lighttpd
 ```

 #### wp password issue

- pw www-data: K0mplexe2$!pw1
- `apt install curl`
- `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar`
- `./wp-cli.phar user update fmaurer --user_pass="fmaurer" --path='/srv/wordpress'`

#### wp update hostname / ip

Well, idk if this is the best solution (i guess there might be something
possible using rewrite rules of lighttpd) but it works.

The Problem: wordpress hardcodes the IP of the VM into its database. But when we
launch the VM it receives a new IP from DHCP. So i use `wp-cli` in a little
script to replace the old ip with the new one in wp's database. The script:

```bash
#!/bin/bash
# script for updating wp after vm reboot and receiving new ip from dhpc

oldip=$(sudo -u www-data -- ./wp-cli.phar --path=./wordpress option get siteurl)
ip="https://$(hostname -I)"
sudo -u www-data -- ./wp-cli.phar search-replace $oldip $ip --path=./wordpress
```

## unordered notes

### nixos / bridge network related note

Add to `configuration.nix`:

```nix
networking = {
    nat = {
        enable = true;
        internalInterfaces = [ "virbr0" ];
        externalInterface = "wlp0s20f3";
    };
    bridges.virbr0.interfaces = [];
    interfaces.virbr0 = {
        ipv4.addresses = [
        {address = "192.168.122.1"; prefixLength = 24; }
        ];
    };
};

networking.hosts = {
    "192.168.122.42" = [ "fmaurer42" ]

};

```

This will create a new virtual bridge-interface with subnet 192.168.122.0/24.
now inside the VM all we need is "nameserver 8.8.8.8" in `/etc/resolv.conf`
aaand an `/etc/network/interfaces` like this:

```sh
auto lo
iface lo inet loopback

allow-hotplug enp0s17
iface enp0s17 inet static
	address 192.168.122.42
	gateway 192.168.122.1
```

### something interesting about `ping`

    The standard ping command does not use TCP or UDP. It uses ICMP. To be more
    precise ICMP type 8 (echo message) and type 0 (echo reply message) are used.
    ICMP has no ports!

    See RFC792 for further details.

### some strange error occured:

    root@fmaurer42:/# apt install dpkg
    E: Could not open lock file /var/lib/dpkg/lock-frontend - open (2: No such file or directory)
    E: Unable to acquire the dpkg frontend lock (/var/lib/dpkg/lock-frontend), are you root?

Fix was: `dpkg --configure -a`. This created all the files again.

### ssh hack

- `apt install net-tools` for ifconfig
- `apt install openssh-server` for sshd
- edit /etc/ssh/sshd_config: 'PermitRootLogin yes' :evil_face:
- change network in VirtualBox to 'bridge'
- ssh to vm \o/

### crypt

`cryptsetup luksFormat --hash=sha512 --key-size=512 --cipher=aes-xts-plain64 --verify-passphrase /dev/sda`

### partitioning

- Install lvm-tools: `sudo apt install lvm2`
- List of LVM commands:
	`lvmchange` — Change attributes of the Logical Volume Manager.
	`lvmdiskscan` — Scan for all devices visible to LVM2.
	`lvmdump` — Create lvm2 information dumps for diagnostic purposes. 
- To declare the /dev/sda2 as a physical volume available for the LVM:
  `sudo pvcreate /dev/sda2`
- List of PV commands:
    `pvchange` — Change attributes of a Physical Volume.
    `pvck` — Check Physical Volume metadata.
    `pvcreate` — Initialize a disk or partition for use by LVM.
    `pvdisplay` — Display attributes of a Physical Volume.
    `pvmove` — Move Physical Extents.
    `pvremove` — Remove a Physical Volume.
    `pvresize` — Resize a disk or partition in use by LVM2.
    `pvs` — Report information about Physical Volumes.
    `pvscan` — Scan all disks for Physical Volumes. 
- Create volume group: `sudo vgcreate myVirtualGroup1 /dev/sda2`
- Verify VG configuration, Simply run this command: `sudo vgdisplay`
- Create an LV. <!> Don't forget to check that you have enough space: naturally,
  an LV of 100 GB (Giga Bytes) doesn't fit in a 10 GB Virtual Group.
  Create a logical volume in a volume group:
  `sudo lvcreate -n myLogicalVolume1 -L 10g myVirtualGroup1`
  Format the logical volume to the filesystem you want (ext4,xfs...)
  `sudo mkfs -t ext4 /dev/myVirtualGroup1/myLogicalVolume1`
  You can test to see if it's working:
  `mkdir /test`
  `sudo mount /dev/myVirtualGroup1/myLogicalVolume1 /test`
  `df -h`
  You also can check your logical volumes with:
  `sudo lvdisplay`
