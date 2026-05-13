Identify AWS Lambda functions that have not been invoked recently.

## Steps

1. List every Lambda in the connected account/region (`aws lambda list-functions`).
2. For each function, query CloudWatch `AWS/Lambda` `Invocations` over the
   last **{{inactivity_days}}** days (default 30); flag functions where
   `Sum == 0`.
3. Cross-check `Last-Modified` on the function configuration; treat
   functions never invoked AND not modified in the same window as the
   highest-priority cleanup candidates.
4. Capture function ARN, runtime, code-size, package-type, owner tag, and
   estimated monthly cost retained (storage + provisioned concurrency, if any).
5. Skip functions tagged `aios:cleanup:exempt=true` or `do-not-delete=true`
   and report the skipped count.
6. Output a structured table: `function_arn | runtime | last_invocation |
   last_modified | owner | est_monthly_usd | recommendation`.
