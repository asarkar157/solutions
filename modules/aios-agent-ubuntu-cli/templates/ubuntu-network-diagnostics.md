Assess network connectivity, DNS resolution, and port reachability on the host system.

## Steps

1. Verify DNS resolution: USE `dig +short <hostname>` or `nslookup <hostname>`
2. Check ping latency: USE `ping -c 4 <target>`
3. Check TCP port connectivity: USE `nc -vz <target_ip> <port>`
4. Review routing table: USE `ip route show` or `netstat -rn`
5. Find open listening ports: USE `lsof -i -P -n | grep LISTEN`
6. **Output:** Root cause report specifying if it's a DNS failure, routing issue, or blocked port.
