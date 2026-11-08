# Progress

## 2026-11-08 — Ordered build numbers

Changed:
- Added `.github/workflows/ordered-build.yml`: runs on pushes to `main`, one at a time
  (`concurrency: build-${{ github.ref }}`, no cancelling), computes
  `BUILD = 1 + run_number` (next build is 2), and tags the commit `build-$BUILD`.
- Stamps BUILD into CURRENT_PROJECT_VERSION / CFBundleVersion in the CI checkout. The app itself is built in Xcode Cloud (ci_scripts/), so no xcodebuild step was added on GitHub.

Open:
- Branch `ci/ordered-build-numbers` is local only; needs Ethan's OK to push.
- GitHub keeps at most one queued run per group; if several pushes land while one is running,
  the middle ones are superseded, so numbers stay in order but can skip.
