# Testing the mstack plugin

Two loops: a **local** loop (no GitHub, fastest) and a **remote** loop (real
install path other repos will use). Always run the validator first.

```bash
scripts/validate.sh        # must print ALL CHECKS PASSED
```

## A. Local loop (recommended while iterating)

Claude Code can add a marketplace from an absolute path on disk — no commit, no
push. Edit files here, re-add, reinstall, done.

In a **target app** (NOT this template — see the collision note below), run:

```text
/plugin marketplace add /absolute/path/to/mstack
/plugin install mstack@mstack
```

Verify it loaded:

```text
/plugin            # mstack shows as installed, 10 skills
/help              # skills appear as mstack:mstack-plan, mstack:mstack-review, ...
```

Smoke-test a read-only skill (no code edits, safe anywhere):

```text
/mstack:mstack-plan      (or just /mstack-plan if there's no name clash)
```

It should read context and start the consultation. If it can run its read phase
and write to `.mstack/plans/`, the wiring (skills + `${CLAUDE_PLUGIN_ROOT}`
shared scripts) is good.

After editing the plugin, refresh:

```text
/plugin marketplace update mstack
/plugin install mstack@mstack     # reinstall picks up changes
```

## B. Remote loop (the path other repos use)

```bash
# from a clean copy of this marketplace
git init && git add -A && git commit -m "mstack plugin v0.1.0"
gh repo create vbhadala/mstack --private --source=. --push
```

Then in any repo:

```text
/plugin marketplace add vbhadala/mstack
/plugin install mstack@mstack
```

## What to actually check

- [ ] `/plugin` lists mstack with all 10 skills.
- [ ] A skill **runs** — `mstack-plan` reads context and writes `.mstack/plans/`.
- [ ] A skill that calls a shared script works — `mstack-review` invokes
      `${CLAUDE_PLUGIN_ROOT}/shared/bin/find-latest-plan.sh` without "file not
      found". This proves plugin-root resolution.
- [ ] `append-learning.sh` appends to the **repo's** `.mstack/learnings.jsonl`,
      not the plugin dir. (Requires `jq` on PATH.)
- [ ] In a non-template app: confirm whether hardcoded paths (`packages/config`,
      `pnpm ...`) in skill prose mislead. This is the known decoupling gap —
      drop a `.mstack/config.json` and confirm the skill respects it once the
      prose-decoupling pass lands.

## Collision note

Do **not** test in this template repo: it still vendors `.claude/skills/mstack-*`,
so you'd have two copies of every skill. Test in a different app, or first
remove the vendored copies here. Once the plugin is proven, deleting the
vendored `.claude/skills/mstack-*` is the cutover.
