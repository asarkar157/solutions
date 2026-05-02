Multi-cloud idle resource detection.

## Steps

1. **AWS:** Find unattached EBS, stopped EC2, unused EIPs
2. **Azure:** Find stopped VMs, unattached disks
3. **GCP:** Find stopped instances, unattached persistent disks
4. Calculate total monthly waste
