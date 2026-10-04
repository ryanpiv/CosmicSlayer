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

## Project

The CurseForge project is [cosmic-slayer-helper](https://www.curseforge.com/wow/addons/cosmic-slayer-helper), project ID `1725635`. That public page stays a 404 until the first file is approved. The ID is already in `CosmicSlayer.toc`:

```
## X-Curse-Project-ID: 1725635
```

The upload token is stored on this repo as `CF_API_KEY`.

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
