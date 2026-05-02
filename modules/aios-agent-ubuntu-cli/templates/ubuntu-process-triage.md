Identify and analyze high CPU/Memory processes and resource bottlenecks.

## Steps

1. Find top CPU consumers: USE `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 10`
2. Find top Memory consumers: USE `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 10`
3. Check overall system load: USE `top -b -n 1 | head -n 15`
4. Profile specific process behavior (if stuck): USE `strace -c -p <pid>` (caution: may require permissions)
5. Identify zombie processes: USE `ps aux | awk '{ print $8 " " $2 }' | grep -w Z`
6. **Output:** Recommendations on processes to terminate or scale.
