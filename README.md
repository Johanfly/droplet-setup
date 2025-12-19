# Panduan Lengkap Setup Droplet

![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-E95420?logo=ubuntu&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?logo=nginx&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-6.0-47A248?logo=mongodb&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-22.x-339933?logo=node.js&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.0-777BB4?logo=php&logoColor=white)

> **Secure droplet setup with Tailscale P2P VPN and Cloudflare proxy.**  
> No public ports exposed - SSH via Tailscale only, web traffic through Cloudflare.  
> Multi-layer security: UFW + Fail2ban + Cloudflare WAF

## 🔐 Security Features

| Layer | Protection |
|-------|------------|
| **Network** | Tailscale P2P VPN - SSH tidak terekspos ke public internet |
| **Firewall** | UFW - Hanya allow Cloudflare IPs untuk port 80/443 |
| **Intrusion** | Fail2ban - Auto-ban IP setelah failed login attempts |
| **WAF** | Cloudflare - DDoS protection, bot filtering, SSL termination |
| **Access** | Key-based SSH only, root login disabled |

## 🛠️ Tech Stack

- **OS**: Ubuntu 22.04.5 LTS (Jammy)
- **Web Server**: Nginx
- **Database**: MongoDB 6.0 / MySQL 8.0
- **Runtime**: Node.js v22.x / PHP 8.0
- **Process Manager**: PM2
- **VPN**: Tailscale
- **CDN/Proxy**: Cloudflare

## 📁 Struktur Repository

```
droplet-setup/
├── README.md
├── LICENSE
├── .gitignore
├── scripts/
│   ├── setup-cloudflare-firewall.sh   # Setup firewall untuk Cloudflare
│   ├── update-cloudflare-ips.sh       # Auto-update Cloudflare IPs
│   └── wait-for-tailscale.sh          # Wait script untuk SSH after Tailscale
├── configs/
│   ├── nginx/
│   │   ├── laravel-example.conf       # Nginx config untuk Laravel
│   │   └── node-example.conf          # Nginx config untuk Node.js
│   ├── php-fpm/
│   │   └── pool-example.conf          # PHP-FPM pool config
│   ├── fail2ban/
│   │   ├── jail.local                 # Fail2ban jail config
│   │   └── sshd-aggressive.conf       # Aggressive SSH filter
│   └── logrotate/
│       ├── mongodb                    # Logrotate untuk MongoDB
│       ├── pm2                        # Logrotate untuk PM2/Node.js
│       └── laravel                    # Logrotate untuk Laravel logs
```

---

## Step 1: Copy SSH Key ke Server

```bash
cat ~/.ssh/id_ed25519.pub | ssh root@IP_DROPLET "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
```

---

## Step 2: Login sebagai Root & Buat Daily User

```bash
ssh root@IP_DROPLET

# Update system
apt update && apt upgrade -y

# Set permission SSH
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Buat user baru
adduser dailyuser
usermod -aG sudo dailyuser

# Copy SSH key ke user baru
cp -r ~/.ssh /home/dailyuser
chmod 700 /home/dailyuser/.ssh
chmod 600 /home/dailyuser/.ssh/authorized_keys
chown -R dailyuser:dailyuser /home/dailyuser/.ssh

exit
```

---

## Step 3: Login sebagai Daily User & Lock Root

```bash
ssh dailyuser@IP_DROPLET

# Lock akun root
sudo passwd -l root
```

### Setup Swap Memory (Jika Belum Ada)

```bash
# Cek status swap
free -h
swapon --show

# Buat swap 2GB jika belum ada
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verifikasi
free -h
```

---

## Step 4: Install Packages

### Tambah Repository MongoDB

```bash
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
```

### Tambah Repository PHP

```bash
sudo add-apt-repository ppa:ondrej/php
```

### Install Semua Package

```bash
sudo apt update
sudo apt install zsh git-core curl software-properties-common nginx mysql-server unzip fail2ban acl \
    php8.0 php8.0-cli php8.0-common php8.0-mbstring php8.0-xml php8.0-mysql php8.0-curl \
    php8.0-gd php8.0-fpm php8.0-intl php8.0-zip mongodb-org
```

