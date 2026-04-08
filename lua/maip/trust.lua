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

--- MAIP Neovim trust score display.
--- Shows trust scores via virtual text, signs, and floating windows.
--- @module maip.trust
local config = require("maip.config")
local agents = require("maip.agents")
local utils = require("maip.utils")
local ui = require("maip.ui")

local M = {}

--- Namespace for MAIP virtual text extmarks.
--- @type number
M._ns = vim.api.nvim_create_namespace("maip_trust")

--- Timer handle for periodic trust refresh.
--- @type userdata|nil
M._timer = nil

--- Pattern to match agent ID strings in buffers.
--- Matches UUIDs and common ID formats.
--- @type string
M._agent_id_pattern = "[%w]+-[%w]+-[%w]+-[%w]+-[%w]+"

--- Get the sign configuration for a trust score.
--- @param score number The trust score (0.0 to 1.0).
--- @return table The sign config with text and hl fields.
function M.get_sign_for_score(score)
  local cfg = config.get()
  if score >= cfg.trust_thresholds.high then
    return cfg.signs.high_trust
  elseif score >= cfg.trust_thresholds.medium then
    return cfg.signs.medium_trust
  else
    return cfg.signs.low_trust
  end
end

--- Format a trust score for display.
--- @param score number The trust score (0.0 to 1.0).
--- @return string The formatted trust string (e.g. "0.85 HIGH").
function M.format_trust(score)
  local cfg = config.get()
  local level
  if score >= cfg.trust_thresholds.high then
    level = "HIGH"
  elseif score >= cfg.trust_thresholds.medium then
    level = "MEDIUM"
  else
    level = "LOW"
  end
  return string.format("%.2f %s", score, level)
end

--- Show trust score as virtual text next to agent ID patterns in the buffer.
--- Scans the buffer for agent ID patterns and annotates them with trust data.
--- @param bufnr number|nil Buffer number (defaults to current buffer).
function M.show_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = config.get()

  if not cfg.show_trust_virtual_text then
    return
  end

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, M._ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    -- Search for agent ID patterns in the line
    local start_pos = 1
    while true do
      local match_start, match_end = line:find(M._agent_id_pattern, start_pos)
      if not match_start then
        break
      end

      local agent_id = line:sub(match_start, match_end)
      local cached_trust = agents.get_cached_trust(agent_id)

      if cached_trust then
        local sign = M.get_sign_for_score(cached_trust)
        local text = string.format(" %s %.2f", sign.text, cached_trust)

        vim.api.nvim_buf_set_extmark(bufnr, M._ns, i - 1, match_end, {
          virt_text = { { text, sign.hl } },
          virt_text_pos = "eol",
        })
      end

      start_pos = match_end + 1
    end
  end
end

--- Get trust score for an agent and display it in a floating window.
--- @param agent_id string|nil The agent ID (defaults to configured agent).
function M.show_trust_float(agent_id)
  if not agent_id or agent_id == "" then
    local cfg = config.get()
    agent_id = cfg.agent_id
  end

  if not agent_id or agent_id == "" then
    ui.error("Agent ID is required. Register an agent or provide one.")
    return
  end

  ui.notify("Fetching trust score for " .. utils.truncate(agent_id, 20) .. "...")

  agents.get_trust(agent_id, function(data)
    if not data then
      return
    end

    local score = data.trust_score or data.score or 0
    local sign = M.get_sign_for_score(score)

    local lines = {
      "Trust Score",
      "═══════════════════════════════════════",
      "",
      "  Agent ID:    " .. agent_id,
      "  Trust Score: " .. M.format_trust(score),
      "",
    }

    -- Visual trust bar
    local bar_width = 30
    local filled = math.floor(score * bar_width)
    local empty = bar_width - filled
    local bar = "  [" .. string.rep("█", filled) .. string.rep("░", empty) .. "]"
    table.insert(lines, bar)
    table.insert(lines, "")

    if data.trust_level or data.level then
      table.insert(lines, "  Level:       " .. (data.trust_level or data.level))
    end
    if data.total_receipts then
      table.insert(lines, "  Receipts:    " .. tostring(data.total_receipts))
    end
    if data.verified_receipts then
      table.insert(lines, "  Verified:    " .. tostring(data.verified_receipts))
    end
    if data.last_activity then
      table.insert(lines, "  Last Active: " .. utils.format_time(data.last_activity))
    end

    table.insert(lines, "")

    ui.float("MAIP Trust Score", lines)
  end)
end

--- Refresh trust scores for all cached agents in the background.
--- Updates the agent cache with fresh trust data from the API.
function M.refresh_all()
  for agent_id, _ in pairs(agents._cache) do
    agents.get_trust(agent_id, function(data)
      if data then
        -- Cache is updated inside agents.get_trust
        -- Refresh virtual text on visible buffers
        utils.schedule(function()
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local bufnr = vim.api.nvim_win_get_buf(win)
            M.show_virtual_text(bufnr)
          end
        end)
      end
    end)
  end
end

--- Start the periodic trust score refresh timer.
function M.start_refresh_timer()
  if M._timer then
    M.stop_refresh_timer()
  end

  local cfg = config.get()
  local interval = cfg.trust_refresh_interval * 1000

  M._timer = vim.loop.new_timer()
  M._timer:start(interval, interval, vim.schedule_wrap(function()
    M.refresh_all()
  end))
end

--- Stop the periodic trust score refresh timer.
function M.stop_refresh_timer()
  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end
end

--- Clear all trust virtual text from a buffer.
--- @param bufnr number|nil Buffer number (defaults to current buffer).
function M.clear_virtual_text(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, M._ns, 0, -1)
end

return M
