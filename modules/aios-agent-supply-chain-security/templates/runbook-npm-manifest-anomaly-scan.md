Compare package.json dependencies against actual code imports to detect phantom dependencies.

Steps:
1) Clone repository: git clone --depth 1 https://github.com/<org>/<repo>.git
2) Parse declared deps: cat package.json | jq -r '.dependencies // {} | keys[]'
3) Scan source for imports: grep -rhn "require\|import " src/ lib/ --include="*.js" --include="*.ts"
4) Check config files for package references
5) Check package.json scripts for CLI tool usage
6) Exclude known build-only packages (typescript, eslint, jest, etc.)
7) Compute phantom set: declared - (imported ∪ config-referenced ∪ build-only)
8) Assess risk: recently added + new maintainer = HIGH, old + unused = MEDIUM
9) Output: package name, phantom status, git history, risk level
