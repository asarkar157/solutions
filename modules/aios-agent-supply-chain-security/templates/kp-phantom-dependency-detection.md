Techniques for detecting unused/phantom dependencies in Node.js projects.

WHAT ARE PHANTOM DEPENDENCIES:
Packages listed in package.json that are never actually imported or required
anywhere in source code. Attackers exploit them because they execute postinstall
scripts during npm install without ever being invoked at runtime.

DETECTION METHODS:
1. depcheck: npx depcheck --json
2. Manual AST: grep -rn "require\|import " src/ lib/ --include="*.js" --include="*.ts"
3. Import graph: npx madge --json src/index.js
4. Lockfile diff: git diff HEAD~1 -- package-lock.json

EXCLUDE FROM PHANTOM DETECTION (build-only packages):
typescript, webpack, eslint, prettier, jest, @types/*, babel-*, nodemon, husky

FALSE POSITIVE MITIGATION:
- Check config files (webpack.config.js, .eslintrc, jest.config.js)
- Check package.json scripts for CLI tool usage
- Check if package provides type definitions (@types/*)
