Navigate key user flows in the web application and verify visual correctness and functionality.

## Steps

1. Navigate to the application URL: USE `navigate_page` with the target URL
2. Wait for page to fully load: USE `wait_for` with a key selector (e.g. `#app`, `.main-content`)
3. Take a screenshot of the loaded page: USE `take_screenshot` with full_page=false
4. Check for console errors or warnings: USE `list_console_messages`
5. Inspect network requests for failed API calls: USE `list_network_requests` — flag any 4xx/5xx responses
6. Navigate through critical user flows (login, dashboard, key features)
7. Take screenshots at each key state change
8. Evaluate page-specific assertions: USE `evaluate_script` with expressions like `document.querySelectorAll('.error').length`
9. **Output:** Report with screenshots at each step, list of console errors, failed API calls, and pass/fail assessment
