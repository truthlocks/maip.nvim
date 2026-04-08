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

--- MAIP Neovim user commands.
--- Registers all :MAIP* commands and their handlers.
--- @module maip.commands
local config = require("maip.config")
local receipts = require("maip.receipts")
local agents = require("maip.agents")
local trust = require("maip.trust")
local telescope_mod = require("maip.telescope")
local ui = require("maip.ui")

local M = {}

--- Register all MAIP user commands.
function M.setup()
  vim.api.nvim_create_user_command("MAIPRegisterAgent", function(cmd_opts)
    M._register_agent(cmd_opts)
  end, {
    nargs = "*",
    desc = "MAIP: Register a new agent with the MAIP API",
    complete = function(_, _, _)
      return { "editor", "ci", "reviewer", "deployer", "monitor", "scanner" }
    end,
  })

  vim.api.nvim_create_user_command("MAIPCreateReceipt", function()
    M._create_receipt()
  end, {
    nargs = 0,
    desc = "MAIP: Create a receipt for the current buffer",
  })

  vim.api.nvim_create_user_command("MAIPVerifyReceipt", function(cmd_opts)
    M._verify_receipt(cmd_opts)
  end, {
    nargs = "?",
    desc = "MAIP: Verify a receipt by ID",
  })

  vim.api.nvim_create_user_command("MAIPListReceipts", function()
    M._list_receipts()
  end, {
    nargs = 0,
    desc = "MAIP: List all receipts (Telescope or floating window)",
  })

  vim.api.nvim_create_user_command("MAIPShowTrust", function(cmd_opts)
    M._show_trust(cmd_opts)
  end, {
    nargs = "?",
    desc = "MAIP: Show trust score for an agent",
  })

  vim.api.nvim_create_user_command("MAIPDashboard", function()
    M._dashboard()
  end, {
    nargs = 0,
    desc = "MAIP: Open the MAIP dashboard",
  })

  vim.api.nvim_create_user_command("MAIPListAgents", function()
    M._list_agents()
  end, {
    nargs = 0,
    desc = "MAIP: List all registered agents (Telescope or floating window)",
  })
end

--- Handler for :MAIPRegisterAgent [name] [type].
--- @param cmd_opts table Command options from nvim_create_user_command.
function M._register_agent(cmd_opts)
  local args = vim.split(cmd_opts.args or "", "%s+", { trimempty = true })
  local name = args[1]
  local agent_type = args[2]

  if not name or name == "" then
    ui.input("Agent name: ", function(input_name)
      if not input_name or input_name == "" then
        ui.error("Agent name is required")
        return
      end
      ui.input("Agent type (editor/ci/reviewer): ", function(input_type)
        input_type = input_type or "editor"
        if input_type == "" then
          input_type = "editor"
        end
        agents.register(input_name, input_type, nil)
      end, "editor")
    end)
  else
    agent_type = agent_type or "editor"
    agents.register(name, agent_type, nil)
  end
end

--- Handler for :MAIPCreateReceipt.
function M._create_receipt()
  local cfg = config.get()
  if cfg.agent_id == "" then
    ui.error("No agent configured. Run :MAIPRegisterAgent first or set agent_id in setup().")
    return
  end
  receipts.create_for_buffer(nil, nil)
end

--- Handler for :MAIPVerifyReceipt [id].
--- @param cmd_opts table Command options from nvim_create_user_command.
function M._verify_receipt(cmd_opts)
  local receipt_id = cmd_opts.args

  if not receipt_id or receipt_id == "" then
    ui.input("Receipt ID: ", function(input_id)
      if not input_id or input_id == "" then
        ui.error("Receipt ID is required")
        return
      end
      receipts.verify(input_id, nil)
    end)
  else
    receipts.verify(receipt_id, nil)
  end
end

--- Handler for :MAIPListReceipts.
--- Opens Telescope picker if available and configured, otherwise uses floating window.
function M._list_receipts()
  local cfg = config.get()
  if cfg.telescope and telescope_mod.is_available() then
    telescope_mod.receipts()
  else
    receipts.list({}, function(receipt_list)
      receipts.show_list_float(receipt_list)
    end)
  end
end

--- Handler for :MAIPShowTrust [agent_id].
--- @param cmd_opts table Command options from nvim_create_user_command.
function M._show_trust(cmd_opts)
  local agent_id = cmd_opts.args
  if not agent_id or agent_id == "" then
    agent_id = nil
  end
  trust.show_trust_float(agent_id)
end

--- Handler for :MAIPDashboard.
function M._dashboard()
  ui.dashboard()
end

--- Handler for :MAIPListAgents.
--- Opens Telescope picker if available and configured, otherwise uses floating window.
function M._list_agents()
  local cfg = config.get()
  if cfg.telescope and telescope_mod.is_available() then
    telescope_mod.agents()
  else
    agents.list(function(agent_list)
      if not agent_list or #agent_list == 0 then
        ui.notify("No agents found")
        return
      end

      local lines = {
        "MAIP Agents",
        "═══════════════════════════════════════════════════════════",
        "",
        string.format("  %-20s  %-12s  %-10s  %s", "Name", "Type", "Trust", "Status"),
        "  " .. string.rep("─", 60),
      }

      local utils = require("maip.utils")
      for _, agent in ipairs(agent_list) do
        table.insert(
          lines,
          string.format(
            "  %-20s  %-12s  %-10s  %s",
            utils.truncate(agent.name or "?", 20),
            agent.agent_type or "?",
            string.format("%.2f", agent.trust_score or 0),
            agent.status or "?"
          )
        )
      end

      table.insert(lines, "")
      table.insert(lines, "  Total: " .. #agent_list .. " agents")
      table.insert(lines, "")

      ui.float("MAIP Agents", lines, { width = 80 })
    end)
  end
end

return M
