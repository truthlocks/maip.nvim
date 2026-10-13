# Truthlocks MAIP for Neovim

Machine-identity commands, receipt metadata and trust views inside Neovim.
The plugin uses Lua and invokes curl for HTTP requests.

## Install from source

Install `truthlocks/maip.nvim` with your plugin manager, or place a reviewed checkout
on the Neovim runtime path. For lazy.nvim use `main = "maip"` so the setup module is
resolved correctly. Install curl and ensure Neovim can find it. Telescope is optional.
Use the bundled `doc/maip.txt` for the detailed command reference.

```lua
-- lazy.nvim
{ "truthlocks/maip.nvim", tag = "v1.1.0", main = "maip",
  opts = { api_key = vim.env.MAIP_API_KEY or "", telescope = false } }
```

## Configure

After making the plugin available on your runtime path, add this to your Lua setup:

```lua
require("maip").setup({
  api_url = "https://sandbox-api.truthlocks.com/v1",
  api_key = vim.env.MAIP_API_KEY or "",
  agent_id = "",
  auto_receipt_on_commit = false,
  show_trust_virtual_text = false,
  max_retries = 0,
  telescope = false,
})
```

Set credentials in the launching process environment; do not commit them in init.lua.
The default URL is the sandbox API. For approved production workspaces, use
`https://api.truthlocks.com/v1` with the corresponding production key. The server
resolves workspace access from your credential; a caller-supplied tenant ID cannot
change it. Set `agent_id` to a machine identity from that same environment before
creating a receipt. An explicit `bearer_token` supports an existing short-lived
session and takes precedence over `api_key`.

## Commands

| Command | Purpose |
| --- | --- |
| `:MAIPListAgents` | Request agent metadata. |
| `:MAIPRegisterAgent` | Create an agent identity; changes remote state. |
| `:MAIPCreateReceipt` | Request a receipt for the current buffer. |
| `:MAIPListReceipts` | Browse receipt metadata. |
| `:MAIPVerifyReceipt` | Request a cryptographic receipt verdict. |
| `:MAIPShowTrust` | Request an agent's trust information. |
| `:MAIPDashboard` | Open the plugin dashboard. |
| `:TruthlocksRegister` | Request developer registration; complete any email verification in Console. |

## Trust and delivery

A successful HTTP fetch or receipt identifier is not proof of a valid signature.
Verification shows success only when `valid` and `signature_verified` are true and
`verdict` is `VALID`. Historical `UNVERIFIABLE` results stay unverifiable. Receipt
lists are metadata views and are labelled **Not checked** until explicitly verified.

Buffer receipts hash the editor lines joined with LF as UTF-8. This does not assert
that the saved file has the same byte encoding or final newline. Commit receipts
hash the completed commit identifier and changed paths; they do not hash the whole
repository. Relative paths and Git metadata are sent; file contents and authenticated
remote URLs are not sent. The signing-algorithm setting records requested metadata;
the server's registered agent key determines the actual signature algorithm.

Automatic receipts are opt-in and observe completed Fugitive/Neogit updates. Saving
a commit message does not establish a completed commit. Read requests may retry;
mutating requests do not retry automatically. If a write times out, check Console
before retrying because the server may already have accepted it. Authentication is
sent through curl stdin instead of command-line arguments, with no tenant override.
Registration does not write a shared plaintext credentials file.

## Validation scope

Release 1.1.0 passed 91 headless tests on Neovim 0.11.6. An existing hosted QA
workspace passed agent lookup, trust retrieval, a labeled synthetic receipt mint,
cryptographic verification, and filtered receipt retrieval through this Lua client.
The temporary session was revoked after testing. Interactive picker, statusline,
and commit-hook acceptance remains outstanding. Registration email delivery is not
exercised by this suite.

## Troubleshooting

If commands are missing, check runtimepath and setup execution. For HTTP errors,
confirm curl availability, host/key environment, timeout and route compatibility.
For missing picker UI, enable Telescope only after installing it. Keep credentials,
buffer contents and full request headers out of diagnostic reports.
