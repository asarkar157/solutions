Grep and identify application anomalies from system and application logs.

## Steps

1. Check system syslog for recent errors: USE `tail -n 200 /var/log/syslog | grep -i 'error\|panic\|fatal'`
2. Check dmesg for kernel-level / hardware errors or OOM kills: USE `dmesg -T | grep -i 'killed process\|oom'`
3. Check specific application service logs: USE `grep -C 2 -i "Exception" <log_file>`
4. Count frequency of specific HTTP status codes: USE `awk '{print $9}' access.log | sort | uniq -c | sort -rn`
5. **Assessment:** Pinpoint the exact timestamp and context of application exceptions.
