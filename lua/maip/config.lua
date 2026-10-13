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

--- MAIP Neovim plugin configuration module.
--- Manages default settings and merges user-provided options.
--- @module maip.config
local M = {}

--- Default configuration values for the MAIP plugin.
--- @type table
--- All 10 supported signing algorithms.
--- @type string[]
M.supported_algorithms = {
  "ES256", "ES384", "ES512",
  "RS256", "RS384", "RS512",
  "PS256", "PS384", "PS512",
  "Ed25519",
}

M.defaults = {
  api_url = "https://sandbox-api.truthlocks.com/v1",
  api_key = "",
  bearer_token = "",
  tenant_id = "",
  agent_id = "",
  --- Signing algorithm: ES256, ES384, ES512, RS256, RS384, RS512, PS256, PS384, PS512, Ed25519
  signing_algorithm = "Ed25519",
  auto_receipt_on_commit = false,
  show_trust_virtual_text = true,
  trust_refresh_interval = 60,
  request_timeout = 30,
  max_retries = 2,
  retry_delay = 1,
  keymaps = {
    create_receipt = "<leader>mc",
    verify_receipt = "<leader>mv",
    list_receipts = "<leader>ml",
    show_trust = "<leader>mt",
    register_agent = "<leader>mr",
    dashboard = "<leader>md",
  },
  signs = {
    high_trust = { text = "●", hl = "DiagnosticOk" },
    medium_trust = { text = "●", hl = "DiagnosticWarn" },
    low_trust = { text = "●", hl = "DiagnosticError" },
  },
  trust_thresholds = {
    high = 0.8,
    medium = 0.5,
  },
  telescope = true,
  log_level = "info",
}

--- Active configuration after setup has been called.
--- @type table
M.options = {}

--- Whether setup() has been called.
--- @type boolean
M._initialized = false

--- Merge user options with defaults and resolve environment variable fallbacks.
--- @param opts table|nil User-provided options to merge with defaults.
--- @return table The resolved configuration.
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  if M.options.api_key == "" then
    M.options.api_key = vim.env.MAIP_API_KEY or ""
  end
  if M.options.tenant_id == "" then
    M.options.tenant_id = vim.env.MAIP_TENANT_ID or ""
  end
  if M.options.agent_id == "" then
    M.options.agent_id = vim.env.MAIP_AGENT_ID or ""
  end

  M.options.api_url = M.options.api_url:gsub("/+$", ""):gsub("/v1/machine%-identity$", "/v1"):gsub("/maip/v1$", "/v1")
  M._initialized = true
  return M.options
end

--- Get the current configuration, raising an error if setup has not been called.
--- @return table The active configuration.
function M.get()
  if not M._initialized then
    error("[MAIP] Plugin not initialized. Call require('maip').setup() first.")
  end
  return M.options
end

--- Check whether the plugin has been initialized.
--- @return boolean
function M.is_initialized()
  return M._initialized
end

--- Validate that required configuration fields are present.
--- @return boolean ok True if configuration is valid.
--- @return string|nil err Error message if configuration is invalid.
function M.validate()
  local cfg = M.options
  if (cfg.api_key or "") == "" and (cfg.bearer_token or "") == "" then
    return false, "api_key or bearer_token is required."
  end
  if not cfg.api_url:match("^https://[^/]+/v1$") then
    return false, "api_url must be an HTTPS API origin ending in /v1."
  end
  if (cfg.api_key or ""):find("[\r\n]") or (cfg.bearer_token or ""):find("[\r\n]") then
    return false, "Credentials must not contain line breaks."
  end
  return true, nil
end

return M
