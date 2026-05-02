Respond to Kubernetes MemoryPressure node condition.

## Steps

1. Identify affected node,
2. List top memory consumers,
3. Evict non-critical pods,
4. Cordon node,
5. Capture heap dump if leak suspected,
6. Terminate instance for ASG replacement if hardware fault,
7. Uncordon after new node Ready.
