# mstack

An internal [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins)
marketplace. One git repo, one `/plugin marketplace add`, and every
repo — new template forks and existing apps alike — can install and **update**
the shared agent workflow without re-forking the template.

## Plugins

| Plugin | Description |
|---|---|
| [`mstack`](./plugins/mstack) | init → plan → review → code → ship workflow + QA, debug, mockup, design-system, ux-audit, research, status, expo release |

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
plugins/<name>/                    # one dir per plugin
  .claude-plugin/plugin.json       #   manifest (name, version, author)
  skills/                          #   /slash-command skills
  shared/                          #   helper scripts + templates (read-only)
```

## Releasing

1. Edit skills/assets under `plugins/<name>/`.
2. Bump `version` in **both** `plugins/<name>/.claude-plugin/plugin.json` and
   the matching entry in `.claude-plugin/marketplace.json` (keep them in sync).
3. Update the plugin's `CHANGELOG.md` — flag any `### Contract` changes.
4. Commit and push. Consuming repos pick it up on `/plugin update`.

## Local development

Point Claude Code at a working copy instead of the remote:

```bash
/plugin marketplace add /absolute/path/to/mstack
/plugin install mstack@mstack
```
