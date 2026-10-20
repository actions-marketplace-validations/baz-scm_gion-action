# Contributing

The actions are composite: each `action.yml` installs gion with `scripts/install.sh`, then runs one script from `scripts/`. Keep logic in the scripts so you can run them locally with a faked runner environment (`RUNNER_TOOL_CACHE`, `GITHUB_PATH`, `GITHUB_OUTPUT` pointing at temp files).

Work with [gion](https://github.com/baz-scm/gion), not git: `gion clone baz-scm/gion-action <dir>`, edit, then `gion commit -m "..." --to main`. [test.yml](.github/workflows/test.yml) runs every action on Linux x64, Linux ARM64 and macOS on each push.

## After a gion release: bump the default

Each release of this action pins the gion version it installs by default. After gion publishes a release, make it the default with your own credentials:

```sh
gh workflow run bump-gion.yml -R baz-scm/gion-action
gh run watch -R baz-scm/gion-action "$(gh run list -R baz-scm/gion-action -w bump-gion.yml -L 1 --json databaseId -q '.[0].databaseId')"
```

With no input it picks gion's latest release. Pass `-f version=vX.Y.Z` to choose one. The workflow:

1. checks the release has binaries by installing it;
2. does nothing if the default is already that version or newer;
3. updates `default:` under `version` in all three `action.yml` files and pushes to main;
4. runs `test.yml` on that commit;
5. tags the next `v1.x.y`, moves `v1` to it and creates the GitHub release.

If the tests fail, main has the new default but nothing is tagged, so `@v1` users are unaffected. Fix forward and rerun.

## Releasing a change to the actions

The same tags carry changes to the actions themselves. Once `test.yml` is green on main:

```sh
gion tag baz-scm/gion-action vX.Y.Z <commit> -m "vX.Y.Z"
gh api -X PATCH repos/baz-scm/gion-action/git/refs/tags/v1 -f sha=<commit> -F force=true
gh release create vX.Y.Z -R baz-scm/gion-action --generate-notes
```

`gion tag` never moves a tag, so `v1` (a lightweight tag) is moved with the API. Never move a `v1.x.y` tag. A breaking change to inputs or outputs needs `v2`.
