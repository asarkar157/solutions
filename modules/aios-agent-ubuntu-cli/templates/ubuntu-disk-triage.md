Diagnose disk space exhaustion, inode limits, and file descriptor leaks.

## Steps

1. Check overall disk capacity: USE `df -h`
2. Check inode usage (if disks show free space but writes fail): USE `df -i`
3. Find largest directories in var/log: USE `du -sh /var/log/* | sort -rh | head -n 10`
4. Check for open file descriptor limits: USE `cat /proc/sys/fs/file-nr`
5. Find processes with most open files: USE `lsof | awk '{print $1}' | sort | uniq -c | sort -rn | head -10`
6. **Risk assessment:** Flag partition usage > 85% or inodes > 90%.
