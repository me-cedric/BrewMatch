# Release Checklist

## Versioned Release

1. Validate locally:

   ```sh
   ./scripts/validate.sh
   ./scripts/smoke-release.sh
   swift build -c release
   .build/release/brewmatch --version
   ```

2. Commit release prep:

   ```sh
   git add .
   git commit -m "chore: release vX.Y.Z"
   ```

3. Push `main`:

   ```sh
   git push origin main
   ```

4. Wait for GitHub Actions CI to pass.

5. Create tag:

   ```sh
   git tag -a vX.Y.Z -m "BrewMatch X.Y.Z"
   git push origin vX.Y.Z
   ```

6. Run the manual `Release Build` workflow with version `X.Y.Z`.

7. Download the workflow artifact.

8. Smoke test the downloaded binary:

   ```sh
   ./brewmatch --version
   ./brewmatch scan
   ./brewmatch brewfile
   ```

9. Create GitHub release notes manually.

10. Verify README install instructions from a clean clone.
