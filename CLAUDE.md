# Claude Plugins Project

This is a Claude Code plugin repository. It contains skills, agents, and related assets that extend Claude Code's behavior.

## Scope Rule

When working on anything in this project, **only touch files within this project folder**. Never modify files outside this directory.

## Structure

- `plugins/uzaak/` — user's own plugin (skills, agents, assets, references)
- `plugins/bmad_v1/` — bmad_v1 plugin (skills, agents, assets, references)
- `plugin.sh` — plugin installation/management script

## Working on Skills

Skills live in `plugins/<plugin-name>/skills/` as `.md` files. When asked to create, edit, or improve a skill:

1. Work only on the `.md` files inside the `skills/` directories.
2. Follow the skill format established by existing files in the same directory.
3. Do not create files outside this project folder.
4. Use the `superpowers:writing-skills` skill when creating or editing skill files.
