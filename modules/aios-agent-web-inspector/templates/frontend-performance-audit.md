Assess frontend performance characteristics using Chrome DevTools Performance domain and browser metrics.

## Steps

1. Navigate to the target page: USE `navigate_page`
2. Wait for full page load: USE `wait_for` with a key content selector
3. Collect baseline performance metrics: USE `get_performance_metrics` — record JSHeapUsedSize, Documents, Nodes, LayoutCount
4. Emulate slow network conditions: USE `emulate_network` with preset "slow-3g"
5. Reload the page and measure load performance
6. Reset network to normal: USE `emulate_network` with preset "none"
7. Emulate mobile viewport: USE `resize_page` with width=375 height=812 (iPhone dimensions)
8. Take mobile screenshot: USE `take_screenshot`
9. Collect mobile performance metrics: USE `get_performance_metrics`
10. Evaluate Core Web Vitals: USE `evaluate_script` with `JSON.stringify(performance.getEntriesByType('navigation')[0])`
11. If Grafana is available: correlate frontend load time with backend API response times
12. **Output:** Performance report including:
    - Core Web Vitals (LCP, FID/INP, CLS)
    - JS heap usage and DOM node count
    - Mobile vs desktop rendering comparison
    - Network waterfall analysis from `list_network_requests`
    - Backend correlation (if Grafana available)
