# Staying current with the upstream template

This repository started as a fork of
[blue-build/template](https://github.com/blue-build/template/). The upstream
template changes rarely, and it explicitly states that syncing is not required
to keep the repository functional. The parts that do change are:

- the `blue-build/github-action` version — tracked automatically by
  [Renovate](../.github/renovate.json), which understands the SHA-pinned
  `uses:` reference in [`.github/workflows/build.yml`](../.github/workflows/build.yml)
- `recipes/recipe.yml` and `README.md` defaults — applied by hand
- `.gitignore` — applied by hand

To see what upstream has changed:

```bash
git remote add template https://github.com/blue-build/template.git
git fetch template
git diff main template/main
```

## See also

- [building.md](building.md) — how the image gets built and published
- [customising.md](customising.md) — changing what goes into the image
