Diagnose GKE cluster issues.

## Steps

1. `gcloud container clusters list`
2. `kubectl get nodes`
3. `kubectl describe node` for NotReady nodes
4. Check pod CrashLoopBackOff
5. Review container logs
