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

--- MAIP Neovim plugin auto-load file.
--- Loaded automatically by Neovim's plugin system.
--- Defers actual setup until require("maip").setup() is called by the user.

-- Guard against double-loading
if vim.g.loaded_maip then
  return
end
vim.g.loaded_maip = true

-- Create a deferred setup command so users can call :MAIPSetup if they prefer
vim.api.nvim_create_user_command("MAIPSetup", function(opts)
  local args_str = opts.args or ""
  local setup_opts = {}

  -- Parse simple key=value arguments
  for key, value in args_str:gmatch("(%w+)=(%S+)") do
    if value == "true" then
      setup_opts[key] = true
    elseif value == "false" then
      setup_opts[key] = false
    elseif tonumber(value) then
      setup_opts[key] = tonumber(value)
    else
      setup_opts[key] = value
    end
  end

  require("maip").setup(setup_opts)
  vim.notify("[MAIP] Plugin initialized", vim.log.levels.INFO)
end, {
  nargs = "*",
  desc = "MAIP: Initialize the plugin with optional key=value arguments",
})

-- Register the filetype for MAIP dashboard buffers
vim.filetype.add({
  pattern = {
    [".*%.maip"] = "maip",
  },
})
