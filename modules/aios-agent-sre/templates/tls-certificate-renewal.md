Emergency TLS certificate renewal for ALB and Kubernetes ingress.

## Steps

1. Check certificate expiry with `aws acm describe-certificate`,
2. Trigger re-validation,
3. Verify new cert serial via `openssl s_client`,
4. Validate no mixed-content warnings,
5. Update monitoring alert threshold.
