# Release Checklist

## v0.1.0

1. Validate locally:

   ```sh
   ./scripts/validate.sh
   ./scripts/smoke-release.sh
   ```

2. Commit release prep:

   ```sh
   git add .
   git commit -m "chore: prepare v0.1.0 release"
   ```

3. Push `main`:

   ```sh
   git push origin main
   ```

4. Wait for GitHub Actions CI to pass.

5. Create tag:

   ```sh
   git tag -a v0.1.0 -m "BrewMatch 0.1.0"
   git push origin v0.1.0
   ```

6. Run the manual `Release Build` workflow with version `0.1.0`.

7. Download the workflow artifact.

8. Smoke test the downloaded binary:

   ```sh
   ./brewmatch --version
   ./brewmatch scan
   ./brewmatch brewfile
   ```

9. Create GitHub release notes manually.

10. Verify README install instructions from a clean clone.
