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

--- Minimal init file for running MAIP tests with plenary.nvim.
--- Usage: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/maip/ {minimal_init = 'tests/minimal_init.lua'}"

-- Set up runtimepath to include the plugin and plenary
local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"
local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")

vim.opt.rtp:append(plugin_dir)
vim.opt.rtp:append(plenary_dir)

-- Ensure plenary is available
local ok, _ = pcall(require, "plenary")
if not ok then
  print("plenary.nvim not found at: " .. plenary_dir)
  print("Set PLENARY_DIR environment variable or clone plenary.nvim to /tmp/plenary.nvim")
  print("  git clone https://github.com/nvim-lua/plenary.nvim " .. plenary_dir)
  os.exit(1)
end

-- Disable swap files and other noisy features for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false

-- Set up test environment variables
vim.env.MAIP_API_KEY = vim.env.MAIP_API_KEY or "test-api-key-12345"
vim.env.MAIP_TENANT_ID = vim.env.MAIP_TENANT_ID or "test-tenant-id"
vim.env.MAIP_AGENT_ID = vim.env.MAIP_AGENT_ID or "test-agent-id"
