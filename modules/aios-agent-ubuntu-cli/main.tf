terraform {
  required_providers {
    sg = { source = "releases.stackgen.com/stackgen/stackgen" }
  }
}

# ============================================================================
# Ubuntu CLI SRE Module
# ============================================================================
# Dedicated OS inspection agent with deep Linux systems expertise.
# Designed for read-only diagnostics: connectivity testing, process
# triage, memory pressure analysis, and log foraging.
#
# Uses a standard MCP container loaded with typical Linux diagnostic tools.

# ============================================================================
# Agent
# ============================================================================

resource "sg_agent" "ubuntu_cli_agent" {
  name        = "ubuntu-cli-inspector"
  persona     = file("${path.module}/personas/ubuntu-sre.md")
  model_names = [var.model_names.claude_sonnet, var.model_names.gpt4o]

  integrations = [var.integration_names.ubuntu_cli]
}

# ============================================================================
# Agent Budget
# ============================================================================

resource "sg_agent_budget" "ubuntu_cli_agent" {
  agent_name  = sg_agent.ubuntu_cli_agent.name
  limit_usd   = 10
  period_type = "daily"
}

# ============================================================================
# Policy Attachments
# ============================================================================

resource "sg_agent_policy_attachment" "ubuntu_dangerous_ops" {
  agent_name = sg_agent.ubuntu_cli_agent.name
  policy_id  = var.policy_ids.dangerous_ops
  enabled    = true
}

resource "sg_agent_policy_attachment" "ubuntu_shell_hitl" {
  agent_name = sg_agent.ubuntu_cli_agent.name
  policy_id  = var.policy_ids.container_shell_hitl
  enabled    = true
}

# ============================================================================
# Runbook SOPs — Granular Linux Triage Skills
# ============================================================================

resource "sg_runbook_sop" "ubuntu_network_diagnostics" {
  name        = "ubuntu-network-diagnostics"
  description = <<-EOT
    Assess network connectivity, DNS resolution, and port reachability on the host system.

    Steps:
    1) Verify DNS resolution: USE `dig +short <hostname>` or `nslookup <hostname>`
    2) Check ping latency: USE `ping -c 4 <target>`
    3) Check TCP port connectivity: USE `nc -vz <target_ip> <port>`
    4) Review routing table: USE `ip route show` or `netstat -rn`
    5) Find open listening ports: USE `lsof -i -P -n | grep LISTEN`
    6) Output: Root cause report specifying if it's a DNS failure, routing issue, or blocked port.
  EOT
}

resource "sg_runbook_sop" "ubuntu_process_triage" {
  name        = "ubuntu-process-triage"
  description = <<-EOT
    Identify and analyze high CPU/Memory processes and resource bottlenecks.

    Steps:
    1) Find top CPU consumers: USE `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -n 10`
    2) Find top Memory consumers: USE `ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -n 10`
    3) Check overall system load: USE `top -b -n 1 | head -n 15`
    4) Profile specific process behavior (if stuck): USE `strace -c -p <pid>` (caution: may require permissions)
    5) Identify zombie processes: USE `ps aux | awk '{ print $8 " " $2 }' | grep -w Z`
    6) Output: Recommendations on processes to terminate or scale.
  EOT
}

resource "sg_runbook_sop" "ubuntu_disk_triage" {
  name        = "ubuntu-disk-triage"
  description = <<-EOT
    Diagnose disk space exhaustion, inode limits, and file descriptor leaks.

    Steps:
    1) Check overall disk capacity: USE `df -h`
    2) Check inode usage (if disks show free space but writes fail): USE `df -i`
    3) Find largest directories in var/log: USE `du -sh /var/log/* | sort -rh | head -n 10`
    4) Check for open file descriptor limits: USE `cat /proc/sys/fs/file-nr`
    5) Find processes with most open files: USE `lsof | awk '{print $1}' | sort | uniq -c | sort -rn | head -10`
    6) Risk assessment: Flag partition usage > 85% or inodes > 90%.
  EOT
}

resource "sg_runbook_sop" "ubuntu_log_analysis" {
  name        = "ubuntu-log-analysis"
  description = <<-EOT
    Grep and identify application anomalies from system and application logs.

    Steps:
    1) Check system syslog for recent errors: USE `tail -n 200 /var/log/syslog | grep -i 'error\|panic\|fatal'`
    2) Check dmesg for kernel-level / hardware errors or OOM kills: USE `dmesg -T | grep -i 'killed process\|oom'`
    3) Check specific application service logs: USE `grep -C 2 -i "Exception" <log_file>`
    4) Count frequency of specific HTTP status codes: USE `awk '{print $9}' access.log | sort | uniq -c | sort -rn`
    5) Assessment: Pinpoint the exact timestamp and context of application exceptions.
  EOT
}
