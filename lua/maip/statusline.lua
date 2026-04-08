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

--- MAIP Neovim statusline component.
--- Compatible with lualine, heirline, and any statusline that accepts a function.
--- @module maip.statusline
local config = require("maip.config")
local agents = require("maip.agents")
local trust = require("maip.trust")

local M = {}

--- Returns a formatted string for use in statusline plugins.
--- Format: "MAIP: [dot] [score]" where dot is colored based on trust level.
--- Returns an empty string when the plugin is not configured or no agent is set.
--- @return string The statusline component string.
function M.component()
  if not config.is_initialized() then
    return ""
  end

  local cfg = config.get()
  if cfg.agent_id == "" then
    return ""
  end

  local score = agents.get_cached_trust(cfg.agent_id)
  if not score then
    return "MAIP: --"
  end

  local sign = trust.get_sign_for_score(score)
  return string.format("MAIP: %s %.2f", sign.text, score)
end

--- Returns a table compatible with lualine component format.
--- Can be used directly in lualine configuration:
---   lualine_x = { require("maip.statusline").lualine() }
--- @return table The lualine component configuration table.
function M.lualine()
  return {
    function()
      return M.component()
    end,
    cond = function()
      return config.is_initialized() and config.get().agent_id ~= ""
    end,
    color = function()
      if not config.is_initialized() then
        return nil
      end
      local cfg = config.get()
      if cfg.agent_id == "" then
        return nil
      end
      local score = agents.get_cached_trust(cfg.agent_id)
      if not score then
        return nil
      end
      local sign = trust.get_sign_for_score(score)
      return { fg = sign.hl }
    end,
  }
end

--- Returns a provider function compatible with heirline.
--- @return function The provider function for heirline.
function M.heirline_provider()
  return function()
    return M.component()
  end
end

--- Returns a condition function for statusline plugins.
--- Returns true when MAIP is configured and has an active agent.
--- @return function The condition function.
function M.condition()
  return function()
    return config.is_initialized() and config.get().agent_id ~= ""
  end
end

return M
