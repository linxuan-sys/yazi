<h1 align="center">🌀 whoosh.yazi</h1>
<p align="center">
  <b>A lightning-fast, keyboard-first bookmark manager for <a href="https://github.com/sxyazi/yazi">Yazi</a></b><br>
  <i>Save, search, and jump to your favorite paths in a blink</i>
</p>

---

> [!TIP]
> **Russian version:** [README-RU.md](README-RU.md)

> [!NOTE]
> [Yazi](https://github.com/sxyazi/yazi) plugin for bookmark management, supporting the following features:
>
> - **Persistent bookmarks** - No bookmarks are lost after you close yazi
> - **Temporary bookmarks** - Session-only bookmarks that don't persist between restarts
> - **Quick navigation** - Jump, delete, and rename bookmarks by keymap
> - **Fuzzy search** - Support fuzzy search through [fzf](https://github.com/junegunn/fzf)
> - **Multiple bookmark deletion** - Select multiple bookmarks with TAB in fzf
> - **Configuration bookmarks** - Pre-configure bookmarks using Lua language
> - **Smart path truncation** - Configurable path shortening for better readability
> - **Directory history** - Navigate back to previous directory with Backspace
> - **Tab history navigation** - Browse and jump to recently visited directories with Tab key
> - **Quick bookmark creation** - Create temporary bookmarks directly from navigation menu
> - **Configurable menu shortcuts** - Override the default Tab/Backspace/Enter/Space bindings from `init.lua`

<div style="text-align: center;">
  <img src="image/plugin.png" alt="Plugin preview" width="1100px">
</div>

## Installation

> [!IMPORTANT]
> Requires Yazi v26.1.4+

```sh
# Manual installation

# Linux/macOS
git clone https://gitlab.com/WhoSowSee/whoosh.yazi.git ~/.config/yazi/plugins/whoosh.yazi

# Windows
git clone https://gitlab.com/WhoSowSee/whoosh.yazi.git $env:APPDATA\yazi\config\plugins\whoosh.yazi
```

## Usage

Add this to your `init.lua`

```lua
-- You can configure your bookmarks using simplified syntax
local bookmarks = {
  { tag = "Desktop", path = "~/Desktop", key = "d" },
  { tag = "Documents", path = "~/Documents", key = "D" },
  { tag = "Downloads", path = "~/Downloads", key = "o" },
}

-- You can also configure bookmarks with key arrays
local bookmarks = {
  { tag = "Desktop", path = "~/Desktop", key = { "d", "D" } },
  { tag = "Documents", path = "~/Documents", key = { "d", "d" } },
  { tag = "Downloads", path = "~/Downloads", key = "o" },
}

-- Windows-specific bookmarks
if ya.target_family() == "windows" then
  local home_path = os.getenv("USERPROFILE")
  table.insert(bookmarks, {
    tag = "Scoop Local",
    path = os.getenv("SCOOP") or (home_path .. "\\scoop"),
    key = "p"
  })
  table.insert(bookmarks, {
    tag = "Scoop Global",
    path = os.getenv("SCOOP_GLOBAL") or "C:\\ProgramData\\scoop",
    key = "P"
  })
end

require("whoosh"):setup {
  -- Configuration bookmarks (cannot be deleted through plugin)
  bookmarks = bookmarks,

  -- Notification settings
  jump_notify = false,

  -- Key generation for auto-assigning bookmark keys
  keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",

  -- Configure the built-in menu action hotkeys
  -- false - hide menu item
  special_keys = {
    create_temp = "<Enter>",         -- Create a temporary bookmark from the menu
    fuzzy_search = "<Space>",        -- Launch fuzzy search (fzf)
    history = "<Tab>",               -- Open directory history
    previous_dir = "<Backspace>",    -- Jump back to the previous directory
  },

  -- File path for storing user bookmarks
  bookmarks_path = (ya.target_family() == "windows" and os.getenv("APPDATA") .. "\\yazi\\config\\plugins\\whoosh.yazi\\bookmarks") or
         (os.getenv("HOME") .. "/.config/yazi/plugins/whoosh.yazi/bookmarks"),

  -- Replace home directory with "~"
  home_alias_enabled = true,                            -- Toggle home aliasing in displays

  -- Path truncation in navigation menu
  path_truncate_enabled = false,                        -- Enable/disable path truncation
  path_max_depth = 3,                                   -- Maximum path depth before truncation

  -- Path truncation in fuzzy search (fzf)
  fzf_path_truncate_enabled = false,                    -- Enable/disable path truncation in fzf
  fzf_path_max_depth = 5,                               -- Maximum path depth before truncation in fzf

  -- Long folder name truncation
  path_truncate_long_names_enabled = false,             -- Enable in navigation menu
  fzf_path_truncate_long_names_enabled = false,         -- Enable in fzf
  path_max_folder_name_length = 20,                     -- Max length in navigation menu
  fzf_path_max_folder_name_length = 20,                 -- Max length in fzf

  -- History directory settings
  history_size = 10,                                    -- Number of directories in history (default 10)
  history_fzf_path_truncate_enabled = false,            -- Enable/disable path truncation by depth for history
  history_fzf_path_max_depth = 5,                       -- Maximum path depth before truncation for history (default 5)
  history_fzf_path_truncate_long_names_enabled = false, -- Enable/disable long folder name truncation for history
  history_fzf_path_max_folder_name_length = 30,         -- Maximum length for folder names in history (default 30)
}
```

Add this to your `keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = "["
run = "plugin whoosh jump_by_key"
desc = "Jump bookmark by key"

# Direct fuzzy search access
[[mgr.prepend_keymap]]
on = "}"
run = "plugin whoosh jump_by_fzf"
desc = "Direct fuzzy search for bookmarks"

# Basic bookmark operations
[[mgr.prepend_keymap]]
on = [ "]", "a" ]
run = "plugin whoosh save"
desc = "Add bookmark (hovered file/directory)"

[[mgr.prepend_keymap]]
on = [ "]", "A" ]
run = "plugin whoosh save_cwd"
desc = "Add bookmark (current directory)"

# Temporary bookmarks
[[mgr.prepend_keymap]]
on = [ "]", "t" ]
run = "plugin whoosh save_temp"
desc = "Add temporary bookmark (hovered file/directory)"

[[mgr.prepend_keymap]]
on = [ "]", "T" ]
run = "plugin whoosh save_cwd_temp"
desc = "Add temporary bookmark (current directory)"

# Jump to bookmarks
[[mgr.prepend_keymap]]
on = "<A-k>"
run = "plugin whoosh jump_key_k"
desc = "Jump directly to bookmark with key k"

[[mgr.prepend_keymap]]
on = [ "]", "f" ]
run = "plugin whoosh jump_by_fzf"
desc = "Jump bookmark by fzf"

# Delete bookmarks
[[mgr.prepend_keymap]]
on = [ "]", "d" ]
run = "plugin whoosh delete_by_key"
desc = "Delete bookmark by key"

[[mgr.prepend_keymap]]
on = [ "]", "D" ]
run = "plugin whoosh delete_by_fzf"
desc = "Delete bookmarks by fzf (use TAB to select multiple)"

[[mgr.prepend_keymap]]
on = [ "]", "C" ]
run = "plugin whoosh delete_all"
desc = "Delete all user bookmarks"

# Rename bookmarks
[[mgr.prepend_keymap]]
on = [ "]", "r" ]
run = "plugin whoosh rename_by_key"
desc = "Rename bookmark by key"

[[mgr.prepend_keymap]]
on = [ "]", "R" ]
run = "plugin whoosh rename_by_fzf"
desc = "Rename bookmark by fzf"
```

## Features

### Temporary Bookmarks

Session-only bookmarks that don't persist between Yazi restarts:

- Create using `save_temp` or `save_cwd_temp` commands
- Identified with [TEMP] prefix in navigation menu and fzf
- Automatically cleared when Yazi restarts
- Can be deleted individually or all at once with `delete_all_temp`

### Directory History

<div style="text-align: center;">
  <img src="image/history.png" alt="History preview" width="1100px">
</div>

The plugin supports a smart directory history system:

- **Independent history per tab** - Each tab maintains its own history
- **Automatic tracking** - History updates when navigating between directories
- **Current directory filtering** - Current directory is excluded from history display
- **Configurable size** - Number of stored directories is configurable (default 10)
- **Separate truncation settings** - Independent path display settings for history

**System behavior:**

- History is empty on first yazi startup
- Previous directories are added to history only when navigating to a new directory
- New items are added to the beginning of the list (sorted from newest to oldest)
- When limit is exceeded, oldest items are removed
- Duplicates are automatically removed and moved to the top

### Navigation Menu Features

When using `jump_by_key`, you get access to a smart navigation menu with:

- **Create temporary bookmark** - Press `<Enter>` to quickly bookmark current directory
- **Fuzzy search** - Press `<Space>` to open fzf search
- **Directory history** - Press `<Tab>` to browse history via fzf (only if history exists)
- **Previous directory** - Press `<Backspace>` to return to the previous directory (if available)
- **All bookmarks** - Both permanent and temporary bookmarks with clear visual distinction

### Directory History Navigation

The plugin provides two ways to navigate history:

1. **Through navigation menu** - When using `jump_by_key`, press `<Tab>` to access history
2. **Direct access** - Trigger the configured history special key (default `<Tab>`) for direct fzf access to history

#### Neovim `<Tab>` keymap (yazi.nvim)

When this plugin runs inside [mikavilpas/yazi.nvim](https://github.com/mikavilpas/yazi.nvim), the default `<Tab>` mapping (`cycle_open_buffers`) is handled by Neovim before Yazi sees it. If pressing `<Tab>` returns you to the buffer where Yazi was opened, disable or remap that key in the yazi.nvim configuration so the directory history picker can receive it:

```lua
  opts = {
    keymaps = {
      cycle_open_buffers = false,
    },
      -- OR
    keymaps = {
      cycle_open_buffers = "<S-Tab>",
    },
  },
```

Full config file example:

```lua
return {
  "mikavilpas/yazi.nvim",
  version = "*",
  event = "VeryLazy",
  dependencies = { { "nvim-lua/plenary.nvim", lazy = true } },
  keys = {
    { "<leader>-", mode = { "n", "v" }, "<cmd>Yazi<cr>", desc = "Open Yazi" },
    { "<leader>cw", "<cmd>Yazi cwd<cr>", desc = "Open Yazi at CWD" },
  },
  opts = {
    open_for_directories = false,
    keymaps = {
      cycle_open_buffers = false,
    },
  },

  init = function() vim.g.loaded_netrwPlugin = 1 end,
}
```

If you prefer to keep Neovim's `<Tab>` binding but still want access to the history picker, remap whoosh's shortcut via `special_keys` in the `init.lua` file:

```lua
require("whoosh"):setup {
  special_keys = {
    history = "<H>",
  },
}
```

### Bookmark Types

The plugin supports three types of bookmarks:

1. **Configuration bookmarks** - Defined in `init.lua`, cannot be deleted through the plugin
2. **User bookmarks** - Created during usage, saved to file, can be deleted
3. **Temporary bookmarks** - Session-only, stored in memory, cleared on restart

When paths conflict, user bookmarks override configuration bookmarks in the display

## Configuration Options

The plugin supports the following configuration options in the `setup()` function:

| Option                                 | Type    | Default                 | Description                                                        |
| -------------------------------------- | ------- | ----------------------- | ------------------------------------------------------------------ |
| `bookmarks`                            | table   | `{}`                    | Pre-configured bookmarks (cannot be deleted through plugin)        |
| `jump_notify`                          | boolean | `false`                 | Show notification when jumping to a bookmark                       |
| `keys`                                 | string  | `"0123456789abcdef..."` | Characters used for auto-generating bookmark keys                  |
| `special_keys`                         | table   | `see description`       | Override the built-in menu shortcuts (Enter/Space/Tab/Backspace); set to `false` to hide an item |
| `path`                                 | string  | OS-dependent            | File path where user bookmarks are stored                          |
| `home_alias_enabled`                  | boolean | `true`                  | Replace paths under the user's home directory with `~`              |
| `path_truncate_enabled`                | boolean | `false`                 | Enable/disable path truncation in navigation menu                  |
| `path_max_depth`                       | number  | `3`                     | Maximum path depth before truncation with "…" in navigation menu   |
| `fzf_path_truncate_enabled`            | boolean | `false`                 | Enable/disable path truncation in fuzzy search (fzf)               |
| `fzf_path_max_depth`                   | number  | `5`                     | Maximum path depth before truncation with "…" in fzf               |
| `path_truncate_long_names_enabled`     | boolean | `false`                 | Enable/disable long folder name truncation in navigation menu      |
| `fzf_path_truncate_long_names_enabled` | boolean | `false`                 | Enable/disable long folder name truncation in fzf                  |
| `path_max_folder_name_length`          | number  | `20`                    | Maximum folder name length before truncation in navigation menu    |
| `fzf_path_max_folder_name_length`      | number  | `20`                    | Maximum folder name length before truncation in fzf                |
| `history_size`                         | number  | `10`                    | Number of directories to keep in Tab history                        |
| `history_fzf_path_truncate_enabled`    | boolean | `false`                 | Enable/disable path truncation by depth for Tab history display    |
| `history_fzf_path_max_depth`           | number  | `5`                     | Maximum path depth before truncation for Tab history               |
| `history_fzf_path_truncate_long_names_enabled` | boolean | `false`         | Enable/disable long folder name truncation for Tab history         |
| `history_fzf_path_max_folder_name_length` | number | `30`                   | Maximum folder name length before truncation for Tab history       |

**Note:** Configuration bookmarks defined in the `bookmarks` option cannot be deleted through the plugin interface. They serve as permanent, protected bookmarks that are always available

### Bookmark Configuration

The plugin supports a simplified bookmark syntax in the configuration:

```lua
-- Simplified syntax (recommended)
local bookmarks = {
  { tag = "Desktop", path = "~/Desktop", key = "d" },
  { tag = "Projects", path = "~/Projects", key = "p" },
}
```

**Features of simplified syntax:**

- **Tilde expansion** - `~` is automatically expanded to home directory
- **Path normalization** - Separators `/` are automatically converted for your OS
- **Automatic trailing separator** - Directories get proper trailing separators

### Path Truncation

The path truncation feature can be controlled by two options:

- `path_truncate_enabled` (boolean, default: `false`) - Enables or disables path truncation entirely. If not specified in config, defaults to `false`
- `path_max_depth` (number, default: `3`) - Controls how long paths are displayed in the navigation menu

When `path_truncate_enabled` is explicitly set to `true` and a path has more directory levels than `path_max_depth`, the beginning parts are replaced with "…" to keep the display concise.

**By default (when `path_truncate_enabled` is not specified or set to `false`):**

- All paths are displayed in full without truncation
- `C:\Users\Documents\Projects\MyProject` → `C:\Users\Documents\Projects\MyProject` (full path)

**With `path_truncate_enabled = true` and `path_max_depth = 3`:**

- `C:\Users\Documents` → `C:\Users\Documents` (no change, 3 parts)
- `C:\Users\Documents\Projects\MyProject` → `C:\…\Projects\MyProject` (truncated, 5 parts)
- `~/.config/yazi/plugins/whoosh.yazi` → `~\…\plugins\whoosh.yazi` (truncated, 5 parts)

#### Folder Name Length Truncation

Long folder names can be truncated to improve readability in both navigation menu and fuzzy search:

**Configuration Options:**

- `path_truncate_long_names_enabled` (boolean, default: `false`) - Enable/disable for navigation menu
- `fzf_path_truncate_long_names_enabled` (boolean, default: `false`) - Enable/disable for fuzzy search (fzf)
- `path_max_folder_name_length` (number, default: `20`) - Maximum length for folder names in navigation menu
- `fzf_path_max_folder_name_length` (number, default: `20`) - Maximum length for folder names in fuzzy search

**How it works:**

- Individual folder names longer than the specified limit are truncated to 40% of the limit + "..."
- This truncation is applied to each folder name separately and works independently of depth-based path truncation
- Both truncation methods can be used together for optimal display
- Windows drive letters (e.g., `C:\`) are handled specially and never truncated

**Examples with `path_max_folder_name_length = 20`:**

- `VeryLongFolderNameThatExceedsLimit` → `VeryLongF…` (9 chars + "…")
- `C:\VeryLongFolderNameThatExceedsLimit\Documents` → `C:\VeryLongF…\Documents`
- `ShortName` → `ShortName` (no change, under limit)
- `/home/VeryLongFolderNameThatExceedsLimit/projects` → `/home/VeryLongF…/projects`

**Combined with depth truncation:**

When both folder name truncation and depth-based truncation are enabled, folder names are shortened first, then depth truncation is applied:

- Original: `C:\Users\VeryLongFolderNameThatExceedsLimit\Documents\Projects\MyProject`
- After folder name truncation: `C:\Users\VeryLongF…\Documents\Projects\MyProject`
- After depth truncation (max_depth=3): `C:\…\Projects\MyProject`

This feature significantly improves readability in deeply nested directory structures while preserving the most relevant path information.

## Available Commands

| Command            | Description                                                   |
| ------------------ | ------------------------------------------------------------- |
| `save`             | Add bookmark for hovered file/directory                       |
| `save_cwd`         | Add bookmark for current working directory                    |
| `save_temp`        | Add temporary bookmark for hovered file/directory             |
| `save_cwd_temp`    | Add temporary bookmark for current working directory          |
| `jump_by_key`      | Open navigation menu to jump to bookmark by key               |
| `jump_key_<keys>`  | Jump instantly to bookmark matching the provided key sequence |
| `jump_by_fzf`      | Open fuzzy search to jump to bookmark                         |
| `delete_by_key`    | Delete bookmark by selecting with key                         |
| `delete_by_fzf`    | Delete multiple bookmarks using fzf (TAB to select)           |
| `delete_all`       | Delete all user-created bookmarks (excludes config bookmarks) |
| `delete_all_temp`  | Delete all temporary bookmarks                                |
| `rename_by_key`    | Rename bookmark by selecting with key                         |
| `rename_by_fzf`      | Rename bookmark using fuzzy search                            |

### Direct Key Shortcuts

You can jump without opening the menu by calling the plugin with an inline key sequence:

- `plugin whoosh jump_key_<keys>` - inline sequence such as `jump_key_k`, `jump_key_<Space>`, or `jump_key_bb`.

Sequences must be provided inline; whitespace-separated forms are not supported. The format matches the bookmark editing prompt, so you can mix plain characters, comma-separated tokens, and special keys like `<Space>` or `<A-l>`.

### Navigation Menu Controls

When using `jump_by_key`, the following special controls are available:

| Default key   | Action                                          |
| ------------  | ----------------------------------------------- |
| `<Enter>`     | Create temporary bookmark for current directory |
| `<Space>`     | Open fuzzy search                               |
| `<Tab>`       | Open directory history (only if history exists) |
| `<Backspace>` | Return to previous directory (if available)     |
| `[a-zA-Z0-9]` | Jump to bookmark with corresponding key         |

## Inspiration

- [yamb](https://github.com/h-hg/yamb.yazi)
- [bunny](https://github.com/stelcodes/bunny.yazi)
