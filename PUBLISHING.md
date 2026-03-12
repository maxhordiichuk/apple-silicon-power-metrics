# Publishing to npm

## First-time setup

Log in to npm

```bash
npm login
```

This opens a browser window to authenticate. Verify you're logged in:

```bash
npm whoami
```

---

## Every release

### 1. Run tests

```bash
npm test
```

### 2. Bump the version

Follow [semantic versioning](https://semver.org):

```bash
npm version patch   # bug fixes:        1.0.0 → 1.0.1
npm version minor   # new features:     1.0.0 → 1.1.0
npm version major   # breaking changes: 1.0.0 → 2.0.0
```

This updates `package.json` and creates a git tag automatically.

### 3. Build the prebuilt binary

```bash
npm run prebuild
```

This compiles the native addon and places the binary at `prebuilds/darwin-arm64/apple-silicon-power-metrics.node`. The binary is included in the published package so users don't need build tools.

### 4. Compile TypeScript

```bash
npm run build:ts
```

This outputs the JS and type declarations to `dist/`.

### 5. Preview the package contents

```bash
npm pack --dry-run
```

Verify the file list includes:
- `dist/` — compiled JS and `.d.ts` files
- `prebuilds/` — prebuilt native binary
- `src/` — C/C++ and TypeScript source files
- `binding.gyp` — build configuration

And does **not** include `node_modules/`, `build/`, or `*.node` files at the root.

### 6. Publish

```bash
npm publish
```

After publishing, verify it appears on npm:

```bash
npm view apple-silicon-power-metrics
```

### 7. Push the version tag to GitHub

```bash
git push --follow-tags
```

---

## What gets published

The `files` field in `package.json` controls what is included:

```json
"files": ["src/", "dist/", "prebuilds/", "binding.gyp"]
```

The `install` script (`node-gyp-build`) runs on the consumer's machine. It finds the matching prebuilt binary in `prebuilds/` and uses it directly, skipping compilation. It only falls back to compiling from source if no matching prebuilt is found.
