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

--- MAIP Neovim Telescope integration.
--- Provides pickers for searching and browsing receipts and agents.
--- Only loaded when telescope.nvim is available.
--- @module maip.telescope
local M = {}

--- Check whether telescope.nvim is available.
--- @return boolean
function M.is_available()
  local ok, _ = pcall(require, "telescope")
  return ok
end

--- Receipt picker with preview showing receipt details.
--- @param opts table|nil Telescope picker options.
function M.receipts(opts)
  if not M.is_available() then
    require("maip.ui").warn("Telescope.nvim is not installed. Using floating window fallback.")
    local receipts_mod = require("maip.receipts")
    receipts_mod.list({}, function(receipt_list)
      receipts_mod.show_list_float(receipt_list)
    end)
    return
  end

  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local utils = require("maip.utils")
  local receipts_mod = require("maip.receipts")
  local ui = require("maip.ui")

  ui.notify("Loading receipts...")

  receipts_mod.list({ limit = 100 }, function(receipt_list)
    if not receipt_list or #receipt_list == 0 then
      ui.notify("No receipts found")
      return
    end

    vim.schedule(function()
      pickers
        .new(opts, {
          prompt_title = "MAIP Receipts",
          finder = finders.new_table({
            results = receipt_list,
            entry_maker = function(receipt)
              local display = string.format(
                "%-14s  %-14s  %s",
                utils.truncate(receipt.receipt_id or "?", 14),
                receipt.action_type or "?",
                utils.format_time(receipt.timestamp or "")
              )
              return {
                value = receipt,
                display = display,
                ordinal = (receipt.receipt_id or "") .. " " .. (receipt.action_type or ""),
              }
            end,
          }),
          sorter = conf.generic_sorter(opts),
          previewer = previewers.new_buffer_previewer({
            title = "Receipt Details",
            define_preview = function(self, entry)
              local receipt = entry.value
              local lines = {
                "Receipt ID:    " .. (receipt.receipt_id or "N/A"),
                "Action Type:   " .. (receipt.action_type or "N/A"),
                "Agent ID:      " .. (receipt.agent_id or "N/A"),
                "Timestamp:     " .. utils.format_time(receipt.timestamp or ""),
                "Verified:      " .. tostring(receipt.verified or false),
                "",
              }

              if receipt.input_hash then
                table.insert(lines, "Input Hash:    " .. receipt.input_hash)
              end
              if receipt.output_hash then
                table.insert(lines, "Output Hash:   " .. receipt.output_hash)
              end
              if receipt.chain_hash then
                table.insert(lines, "Chain Hash:    " .. receipt.chain_hash)
              end

              if receipt.metadata then
                table.insert(lines, "")
                table.insert(lines, "Metadata:")
                for k, v in pairs(receipt.metadata) do
                  if type(v) == "table" then
                    table.insert(lines, "  " .. k .. ": " .. vim.fn.json_encode(v))
                  else
                    table.insert(lines, "  " .. k .. ": " .. tostring(v))
                  end
                end
              end

              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            end,
          }),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              if selection and selection.value and selection.value.receipt_id then
                receipts_mod.verify(selection.value.receipt_id, nil)
              end
            end)
            return true
          end,
        })
        :find()
    end)
  end)
end

--- Agent picker with preview showing trust score and activity.
--- @param opts table|nil Telescope picker options.
function M.agents(opts)
  if not M.is_available() then
    require("maip.ui").warn("Telescope.nvim is not installed.")
    return
  end

  opts = opts or {}

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local previewers = require("telescope.previewers")
  local utils = require("maip.utils")
  local agents_mod = require("maip.agents")
  local trust_mod = require("maip.trust")
  local ui = require("maip.ui")

  ui.notify("Loading agents...")

  agents_mod.list(function(agent_list)
    if not agent_list or #agent_list == 0 then
      ui.notify("No agents found")
      return
    end

    vim.schedule(function()
      pickers
        .new(opts, {
          prompt_title = "MAIP Agents",
          finder = finders.new_table({
            results = agent_list,
            entry_maker = function(agent)
              local score = agent.trust_score or 0
              local display = string.format(
                "%-20s  %-12s  Trust: %.2f  %s",
                utils.truncate(agent.name or "?", 20),
                agent.agent_type or "?",
                score,
                agent.status or "?"
              )
              return {
                value = agent,
                display = display,
                ordinal = (agent.name or "") .. " " .. (agent.agent_type or ""),
              }
            end,
          }),
          sorter = conf.generic_sorter(opts),
          previewer = previewers.new_buffer_previewer({
            title = "Agent Details",
            define_preview = function(self, entry)
              local agent = entry.value
              local score = agent.trust_score or 0
              local sign = trust_mod.get_sign_for_score(score)

              local lines = {
                "Agent ID:      " .. (agent.agent_id or agent.id or "N/A"),
                "Name:          " .. (agent.name or "N/A"),
                "Type:          " .. (agent.agent_type or "N/A"),
                "Status:        " .. (agent.status or "N/A"),
                "Trust Score:   " .. trust_mod.format_trust(score),
                "",
              }

              -- Visual trust bar
              local bar_width = 30
              local filled = math.floor(score * bar_width)
              local empty = bar_width - filled
              table.insert(lines, "[" .. string.rep("█", filled) .. string.rep("░", empty) .. "]")
              table.insert(lines, "")

              if agent.capabilities then
                table.insert(lines, "Capabilities:")
                for _, cap in ipairs(agent.capabilities) do
                  table.insert(lines, "  - " .. cap)
                end
                table.insert(lines, "")
              end

              if agent.created_at then
                table.insert(lines, "Created:       " .. utils.format_time(agent.created_at))
              end
              if agent.last_active then
                table.insert(lines, "Last Active:   " .. utils.format_time(agent.last_active))
              end

              vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            end,
          }),
          attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
              actions.close(prompt_bufnr)
              local selection = action_state.get_selected_entry()
              if selection and selection.value then
                local agent_id = selection.value.agent_id or selection.value.id
                if agent_id then
                  trust_mod.show_trust_float(agent_id)
                end
              end
            end)
            return true
          end,
        })
        :find()
    end)
  end)
end

return M
