# Publishing to CurseForge

The TOC stays at `1.0.0` until the first publish. Releases are driven by git tags.

```bash
git tag v1.0.0
git push && git push --tags
```

GitHub Actions ([BigWigs packager](https://github.com/BigWigsMods/packager),
see `.github/workflows/release.yml`) packages the addon per `.pkgmeta`,
uploads it to CurseForge, and attaches the zip to a GitHub release. Until the
project id and API token below exist, a tag push still creates the GitHub
release and skips the CurseForge upload.

## Create the project first

CurseForge will not accept an upload until the project exists.

1. Open [authors.curseforge.com](https://authors.curseforge.com) → Projects →
   Create a Project → World of Warcraft → Addon.
2. Name it Cosmic Slayer. Summary can match the TOC notes. Category:
   Achievements.
3. Copy the project ID from the About Project box on the project overview.
4. Add it to `CosmicSlayer.toc`:

   ```
   ## X-Curse-Project-ID: 123456
   ```

5. Generate an API token at authors.curseforge.com → Account → API Tokens.
   The same token used by Arcane Salvo Tracker works here. Store it on this
   repo:

   ```bash
   gh secret set CF_API_KEY --repo ryanpiv/CosmicSlayer
   ```

## Releasing 1.0.0

1. Confirm `## Version: 1.0.0` in `CosmicSlayer.toc`.
2. Update `CHANGELOG.md`. Its full contents are the CurseForge changelog.
3. Commit, tag `v1.0.0`, and push the tag.

New uploads sit in CurseForge's approval queue and go live once approved.

## Notes

- The zip ships `CosmicSlayer.toc` and `CosmicSlayer.lua` only. Tests, docs,
  and workflows are excluded in `.pkgmeta`.
- A tag containing `alpha` or `beta` uploads to that channel instead of release.
- The game version comes from `## Interface:` (`120100` → 12.1.0). If CurseForge
  has not registered that patch yet, the packager error lists nearby versions.
