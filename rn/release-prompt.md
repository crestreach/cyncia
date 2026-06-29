
# Make a release

Switch to main, and make a release on GitHub. Make sure to ask me which version should be released (patch, minor, major), generate release notes in the releas (also in the rn directory). Update any files if needed. Commit these changes to master before creating a tag.
Write the release notes in rn/<version>.md using repo-relative ../ links (for in-repo viewing) and commit only that file. Generate the release-page body with rn/generate-release-notes.sh <version> — it writes a gitignored rn/release/<version>-release.md whose links are root-relative so GitHub resolves them against the repo at the tag — then run gh release create <version> --title "Cyncia <version>" --notes-file rn/release/<version>-release.md --verify-tag --latest (or gh release edit …). Delete rn/release/ afterward; never commit it. The tag should sit on the latest commit.

# Update the website

Have a look at the Cyncia project https://github.com/crestreach/cyncia and its README.md file. Then please update this page (which was generated based on the README.md) to reflect the information in the lastest Cyncia version in the Github repository.

