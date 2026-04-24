# uzaak — Claude Code Plugin

Local plugin providing custom slash commands under the `uzaak:` namespace.

## Commands

| Command | Description |
|---|---|
| `/uzaak:unittests` | Says hello |
| `/uzaak:dockercomposefix` | Says goodbye |

## Structure

```
ClaudeZak/
├── .claude-plugin/
│   └── plugin.json       # Plugin metadata
├── skills/
│   ├── unittests/
│   │   └── SKILL.md      # /uzaak:unittests command
│   └── dockercomposefix/
│       └── SKILL.md      # /uzaak:dockercomposefix command
└── README.md
```

## Manual Installation

Add the following entry to `~/.claude/plugins/installed_plugins.json` under the `plugins` key:

```json
"uzaak@local": [
  {
    "scope": "user",
    "installPath": "/home/tiagofurlaneto/Developer/ClaudeZak",
    "version": "1.0.0",
    "installedAt": "2026-04-01T00:00:00.000Z",
    "lastUpdated": "2026-04-01T00:00:00.000Z"
  }
]
```
