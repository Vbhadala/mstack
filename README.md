# mstack

An internal [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins)
marketplace. One git repo, one `/plugin marketplace add`, and every
repo — new template forks and existing apps alike — can install and **update**
the shared agent workflow without re-forking the template.

## Plugins

| Plugin | Description |
|---|---|
| [`mstack`](./plugins/mstack) | init → plan → review → code → ship workflow + QA, fix, debug, mockup, design-system, ux-audit, research, status, expo release |

(Room to grow — add a new plugin under `plugins/` and a new entry in
`.claude-plugin/marketplace.json`.)

## Use it in a repo

```bash
/plugin marketplace add vbhadala/mstack
/plugin install mstack@mstack
```

To pin or upgrade later: `/plugin update mstack@mstack`.

## Layout

```
.claude-plugin/marketplace.json   # lists installable plugins
.github/workflows/validate.yml    # CI: shellcheck + validate + script tests
scripts/                           # validate.sh · test.sh (fixtures) · release.sh
plugins/<name>/                    # one dir per plugin
  .claude-plugin/plugin.json       #   manifest (name, version, author)
  skills/                          #   /slash-command skills
  shared/bin/                      #   helper scripts (read-only)
  shared/templates/                #   plan/review/design/prd/roadmap templates
  shared/references/               #   shared reference docs (frontend-craft)
```

## Releasing

1. Edit skills/assets under `plugins/<name>/` on a feature branch.
2. Add a `## [X.Y.Z]` section to the plugin's `CHANGELOG.md` — flag any
   contract changes under a `### Contract` heading.
3. Run `scripts/release.sh X.Y.Z` — it syncs the version into both manifests,
   then runs `scripts/validate.sh` and `scripts/test.sh`.
4. Commit, push, open a PR — CI re-runs the same checks. Merge with a merge
   commit (per-task commits are the review surface). Consuming repos pick the
   release up on `/plugin update`.

`scripts/validate.sh && scripts/test.sh` is the local gate for any change,
release or not.

## Local development

Point Claude Code at a working copy instead of the remote:

```bash
/plugin marketplace add /absolute/path/to/mstack
/plugin install mstack@mstack
```
