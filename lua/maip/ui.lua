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

--- MAIP Neovim UI components.
--- Provides floating windows, input prompts, notifications, and dashboard.
--- @module maip.ui
local utils = require("maip.utils")

local M = {}

--- Show a floating window with the given content.
--- @param title string The window title.
--- @param lines table List of strings to display.
--- @param opts table|nil Optional settings.
---   - width (number|nil): Window width (default: auto-calculated).
---   - height (number|nil): Window height (default: auto-calculated).
---   - border (string|nil): Border style (default: "rounded").
---   - filetype (string|nil): Filetype for the buffer (default: nil).
--- @return number bufnr The buffer number of the floating window.
--- @return number winnr The window number of the floating window.
function M.float(title, lines, opts)
  opts = opts or {}

  local max_width = 0
  for _, line in ipairs(lines) do
    if #line > max_width then
      max_width = #line
    end
  end

  local width = opts.width or math.min(math.max(max_width + 4, 40), math.floor(vim.o.columns * 0.8))
  local height = opts.height or math.min(#lines + 2, math.floor(vim.o.lines * 0.8))

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")

  if opts.filetype then
    vim.api.nvim_buf_set_option(bufnr, "filetype", opts.filetype)
  end

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = opts.border or "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  }

  local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

  -- Close on q or Escape
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end,
  })
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = function()
      if vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_win_close(winnr, true)
      end
    end,
  })

  return bufnr, winnr
end

--- Show an input prompt and invoke the callback with the user's input.
--- @param prompt string The prompt text.
--- @param callback function Callback receiving the user's input string.
--- @param default_value string|nil Optional default value.
function M.input(prompt, callback, default_value)
  vim.ui.input({
    prompt = "[MAIP] " .. prompt,
    default = default_value or "",
  }, function(input)
    if input ~= nil then
      callback(input)
    end
  end)
end

--- Show a notification with MAIP prefix.
--- @param msg string The notification message.
--- @param level number|nil The vim.log.levels value (default: INFO).
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify("[MAIP] " .. msg, level, { title = "MAIP" })
end

--- Show an error notification.
--- @param msg string The error message.
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

--- Show a warning notification.
--- @param msg string The warning message.
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

--- Create and display the MAIP dashboard in a new scratch buffer.
--- Shows agent status, recent receipts, trust scores, and configuration.
--- @return number bufnr The buffer number of the dashboard.
function M.dashboard()
  local cfg = require("maip.config").get()
  local agents_mod = require("maip.agents")
  local receipts_mod = require("maip.receipts")

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
  vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
  vim.api.nvim_buf_set_option(bufnr, "filetype", "maip")

  local lines = {
    "╔══════════════════════════════════════════════════════════════╗",
    "║                    MAIP Dashboard                           ║",
    "║          Machine Agent Identity Protocol                    ║",
    "╚══════════════════════════════════════════════════════════════╝",
    "",
    "Configuration",
    "─────────────────────────────────────────────",
    "  API URL:    " .. cfg.api_url,
    "  Tenant ID:  " .. utils.truncate(cfg.tenant_id, 40),
    "  Agent ID:   " .. utils.truncate(cfg.agent_id, 40),
    "  Auto Receipt on Commit: " .. tostring(cfg.auto_receipt_on_commit),
    "  Trust Virtual Text:     " .. tostring(cfg.show_trust_virtual_text),
    "",
    "Git Context",
    "─────────────────────────────────────────────",
    "  Branch:  " .. (utils.git_branch() or "N/A"),
    "  Commit:  " .. (utils.git_commit_hash() or "N/A"),
    "  Remote:  " .. (utils.git_remote_url() or "N/A"),
    "",
    "Keymaps",
    "─────────────────────────────────────────────",
    "  Create Receipt:   " .. cfg.keymaps.create_receipt,
    "  Verify Receipt:   " .. cfg.keymaps.verify_receipt,
    "  List Receipts:    " .. cfg.keymaps.list_receipts,
    "  Show Trust:       " .. cfg.keymaps.show_trust,
    "  Register Agent:   " .. cfg.keymaps.register_agent,
    "  Dashboard:        " .. cfg.keymaps.dashboard,
    "",
    "Commands",
    "─────────────────────────────────────────────",
    "  :MAIPRegisterAgent [name] [type]   Register a new agent",
    "  :MAIPCreateReceipt                 Receipt for current buffer",
    "  :MAIPVerifyReceipt [id]            Verify a receipt",
    "  :MAIPListReceipts                  List/search receipts",
    "  :MAIPShowTrust [agent_id]          Show trust score",
    "  :MAIPDashboard                     This dashboard",
    "",
    "  Press 'q' to close    Press 'r' to refresh",
    "",
  }

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  -- Switch to the dashboard buffer
  vim.api.nvim_set_current_buf(bufnr)

  -- Set up keymaps for the dashboard
  vim.api.nvim_buf_set_keymap(bufnr, "n", "q", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end,
  })

  vim.api.nvim_buf_set_keymap(bufnr, "n", "r", "", {
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
      M.dashboard()
    end,
  })

  -- Fetch live data and append it
  agents_mod.list(function(agent_list)
    utils.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local agent_lines = {
        "Registered Agents",
        "─────────────────────────────────────────────",
      }

      if agent_list and #agent_list > 0 then
        for _, agent in ipairs(agent_list) do
          local trust = agent.trust_score or 0
          local status = agent.status or "unknown"
          table.insert(
            agent_lines,
            string.format(
              "  %-20s  %-12s  Trust: %.2f  Status: %s",
              utils.truncate(agent.name or agent.agent_id or "?", 20),
              agent.agent_type or "?",
              trust,
              status
            )
          )
        end
      else
        table.insert(agent_lines, "  No agents registered")
      end

      table.insert(agent_lines, "")

      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, agent_lines)
      vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end)
  end)

  receipts_mod.list({ limit = 10 }, function(receipt_list)
    utils.schedule(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local receipt_lines = {
        "Recent Receipts",
        "─────────────────────────────────────────────",
      }

      if receipt_list and #receipt_list > 0 then
        for _, receipt in ipairs(receipt_list) do
          table.insert(
            receipt_lines,
            string.format(
              "  %s  %s  %s  %s",
              utils.truncate(receipt.receipt_id or "?", 12),
              receipt.action_type or "?",
              utils.format_time(receipt.timestamp or ""),
              receipt.verified and "Verified" or "Unverified"
            )
          )
        end
      else
        table.insert(receipt_lines, "  No receipts found")
      end

      table.insert(receipt_lines, "")

      vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, receipt_lines)
      vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end)
  end)

  return bufnr
end

return M
