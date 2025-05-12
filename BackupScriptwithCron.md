اگر بخواهید این اسکریپت هر روز رأس ساعت ۱ شب اجرا شود:
crontab -e

0 1 * * * /bin/bash /home/user/backup_script.sh
