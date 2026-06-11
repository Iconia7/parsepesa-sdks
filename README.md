# ParsePesa Official SDKs

This directory contains the source code for the official ParsePesa SDKs. 

## Publishing to Registries

To make the installation commands (e.g., `npm install parsepesa`) work, you must publish these packages to their respective registries.

### 1. Node.js (npm)
1. Go to `sdks/nodejs/`
2. Run `npm login`
3. Run `npm publish`

### 2. Python (PyPI)
1. Go to `sdks/python/`
2. Install build tools: `py -m pip install build twine`
3. Build the package: `py -m build`
4. Upload: `py -m twine upload dist/*`

### 3. Flutter (pub.dev)
1. Go to `sdks/flutter/`
2. Run `dart pub publish`

---
© 2026 Nexora Creative Solutions