### Setup User untuk Web Development

Setelah Nginx terinstall, group `www-data` sudah tersedia:

```bash
# Tambahkan dailyuser ke group www-data
sudo usermod -aG www-data $USER

# Logout dan login lagi agar group aktif
exit
```

Login kembali, lalu setup ACL:

```bash
ssh dailyuser@IP_DROPLET

# Verifikasi group
groups
# Output: username sudo www-data

# Buat direktori web
sudo mkdir -p /var/www

# Set ownership dan permissions
sudo chown -R www-data:www-data /var/www
sudo chmod -R 775 /var/www

# Setup ACL agar current user bisa read/write/execute
sudo setfacl -R -m u:$USER:rwx /var/www
sudo setfacl -R -d -m u:$USER:rwx /var/www

# Verifikasi ACL
getfacl /var/www
```

> **Catatan ACL:**
> - `-R` = recursive (semua subdirectory)
> - `-d` = default ACL (berlaku untuk file/folder baru)
> - `-m u:$USER:rwx` = current user dapat read, write, execute

---

## Step 5: Setup Oh-My-Zsh

```bash
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Install plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
```

Edit `~/.zshrc`:

```bash
# Hindari duplikat di history
setopt HIST_IGNORE_ALL_DUPS    # Hapus duplikat lama, simpan yang baru
setopt HIST_FIND_NO_DUPS       # Jangan tampilkan duplikat saat search
setopt HIST_SAVE_NO_DUPS       # Jangan tulis duplikat ke file
HISTORY_IGNORE="(reboot|shutdown|poweroff|halt|init 0|init 6)"

plugins=( 
    zsh-autosuggestions
    fast-syntax-highlighting
)

# Alias untuk bersihkan duplikat history
alias cleanhis='sort -t ";" -k2 -u ~/.zsh_history > /tmp/zsh_history_clean && mv /tmp/zsh_history_clean ~/.zsh_history && fc -R && echo "✅ History c
leaned!"'
```

```bash
source ~/.zshrc
```

---

## Step 6: Install Tailscale (P2P VPN)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Enable & start service
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo systemctl status tailscaled

# Login (akan muncul link untuk auth)
sudo tailscale up
```

> **Note:** Buka link yang muncul di browser dan login dengan akun Tailscale Anda.

```bash
# Cek IP Tailscale (catat IP ini, contoh: 100.xx.x.x)
tailscale ip -4
tailscale status
```

### Install Tailscale di Device Lokal

Download dari: https://tailscale.com/download

- **Linux**: `curl -fsSL https://tailscale.com/install.sh | sh`
- **macOS/Windows**: Download dari website
- **iOS/Android**: Download dari App Store/Play Store

> **Penting:** Login dengan akun Tailscale yang sama!

---

## Step 7: Konfigurasi SSH (Hanya via Tailscale)

```bash
sudo nano /etc/ssh/sshd_config
```

Edit menjadi:

```bash
Port 2222
ListenAddress 100.xx.x.x    # Ganti dengan IP Tailscale droplet
ListenAddress 127.0.0.1
PermitRootLogin no 
PubkeyAuthentication yes 
PasswordAuthentication no
```

### Buat Script Wait for Tailscale

```bash
sudo cp scripts/wait-for-tailscale.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/wait-for-tailscale.sh
```

### Buat Systemd Override untuk SSH

```bash
sudo systemctl edit ssh
```

Isi:

```ini
[Unit]
After=tailscaled.service network-online.target
Wants=tailscaled.service

[Service]
ExecStartPre=/usr/local/bin/wait-for-tailscale.sh
```

### Reload & Restart

```bash
sudo systemctl daemon-reload
sudo systemctl restart sshd
sudo systemctl status sshd

# Verifikasi
sudo lsof -i :2222
```

### Login SSH dengan Port Custom dan IP Tailscale

