---
name: remote-me
description: Use when the user runs /remote-me — proxies prompts to a persistent Claude Code session on a remote machine via SSH. Supports init (create config), reset (clear session), and prompt forwarding.
argument-hint: [init | reset | path/to/remote-me.json] [prompt...]
---

# remote-me

Read the args to determine which command to run:
- First arg is `init` → run the **Init** flow
- First arg is `reset` → run the **Reset** flow
- Anything else → run the **Relay** flow

---

## Init

Collect the following from the user interactively (one question at a time):

1. **name** — a friendly label for this remote (e.g. `myproject`)
2. **host** — SSH target in `user@host` format (e.g. `deploy@192.168.1.10`)
3. **project_dir** — absolute path to the project directory on the remote machine (e.g. `/home/deploy/myproject`)

Then write `remote-me.json` to the **current working directory**:

```json
{
  "name": "<name>",
  "host": "<host>",
  "project_dir": "<project_dir>",
  "session_id": null
}
```

Then verify SSH connectivity:

```bash
ssh <host> "echo ok"
```

- If output is `ok`: print `SSH connection to <host> verified. Config saved to ./remote-me.json`
- If it fails: print the raw SSH error and warn the user to check their SSH access before using `/remote-me`

The config file is written before the SSH check and must not be removed or overwritten if the check fails.

---

## Reset

Determine config path:
- If first arg is `reset` and a second arg exists and ends in `.json` → use that path
- Otherwise → use `remote-me.json` in the current working directory

Read the file. Set `session_id` to `null`. Write the file back. Print: `Session reset. Next prompt will start a fresh Claude session on the remote.`

---

## Relay

### 1. Determine config path and prompt

Parse args:
- If first arg ends in `.json` → that is the config path; the remaining args are the prompt
- Otherwise → config path is `remote-me.json` in the current working directory; all args are the prompt

If config file does not exist: print the following and stop:

```
Config file not found: <path>
Run `/remote-me init` to create one, or pass an explicit path: `/remote-me path/to/remote-me.json your prompt`
```

### 2. Read config

Parse the JSON. Extract: `host`, `project_dir`, `session_id`.

### 3. Build and run the SSH command

If `session_id` is null (first run):

```bash
ssh <host> "cd <project_dir> && claude -p \"<prompt>\" --output-format json"
```

If `session_id` has a value:

```bash
ssh <host> "cd <project_dir> && claude -p \"<prompt>\" -r <session_id> --output-format json"
```

Capture stdout. If the SSH command itself fails (non-zero exit code): print the raw SSH error and stop — do not modify the config file.

Before embedding `<prompt>` in the command, escape any double-quote characters in the prompt text (replace `"` with `\"`). Prompts containing unescaped `"`, `$`, or backticks will break the SSH command.

### 4. Parse the response

Parse captured stdout as JSON.

- If parsing fails or `type` is not `"result"` (the JSON always contains a `type` field; successful responses have `type: "result"`): print the raw stdout as-is and stop. Do not modify the config.
- If `is_error` is true: do not update session_id. Ask the user:

```
Remote Claude returned an error: <result field content>
This may mean the session no longer exists on the remote.
Would you like me to reset the session and retry your prompt fresh? (yes/no)
```

If the user says yes: set `session_id` to null in the config file, then re-run the SSH command from Step 3 without `-r` (first-run form), and continue from Step 4 as normal. If this retry also returns `is_error: true`, do not offer to reset again — print the error and stop.

### 5. Print and persist

Print the value of `result` to the screen.

Read the current config file, replace only the `session_id` value with the one from the response, and write the full JSON back. Do not overwrite other fields.
