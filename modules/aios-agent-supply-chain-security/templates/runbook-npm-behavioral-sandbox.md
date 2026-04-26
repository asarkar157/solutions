Run npm install in a restricted sandbox and monitor for suspicious behavior.

Steps:
1) Create isolated workspace: mkdir -p /tmp/sandbox-<uuid>
2) Copy package.json and package-lock.json from target repo
3) Run: npm install --ignore-scripts 2>&1
4) Inspect postinstall scripts: find node_modules -name package.json -exec grep -l "postinstall" {} \;
5) Check for binary downloads: grep -rn "curl\|wget\|fetch" node_modules/<pkg>/package.json
6) Check for obfuscated code: find node_modules/<pkg> -name "*.js" -exec grep -l "eval\|Function(" {} \;
7) Monitor DNS/HTTP for non-allowlisted domain access
8) Output: package name, script type, suspicious patterns, domains accessed