```bash
ssh -p 2222 dailyuser@100.xx.x.x    # Ganti dengan IP Tailscale droplet
```

---

## Step 8: Konfigurasi Fail2ban

```bash
# Copy config dari repo
sudo cp configs/fail2ban/jail.local /etc/fail2ban/
sudo cp configs/fail2ban/sshd-aggressive.conf /etc/fail2ban/filter.d/

# Set permissions
sudo chmod 644 /etc/fail2ban/jail.local
sudo chmod 644 /etc/fail2ban/filter.d/sshd-aggressive.conf

# Edit jail.local, tambahkan IP Tailscale device Anda di ignoreip
sudo nano /etc/fail2ban/jail.local

# Test & start
sudo fail2ban-client -t
sudo systemctl start fail2ban.service
sudo systemctl enable fail2ban.service
sudo fail2ban-client status
```

---

## Step 9: Konfigurasi UFW Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow semua traffic dari interface Tailscale
sudo ufw allow in on tailscale0 comment "Tailscale interface"

# Setup firewall untuk Cloudflare
# Domain sudah di set NS ke Cloudflare dan A record pointing ke IP droplet (Orange cloud)
./scripts/setup-cloudflare-firewall.sh

# Enable firewall
sudo ufw enable
sudo ufw status numbered
```

### Auto-Update Cloudflare IPs (Cron)

```bash
# Setup cron job untuk update Cloudflare IPs setiap bulan
sudo crontab -e
```

Tambahkan:

```cron
0 0 1 * * /path/to/droplet-setup/scripts/update-cloudflare-ips.sh >> /var/log/cloudflare-update.log 2>&1
```

---

## Step 10: Konfigurasi MySQL

```bash
# Stop MySQL
sudo systemctl stop mysql.service

# Edit service untuk skip auth sementara
sudo nano /lib/systemd/system/mysql.service
```

Ubah ExecStart menjadi:

```bash
ExecStart=/usr/sbin/mysqld --skip-grant-tables --skip-networking
```

```bash
sudo systemctl daemon-reload
sudo systemctl start mysql.service
sudo mysql -u root
```

```sql
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'NEW_PASSWORD';
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Kembalikan config normal
sudo nano /lib/systemd/system/mysql.service
```

Ubah kembali:

```bash
ExecStart=/usr/sbin/mysqld
```

```bash
sudo systemctl daemon-reload
sudo systemctl start mysql.service
sudo systemctl enable mysql.service
sudo mysql_secure_installation
```

### Buat Database & User

```bash
sudo mysql -u root -p
```

```sql
CREATE DATABASE nama_database;
CREATE USER 'db_user'@'%' IDENTIFIED WITH caching_sha2_password BY 'DB_PASSWORD';
GRANT ALL ON nama_database.* TO 'db_user'@'%';
FLUSH PRIVILEGES;
EXIT;
```

---

## Step 11: Konfigurasi MongoDB dengan Authentication

### Start MongoDB

```bash
sudo systemctl start mongod
sudo systemctl enable mongod
sudo systemctl status mongod
```

### Buat Admin User

```bash
mongosh
```

```javascript
use admin

// Buat admin user
db.createUser({
  user: "adminUser",
  pwd: "ADMIN_PASSWORD",
  roles: [
    { role: "userAdminAnyDatabase", db: "admin" },
    { role: "readWriteAnyDatabase", db: "admin" }
  ]
})

// Buat user untuk aplikasi
use nama_database
db.createUser({
  user: "appUser",
  pwd: "APP_PASSWORD",
  roles: [
    { role: "readWrite", db: "nama_database" }
  ]
})

exit
```

### Enable Authentication

```bash
sudo nano /etc/mongod.conf
```

Tambahkan/edit bagian security:

```yaml
security:
  authorization: enabled
```

Optional - bind ke localhost saja:

```yaml
net:
  port: 27017
  bindIp: 127.0.0.1
```

```bash
# Restart MongoDB
sudo systemctl restart mongod
sudo systemctl status mongod
```

### Test Login dengan Auth

```bash
# Login sebagai admin
mongosh -u adminUser -p --authenticationDatabase admin

