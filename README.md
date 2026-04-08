# maip.nvim

MAIP (Machine-Actionable Integrity Protocol) plugin for Neovim. Lua-native integration for agent management, cryptographic receipts, real-time trust scores, and Telescope browsing.

## Features

- **Agent Registration** -- Register AI agents directly from Neovim
- **Cryptographic Receipts** -- Create SHA-256 receipts for file edits and git commits
- **Receipt Verification** -- Verify receipt authenticity with the MAIP API
- **Trust Scores** -- Real-time trust score monitoring with virtual text and statusline
- **Auto-Receipts** -- Automatically generate receipts on git commit (native git, fugitive, neogit)
- **Telescope Integration** -- Browse and search receipts and agents via Telescope pickers
- **Statusline** -- Components for lualine, heirline, and custom statuslines
- **Dashboard** -- Full-featured dashboard buffer with keymaps, agents, and receipts

## Requirements

- Neovim >= 0.9
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for HTTP and async)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional, for pickers)
- A Truthlocks MAIP API key ([truthlocks.com](https://truthlocks.com))

## Installation

### lazy.nvim

```lua
{
  "truthlocks/maip.nvim",
  opts = {
    api_key = "",           -- or set MAIP_API_KEY env var
    tenant_id = "",         -- or set MAIP_TENANT_ID env var
    agent_id = "",          -- or set MAIP_AGENT_ID env var
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",  -- optional
  },
}
```

### packer.nvim

```lua
use {
  "truthlocks/maip.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("maip").setup({
      api_key = "",
      tenant_id = "",
      agent_id = "",
    })
  end,
}
```

### Manual

Clone to your Neovim packages directory and call setup:

```lua
require("maip").setup({
  api_key = vim.env.MAIP_API_KEY,
  tenant_id = vim.env.MAIP_TENANT_ID,
  agent_id = vim.env.MAIP_AGENT_ID,
})
```

## Configuration

All options with defaults:

```lua
require("maip").setup({
  api_url = "https://api.truthlocks.com/v1/machine-identity",
  api_key = "",                      -- or MAIP_API_KEY env var
  tenant_id = "",                    -- or MAIP_TENANT_ID env var
  agent_id = "",                     -- or MAIP_AGENT_ID env var
  auto_receipt_on_commit = true,     -- auto-receipt on git commit
  show_trust_virtual_text = true,    -- trust scores as virtual text
  trust_refresh_interval = 60,       -- seconds between refreshes
  request_timeout = 30,              -- HTTP timeout in seconds
  max_retries = 3,
  retry_delay = 1,                   -- base retry delay (exponential backoff)
  telescope = true,                  -- enable Telescope integration
  keymaps = {
    create_receipt = "<leader>mc",
    verify_receipt = "<leader>mv",
    list_receipts  = "<leader>ml",
    show_trust     = "<leader>mt",
    register_agent = "<leader>mr",
    dashboard      = "<leader>md",
  },
  signs = {
    high_trust   = { text = ".", hl = "DiagnosticOk" },
    medium_trust = { text = ".", hl = "DiagnosticWarn" },
    low_trust    = { text = ".", hl = "DiagnosticError" },
  },
  trust_thresholds = { high = 0.8, medium = 0.5 },
})
```

Set any keymap to `false` to disable it.

## Commands

| Command              | Description                                  |
|----------------------|----------------------------------------------|
| `:MAIPRegisterAgent` | Register a new machine agent                 |
| `:MAIPCreateReceipt` | Create receipt for current buffer             |
| `:MAIPVerifyReceipt` | Verify a receipt by ID                        |
| `:MAIPListReceipts`  | List receipts (Telescope or floating window) |
| `:MAIPShowTrust`     | Show trust score for an agent                |
| `:MAIPListAgents`    | List registered agents                       |
| `:MAIPDashboard`     | Open the MAIP dashboard                      |

## Keymaps

| Keymap       | Action                |
|--------------|-----------------------|
| `<leader>mc` | Create receipt        |
| `<leader>mv` | Verify receipt        |
| `<leader>ml` | List receipts         |
| `<leader>mt` | Show trust score      |
| `<leader>mr` | Register agent        |
| `<leader>md` | Open dashboard        |

## Telescope

When telescope.nvim is installed:

```vim
:Telescope maip receipts
:Telescope maip agents
```

## Statusline

```lua
-- lualine
require("lualine").setup({
  sections = {
    lualine_x = { require("maip.statusline").lualine() },
  },
})

-- heirline
local MAIPComponent = {
  provider = require("maip.statusline").heirline_provider(),
  condition = require("maip.statusline").condition(),
}

-- generic
local status = require("maip.statusline").component()
```

## Auto-Receipts

When `auto_receipt_on_commit = true`, a MAIP receipt is created on every git commit. Works with native git, vim-fugitive, and neogit.

## Documentation

Full Vim help is available:

```vim
:help maip
```

## License

Apache License 2.0. See [LICENSE](LICENSE).
