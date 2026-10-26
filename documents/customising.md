# Customising

Edit `recipes/recipe.yml` — it is validated on every pull request, so mistakes
are caught before a build starts.

- **Packages**: add to the `dnf` module's `install.packages` list. Anything in
  Fedora's repositories works without extra configuration. Third-party repos go
  under `repos.files` and `repos.keys`.
- **Files and scripts**: see [`files/README.md`](../files/README.md).
- **Base image**: `image-version` accepts `latest` or a Fedora major version
  (e.g. `44`). Pinning a major version freezes your base, but note that the
  pinned tag is removed from the base image when that release ages out, so
  a stale pin will eventually break the build.

Where the packages in those lists come from is covered in
[image-composition.md](image-composition.md).

## See also

- [image-composition.md](image-composition.md) — what goes into the image and why
- [building.md](building.md) — how the image gets built and published
