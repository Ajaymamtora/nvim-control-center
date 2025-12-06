# Tasks Feature

The **Tasks** feature provides a comprehensive UI for managing [overseer.nvim](https://github.com/stevearc/overseer.nvim) tasks. You can define tasks, configure auto-run behavior, and run them directly from the control center.

## Enabling the Feature

```lua
require("nvim-control-center").setup({
  features = {
    tasks = true,
  },
})
```

## How It Works

### Task Storage

Tasks are stored in `.neoconf.json` under the `tasks` key as an array:

```json
{
  "tasks": [
    {
      "name": "npm start",
      "start": "auto"
    },
    {
      "name": "build",
      "cmd": "npm",
      "args": ["run", "build"],
      "cwd": "./",
      "start": "once"
    }
  ]
}
```

### Task Types

The feature supports two types of tasks:

#### 1. Template Tasks

Template tasks reference an existing overseer template/generator by name. They are identified by:
- Having `type: "template"` explicitly set, OR
- Having no `cmd` field defined

```json
{
  "name": "npm serve",
  "start": "auto"
}
```

When run, template tasks use `overseer.run_task({ name = "npm serve" })` to find and execute the matching template.

#### 2. Inline Tasks

Inline tasks define a complete task with a command. They are identified by having a `cmd` field:

```json
{
  "name": "build",
  "cmd": "make",
  "args": ["all"],
  "cwd": "./src",
  "start": "once"
}
```

When run, inline tasks use `overseer.new_task()` with the full definition.

### Start Modes

Each task has a `start` mode that controls auto-run behavior:

| Mode | Description |
|------|-------------|
| `auto` | Run automatically every time (on project load) |
| `once` | Run only once per session (tracked in history) |
| `disabled` | Never run automatically |

**Note**: Auto-run behavior must be integrated with your session management (see Integration section below).

## UI Features

### Task List

Each task displays:
- **Task name** with a start mode selector (auto/once/disabled)
- **▶ Run** - Run the task immediately
- **✎ Edit** - Expand inline editing form
- **✕ Delete** - Remove the task

### Expandable Edit Form

Clicking "Edit" expands an inline form with editable fields:

```
▼ npm start                              [auto ▼]
  ► Run   ▲ Collapse   ✕ Delete
  ─── Edit Fields ───
    󰏫 Name: npm start
    󰊕 Type: template
     Command: 
     Working Dir: 
     Arguments: 
    󰑓 Auto Restart: ✗
    ▶ 󰒓 Env Variables (2)
    ↩ Revert Changes
    ✓ Done Editing
  ─────────────────
```

Expanding "Env Variables" shows individual entries:

```
    ▼ 󰒓 Env Variables (2)
      ─── Environment ───
       NODE_ENV: development
        ✕ Remove NODE_ENV
       PORT: 3000
        ✕ Remove PORT
       + Add Variable
      ───────────────────
```

- **Edit any field** in any order
- **Changes save immediately** when you press Enter on a field
- **Auto Restart** toggle: task will restart automatically when it exits
- **Env Variables**: expandable section with per-variable editing
  - Click the header to expand/collapse
  - Edit values inline by pressing Enter
  - Delete variables with "✕ Remove"
  - Add new variables with "+ Add Variable"
- **Revert Changes** rolls back to the state when you started editing
- **Done Editing** collapses the form

### Smart Type Detection

The "Type" field intelligently detects the task type:
- If no `cmd` is defined → shows "template"
- If `cmd` is defined → shows "inline"
- You can manually override by changing the type

### Adding New Tasks

Click "+ Add New Task" at the bottom to create a new task. You'll be prompted for:
1. Task name
2. The task is created with `start: "disabled"` and auto-expanded for editing

## Integration with overseer.nvim

### Running Tasks

When you click "Run":
1. The control center window closes (to prevent UI conflicts)
2. The task is executed via overseer:
   - **Template tasks**: `overseer.run_task({ name = task.name, autostart = true })`
   - **Inline tasks**: `overseer.new_task(task_def):start()`

### Auto-Running Tasks on Project Load

To enable auto-run functionality, integrate with your session/project management:

```lua
-- In your persisted.nvim or project.nvim callback:
local function start_auto_tasks()
  local neoconf = require("neoconf")
  local tasks = neoconf.get("tasks")
  if not tasks then return end
  
  local overseer = require("overseer")
  
  for _, task in ipairs(tasks) do
    if task.start == "auto" then
      -- Template task
      if not task.cmd or task.cmd == "" then
        overseer.run_task({ name = task.name, autostart = true })
      else
        -- Inline task
        local t = overseer.new_task({
          name = task.name,
          cmd = task.cmd,
          args = task.args,
          cwd = task.cwd,
        })
        t:start()
      end
    elseif task.start == "once" then
      -- Check task history before running
      -- (implement your own history tracking)
    end
  end
end
```

## Task Definition Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Task identifier and display name |
| `start` | string | No | Auto-run mode: "auto", "once", or "disabled" |
| `type` | string | No | "template" or omit for auto-detection |
| `cmd` | string | No | Command to run (makes task "inline") |
| `args` | array | No | Command arguments |
| `cwd` | string | No | Working directory |
| `env` | object | No | Environment variables (KEY=VALUE pairs) |
| `auto_restart` | boolean | No | Automatically restart task when it exits |

## Use Cases

- **Auto-start dev servers** on project open (`start: "auto"`)
- **Run one-time setup** tasks (`start: "once"`)
- **Quick access to common tasks** from a central UI
- **Project-specific tasks** stored in `.neoconf.json`
- **Template task references** without duplicating definitions

## Example Configuration

```json
{
  "tasks": [
    {
      "name": "Dev Server",
      "cmd": "npm",
      "args": ["run", "dev"],
      "start": "auto",
      "auto_restart": true,
      "env": {
        "NODE_ENV": "development",
        "PORT": "3000"
      }
    },
    {
      "name": "Build",
      "cmd": "npm",
      "args": ["run", "build"],
      "start": "disabled"
    },
    {
      "name": "Open git exclude",
      "start": "once"
    }
  ]
}
```

This configuration:
- Auto-starts the dev server on project load
- Makes "Build" available but doesn't auto-run
- Runs "Open git exclude" (a template task) once per session
