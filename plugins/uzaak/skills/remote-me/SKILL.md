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

Then verify SSH connectivity:

```bash
ssh <host> "echo ok"
```

- If it fails: print the raw SSH error and stop — do not write the config file.

If SSH succeeds, discover the claude binary path on the remote:

```bash
ssh <host> "bash -li -c 'which claude' 2>/dev/null || find /usr/local/bin /home -name claude 2>/dev/null | head -1"
```

- If a path is returned: use it as `host_claude_path`
- If nothing is returned: print `Could not locate the claude binary on <host>. Install Claude Code there first.` and stop — do not write the config file.

Generate a UUID for this config:

```bash
python3 -c "import uuid; print(uuid.uuid4())"
```

Then write `remote-me.json` to the **current working directory**:

```json
{
  "name": "<name>",
  "host": "<host>",
  "project_dir": "<project_dir>",
  "host_claude_path": "<discovered_path>",
  "session_id": null,
  "uuid": "<generated-uuid>",
  "detached": true,
  "dangerously_skip_permissions": true
}
```

- `uuid` — ties this config to its output file on the remote (`/tmp/remote-me-out-<uuid>.json`). Never changes after init.
- `detached` — `true` runs Claude detached from the SSH session (robust against drops); `false` runs blocking. Default: `true`.
- `dangerously_skip_permissions` — `true` passes `--dangerously-skip-permissions` to Claude, which is required for file-writing skills in non-interactive mode. Default: `true`.

Both flags can be edited manually in the JSON at any time.

Print: `SSH connection to <host> verified. claude found at <host_claude_path>. Config saved to ./remote-me.json`

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

Parse the JSON. Extract: `host`, `project_dir`, `host_claude_path`, `session_id`, `uuid`, `detached`, `dangerously_skip_permissions`.

If `host_claude_path` is missing or null: print `Config is missing host_claude_path. Re-run \`/remote-me init\` to regenerate it.` and stop.

If `uuid` is missing or null: print `Config is missing uuid. Re-run \`/remote-me init\` to regenerate it.` and stop.

Treat missing `detached` as `true`. Treat missing `dangerously_skip_permissions` as `true`.

### 3. Build the Claude command

Escape the prompt: replace `"` with `\"`, `$` with `\$`, and backticks with `\``.

Assemble the remote command:

```
<host_claude_path> -p "<escaped_prompt>" [--resume <session_id>] --output-format json [--dangerously-skip-permissions]
```

- Include `-r <session_id>` only if `session_id` is non-null.
- Include `--dangerously-skip-permissions` only if `dangerously_skip_permissions` is `true`.

### 4a. Execute — detached mode (`detached: true`)

Launch Claude on the remote, detached from the SSH session, writing output to a stable file keyed by UUID:

```bash
ssh <host> "cd <project_dir> && nohup bash -c '<claude_command>' > /tmp/remote-me-out-<uuid>.json 2>/tmp/remote-me-err-<uuid>.txt & echo \$!"
```

Capture the PID printed to stdout.

Poll every 30 seconds until the process exits:

```bash
until ssh <host> "! kill -0 <pid> 2>/dev/null"; do sleep 30; done
```

If the poll SSH connection drops mid-wait, simply re-run `/remote-me` with the same prompt — the UUID is stable, and if the remote process already finished, Step 4b will find the output file immediately. If it is still running, a new PID will be captured and polling resumes.

Once the process exits, fetch the output:

```bash
ssh <host> "cat /tmp/remote-me-out-<uuid>.json"
```

Leave the output file on the remote as a debug artefact. Proceed to Step 5.

### 4b. Execute — blocking mode (`detached: false`)

```bash
ssh <host> "cd <project_dir> && <claude_command>"
```

Capture stdout directly. If the SSH command itself fails (non-zero exit code): print the raw SSH error and stop — do not modify the config file. Proceed to Step 5.

### 5. Parse the response

Parse captured stdout as JSON.

- If parsing fails or `type` is not `"result"`: print the raw stdout as-is and stop. Do not modify the config.
- If `is_error` is true: do not update `session_id`. Ask the user:

```
Remote Claude returned an error: <result field content>
This may mean the session no longer exists on the remote.
Would you like me to reset the session and retry your prompt fresh? (yes/no)
```

If the user says yes: set `session_id` to null in the config file, then re-run the SSH command from Step 4 without `-r` (first-run form), and continue from Step 5 as normal. If this retry also returns `is_error: true`, do not offer to reset again — print the error and stop.

### 6. Print and persist

Print the value of `result` to the screen.

Read the current config file, replace only the `session_id` value with the one from the response, and write the full JSON back. Do not overwrite other fields.