# Login sebagai app user
mongosh -u appUser -p --authenticationDatabase nama_database
```

### Connection String untuk Aplikasi

```
mongodb://appUser:APP_PASSWORD@localhost:27017/nama_database
```

Atau dengan authentication database:

```
mongodb://appUser:APP_PASSWORD@localhost:27017/nama_database?authSource=nama_database
```

---

## Step 12: Install Node.js via NVM

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
source ~/.zshrc

nvm install v22.17.0
nvm use v22.17.0
nvm alias default v22.17.0
```

---

## Step 13: Setup PM2 (Node.js Process Manager)

```bash
npm install -g pm2

# Start aplikasi
cd /path/to/app
npm install
pm2 start server.js --name app_name

# Auto-start saat server reboot
pm2 startup
pm2 save

# Monitoring
pm2 list
pm2 logs app_name
pm2 monit
```

---

## Step 14: Setup PHP-FPM Pool

```bash
# Copy config dan sesuaikan
sudo cp configs/php-fpm/pool-example.conf /etc/php/8.0/fpm/pool.d/domain.com.conf
sudo nano /etc/php/8.0/fpm/pool.d/domain.com.conf
```

Ganti `example.com` dengan domain Anda.

```bash
sudo systemctl restart php8.0-fpm
sudo systemctl enable php8.0-fpm
```

---

## Step 15: Deploy Laravel Application

### Clone/Upload Project

```bash
cd /var/www
sudo git clone [REPO_URL] domain.com
# atau upload via rsync/scp

sudo chown -R $USER:www-data /var/www/domain.com
sudo chmod -R 775 /var/www/domain.com/storage
sudo chmod -R 775 /var/www/domain.com/bootstrap/cache
```

### Install Dependencies

```bash
cd /var/www/domain.com

# Install Composer jika belum ada
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install dependencies
composer install --optimize-autoloader --no-dev
```

### Setup Environment

```bash
cp .env.example .env
nano .env
```

Edit `.env` sesuai environment production:

```env
APP_NAME="Nama Aplikasi"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://domain.com

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=nama_database
DB_USERNAME=db_user
DB_PASSWORD=DB_PASSWORD

# Jika pakai MongoDB
# MONGODB_URI=mongodb://appUser:APP_PASSWORD@localhost:27017/nama_database
```

### Laravel Artisan Commands

```bash
cd /var/www/domain.com

# Generate application key
php artisan key:generate

# Run migrations
php artisan migrate

# Run seeders (jika ada)
php artisan db:seed

# Create storage symlink
php artisan storage:link

# Clear & optimize cache
php artisan optimize:clear
php artisan optimize

# Cache config & routes untuk production
php artisan config:cache
php artisan route:cache
php artisan view:cache
```

### Set Final Permissions

```bash
sudo chown -R www-data:www-data /var/www/domain.com
sudo find /var/www/domain.com -type f -exec chmod 644 {} \;
sudo find /var/www/domain.com -type d -exec chmod 755 {} \;
sudo chmod -R 775 /var/www/domain.com/storage
sudo chmod -R 775 /var/www/domain.com/bootstrap/cache
```

---

## Step 16: Konfigurasi Nginx Global

Edit file konfigurasi utama Nginx:

```bash
sudo nano /etc/nginx/nginx.conf
```

Tambahkan/edit setting berikut di dalam block `http { }`:

```nginx
http {
    # Security - Sembunyikan versi Nginx
    server_tokens off;
    
    # Performance - Hash table size
    types_hash_max_size 2048;
    server_names_hash_bucket_size 64;
    
    # Limit request body size (optional, default 1M)
    client_max_body_size 50M;
    
    # ... sisanya biarkan default ...
}
```

> **Catatan:** 
> - `server_tokens off` - Menyembunyikan versi Nginx di response header (security)
> - `types_hash_max_size 2048` - Mencegah warning saat banyak MIME types
> - `server_names_hash_bucket_size 64` - Untuk domain name yang panjang

