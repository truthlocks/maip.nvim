-- Copyright 2026 Truthlocks Inc.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--- MAIP Neovim plugin entry point.
--- Machine Agent Identity Protocol integration for Neovim.
---
--- Usage with lazy.nvim:
---   { "truthlocks/maip-neovim", opts = { api_key = "...", tenant_id = "..." } }
---
--- Usage with packer:
---   use { "truthlocks/maip-neovim", config = function()
---     require("maip").setup({ api_key = "...", tenant_id = "..." })
---   end }
---
--- Manual:
---   require("maip").setup({ api_key = "...", tenant_id = "..." })
---
--- @module maip
local M = {}

--- Plugin version.
--- @type string
M.version = "1.0.0"

--- Initialize the MAIP plugin with user configuration.
--- Merges user options with defaults, registers commands, sets up keymaps,
--- and starts auto-receipt and trust refresh features.
--- @param opts table|nil User configuration options. See maip.config for defaults.
function M.setup(opts)
  -- Initialize configuration
  local config = require("maip.config")
  config.setup(opts)

  -- Register user commands
  local commands = require("maip.commands")
  commands.setup()

  -- Set up keymaps
  M._setup_keymaps()

  -- Set up auto-receipt on git commit
  local cfg = config.get()
  if cfg.auto_receipt_on_commit then
    local auto_receipt = require("maip.auto_receipt")
    auto_receipt.setup()
  end

  -- Start trust refresh timer if agent is configured
  if cfg.agent_id ~= "" then
    local trust = require("maip.trust")
    trust.start_refresh_timer()

    -- Fetch initial trust score
    local agents_mod = require("maip.agents")
    agents_mod.get_trust(cfg.agent_id, function(data)
      if data then
        vim.schedule(function()
          -- Show virtual text on current buffer if enabled
          if cfg.show_trust_virtual_text then
            trust.show_virtual_text(vim.api.nvim_get_current_buf())
          end
        end)
      end
    end)
  end

  -- Register Telescope extension if available and enabled
  if cfg.telescope then
    local telescope_mod = require("maip.telescope")
    if telescope_mod.is_available() then
      local ok, telescope = pcall(require, "telescope")
      if ok then
        telescope.register_extension({
          exports = {
            receipts = telescope_mod.receipts,
            agents = telescope_mod.agents,
          },
        })
      end
    end
  end

  -- Set up autocmd for virtual text on BufEnter
  if cfg.show_trust_virtual_text then
    local augroup = vim.api.nvim_create_augroup("MAIPTrustVirtualText", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
      group = augroup,
      callback = function(ev)
        local trust = require("maip.trust")
        trust.show_virtual_text(ev.buf)
      end,
      desc = "MAIP: Show trust virtual text on buffer enter",
    })
  end
end

--- Set up plugin keymaps based on configuration.
function M._setup_keymaps()
  local cfg = require("maip.config").get()
  local km = cfg.keymaps

  if km.create_receipt then
    vim.keymap.set("n", km.create_receipt, function()
      vim.cmd("MAIPCreateReceipt")
    end, { desc = "MAIP: Create receipt for current buffer", silent = true })
  end

  if km.verify_receipt then
    vim.keymap.set("n", km.verify_receipt, function()
      vim.cmd("MAIPVerifyReceipt")
    end, { desc = "MAIP: Verify a receipt", silent = true })
  end

  if km.list_receipts then
    vim.keymap.set("n", km.list_receipts, function()
      vim.cmd("MAIPListReceipts")
    end, { desc = "MAIP: List receipts", silent = true })
  end

  if km.show_trust then
    vim.keymap.set("n", km.show_trust, function()
      vim.cmd("MAIPShowTrust")
    end, { desc = "MAIP: Show trust score", silent = true })
  end

  if km.register_agent then
    vim.keymap.set("n", km.register_agent, function()
      vim.cmd("MAIPRegisterAgent")
    end, { desc = "MAIP: Register agent", silent = true })
  end

  if km.dashboard then
    vim.keymap.set("n", km.dashboard, function()
      vim.cmd("MAIPDashboard")
    end, { desc = "MAIP: Open dashboard", silent = true })
  end
end

return M
