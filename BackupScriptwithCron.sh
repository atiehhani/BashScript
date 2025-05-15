#!/bin/bash

# مسیر منبع (مثلاً وب‌سایت)
SOURCE="/var/www"

# مسیر مقصد بکاپ
DEST="/backup/$(date +%F)"  # بکاپ در پوشه‌ای به نام تاریخ امروز

# مسیر فایل لاگ
LOGFILE="/var/log/rsync_backup.log"

# اجرای rsync با گزینه‌های مناسب
rsync -avh --delete "$SOURCE" "$DEST" >> "$LOGFILE" 2>&1

# پیغام پایان
echo "Backup completed at $(date)" >> "$LOGFILE"

# اگر بخواهید این اسکریپت هر روز رأس ساعت ۱ شب اجرا شود: crontab -e
# 0 1 * * * /bin/bash /home/user/backup_script.sh
