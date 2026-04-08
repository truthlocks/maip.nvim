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

--- MAIP Neovim agent management.
--- Handles agent registration, listing, and trust score queries.
--- @module maip.agents
local client = require("maip.client")
local config = require("maip.config")
local utils = require("maip.utils")
local ui = require("maip.ui")

local M = {}

--- Cache of known agents and their trust scores.
--- @type table<string, table>
M._cache = {}

--- Register a new agent with the MAIP API.
--- @param name string The agent name.
--- @param agent_type string The agent type (e.g. "editor", "ci", "reviewer").
--- @param callback function|nil Callback receiving the registration result.
function M.register(name, agent_type, callback)
  if not name or name == "" then
    ui.error("Agent name is required")
    if callback then
      callback(nil)
    end
    return
  end

  agent_type = agent_type or "editor"

  local payload = {
    name = name,
    agent_type = agent_type,
    capabilities = { "file_edit", "git_commit", "code_review" },
    metadata = {
      editor = "neovim",
      plugin_version = "1.0.0",
      platform = vim.loop.os_uname().sysname,
      neovim_version = vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
    },
  }

  ui.notify("Registering agent '" .. name .. "' (type: " .. agent_type .. ")...")

  client.post("/agents", {
    body = payload,
    on_success = function(data)
      local agent_id = data.agent_id or data.id or "unknown"

      -- Update config with new agent_id
      local cfg = config.get()
      cfg.agent_id = agent_id

      -- Cache the agent
      M._cache[agent_id] = {
        agent_id = agent_id,
        name = name,
        agent_type = agent_type,
        trust_score = data.trust_score or 0,
        status = data.status or "active",
      }

      local result_lines = {
        "Agent Registration Successful",
        "═══════════════════════════════════════",
        "",
        "  Agent ID:   " .. agent_id,
        "  Name:       " .. name,
        "  Type:       " .. agent_type,
        "  Status:     " .. (data.status or "active"),
        "  Trust:      " .. tostring(data.trust_score or 0),
        "",
        "  The agent_id has been set in your config.",
        "  Add to your setup(): agent_id = \"" .. agent_id .. "\"",
        "",
      }

      ui.float("MAIP Agent Registered", result_lines)

      if callback then
        callback(data)
      end
    end,
    on_error = function(err)
      ui.error("Registration failed: " .. err)
      if callback then
        callback(nil)
      end
    end,
  })
end

--- Get the trust score for a specific agent.
--- @param agent_id string The agent ID.
--- @param callback function Callback receiving the trust score data.
function M.get_trust(agent_id, callback)
  if not agent_id or agent_id == "" then
    local cfg = config.get()
    agent_id = cfg.agent_id
  end

  if not agent_id or agent_id == "" then
    ui.error("Agent ID is required. Register an agent first.")
    if callback then
      callback(nil)
    end
    return
  end

  client.get("/agents/" .. agent_id .. "/trust", {
    on_success = function(data)
      -- Update cache
      M._cache[agent_id] = M._cache[agent_id] or {}
      M._cache[agent_id].trust_score = data.trust_score or data.score or 0
      M._cache[agent_id].trust_level = data.trust_level or data.level or "unknown"
      M._cache[agent_id].last_updated = utils.iso_timestamp()

      if callback then
        callback(data)
      end
    end,
    on_error = function(err)
      ui.error("Failed to get trust score: " .. err)
      if callback then
        callback(nil)
      end
    end,
  })
end

--- List all registered agents.
--- @param callback function Callback receiving the list of agents.
function M.list(callback)
  client.get("/agents", {
    on_success = function(data)
      local agent_list = data.agents or data.items or data
      if type(agent_list) ~= "table" then
        agent_list = {}
      end

      -- Update cache
      for _, agent in ipairs(agent_list) do
        local id = agent.agent_id or agent.id
        if id then
          M._cache[id] = agent
        end
      end

      if callback then
        callback(agent_list)
      end
    end,
    on_error = function(err)
      ui.error("Failed to list agents: " .. err)
      if callback then
        callback({})
      end
    end,
  })
end

--- Show agent details in a floating window.
--- @param agent_id string|nil The agent ID (defaults to configured agent).
function M.show_details_float(agent_id)
  if not agent_id or agent_id == "" then
    local cfg = config.get()
    agent_id = cfg.agent_id
  end

  if not agent_id or agent_id == "" then
    ui.error("Agent ID is required")
    return
  end

  client.get("/agents/" .. agent_id, {
    on_success = function(data)
      local lines = {
        "Agent Details",
        "═══════════════════════════════════════",
        "",
        "  Agent ID:    " .. (data.agent_id or data.id or agent_id),
        "  Name:        " .. (data.name or "N/A"),
        "  Type:        " .. (data.agent_type or "N/A"),
        "  Status:      " .. (data.status or "N/A"),
        "  Trust Score: " .. tostring(data.trust_score or 0),
        "  Trust Level: " .. (data.trust_level or "N/A"),
        "",
      }

      if data.capabilities then
        table.insert(lines, "  Capabilities:")
        for _, cap in ipairs(data.capabilities) do
          table.insert(lines, "    - " .. cap)
        end
        table.insert(lines, "")
      end

      if data.created_at then
        table.insert(lines, "  Created: " .. utils.format_time(data.created_at))
      end
      if data.last_active then
        table.insert(lines, "  Last Active: " .. utils.format_time(data.last_active))
      end

      table.insert(lines, "")

      ui.float("MAIP Agent", lines)
    end,
    on_error = function(err)
      ui.error("Failed to fetch agent details: " .. err)
    end,
  })
end

--- Get the cached trust score for an agent.
--- @param agent_id string The agent ID.
--- @return number|nil The cached trust score, or nil if not cached.
function M.get_cached_trust(agent_id)
  local cached = M._cache[agent_id]
  if cached then
    return cached.trust_score
  end
  return nil
end

--- Clear the agent cache.
function M.clear_cache()
  M._cache = {}
end

return M