---

## Step 17: Setup Nginx Site Config

### Copy Config dan Sesuaikan

```bash
# Untuk Laravel
sudo cp configs/nginx/laravel-example.conf /etc/nginx/sites-available/domain.com.conf

# Atau untuk Node.js
sudo cp configs/nginx/node-example.conf /etc/nginx/sites-available/domain.com.conf

# Edit sesuai domain
sudo nano /etc/nginx/sites-available/domain.com.conf
```

### Enable Site

```bash
sudo ln -s /etc/nginx/sites-available/domain.com.conf /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

---

## Step 18: Setup Logrotate

Logrotate sudah terinstall secara default di Ubuntu. Beberapa service sudah memiliki config bawaan, tetapi kita perlu menambahkan untuk aplikasi custom.

### Cek Config Bawaan

```bash
# Lihat config logrotate yang sudah ada
ls -la /etc/logrotate.d/
```

Config yang biasanya sudah ada:
- `/etc/logrotate.d/nginx` - Nginx logs
- `/etc/logrotate.d/mysql-server` - MySQL logs
- `/etc/logrotate.d/php8.0-fpm` - PHP-FPM logs
- `/etc/logrotate.d/fail2ban` - Fail2ban logs

### Tambahkan Config untuk MongoDB

```bash
sudo nano /etc/logrotate.d/mongodb
```

Isi:

```
/var/log/mongodb/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 640 mongodb mongodb
    sharedscripts
    postrotate
        /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod.pid 2>/dev/null) 2>/dev/null || true
    endscript
}
```

### Tambahkan Config untuk PM2 (Node.js)

```bash
sudo nano /etc/logrotate.d/pm2
```

Isi:

```
/home/dailyuser/.pm2/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644 dailyuser dailyuser
    sharedscripts
    postrotate
        /usr/bin/pm2 reloadLogs > /dev/null 2>&1 || true
    endscript
}
```

### Tambahkan Config untuk Laravel Logs

```bash
sudo nano /etc/logrotate.d/laravel
```

Isi:

```
/var/www/*/storage/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 664 www-data www-data
    sharedscripts
}
```

### Test Logrotate

```bash
# Test tanpa rotate (dry-run)
sudo logrotate -d /etc/logrotate.d/mongodb
sudo logrotate -d /etc/logrotate.d/pm2
sudo logrotate -d /etc/logrotate.d/laravel

# Force rotate untuk test
sudo logrotate -f /etc/logrotate.d/mongodb
```

### Cek Status Logrotate

```bash
# Lihat log terakhir logrotate
cat /var/lib/logrotate/status

# Cek cron job
cat /etc/cron.daily/logrotate
```

> **Catatan Logrotate:**
> - `daily` = rotate setiap hari (bisa `weekly`, `monthly`)
> - `rotate 14` = simpan 14 file backup
> - `compress` = compress file lama dengan gzip
> - `delaycompress` = compress setelah 1 rotasi (agar log masih bisa dibaca)
> - `missingok` = jangan error jika file tidak ada
> - `notifempty` = jangan rotate jika file kosong
> - `create` = buat file baru dengan permission tertentu
> - `postrotate/endscript` = command yang dijalankan setelah rotate

---

## 🔧 Useful Commands

### Service Status

```bash
sudo systemctl status nginx
sudo systemctl status php8.0-fpm
sudo systemctl status mysql
sudo systemctl status mongod
sudo systemctl status fail2ban
sudo systemctl status tailscaled
```

### Logs

```bash
# Nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log

# Fail2ban
sudo tail -f /var/log/fail2ban.log
sudo fail2ban-client status sshd

# Auth (SSH attempts)
sudo tail -f /var/log/auth.log
```

### Firewall

```bash
sudo ufw status numbered
sudo ufw delete [number]
```

### PM2

```bash
pm2 list
pm2 logs
pm2 restart all
pm2 reload all
```

---

## 📜 License

MIT License - lihat file [LICENSE](LICENSE) untuk detail.
