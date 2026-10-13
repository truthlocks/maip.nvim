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

--- MAIP Neovim developer registration module.
--- Handles :TruthlocksRegister command to register a developer account
--- API keys are kept in process memory; no shared plaintext credential file is written.
--- @module maip.register

local utils = require("maip.utils")

local M = {}

--- The sandbox registration endpoint.
--- @type string
M.REGISTER_URL = "https://sandbox-api.truthlocks.com/v1/developers/register"

--- Register a developer account via the Truthlocks sandbox API.
--- Registration may require email verification before a credential becomes available.
--- @param email string The developer's email address.
function M.register(email)
  if not email or email == "" then
    vim.notify("[Truthlocks] Email is required for registration.", vim.log.levels.ERROR)
    return
  end

  -- Basic email validation
  if not email:match("^[%w%._%+%-]+@[%w%.%-]+%.[%a]+$") then
    vim.notify("[Truthlocks] Invalid email address: " .. email, vim.log.levels.ERROR)
    return
  end

  local body = utils.json_encode({ email = email, source = "neovim" })

  local curl_args = {
    "curl",
    "-s",
    "-X", "POST",
    "-H", "Content-Type: application/json",
    "-H", "Accept: application/json",
    "--max-time", "30",
    "-w", "\n%{http_code}",
    "-d", body,
    M.REGISTER_URL,
  }

  local stdout_lines = {}
  local stderr_lines = {}

  vim.fn.jobstart(curl_args, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code ~= 0 then
          local stderr_msg = table.concat(stderr_lines, "\n")
          vim.notify(
            "[Truthlocks] Registration failed (curl exit " .. exit_code .. "): " .. stderr_msg,
            vim.log.levels.ERROR
          )
          return
        end

        -- Parse response: last line is HTTP status code
        if #stdout_lines == 0 then
          vim.notify("[Truthlocks] Empty response from server.", vim.log.levels.ERROR)
          return
        end

        local status_line = stdout_lines[#stdout_lines]
        local status = tonumber(status_line) or 0

        -- Remove status line from body
        if status > 0 then
          table.remove(stdout_lines, #stdout_lines)
        end

        -- Remove trailing empty lines
        while #stdout_lines > 0 and stdout_lines[#stdout_lines] == "" do
          table.remove(stdout_lines, #stdout_lines)
        end

        local response_body = table.concat(stdout_lines, "\n")

        if status >= 200 and status < 300 then
          local data, decode_err = utils.json_decode(response_body)
          if decode_err then
            vim.notify(
              "[Truthlocks] Failed to parse response: " .. decode_err,
              vim.log.levels.ERROR
            )
            return
          end

          local api_key = data and data.api_key
          if type(api_key) == "string" and api_key ~= "" then
            local config = require("maip.config")
            if config.is_initialized() then config.get().api_key = api_key end
            vim.notify("[Truthlocks] Sandbox API key configured for this editor session. Manage durable credentials in Console; it was not written to disk.", vim.log.levels.INFO)
          else
            vim.notify("[Truthlocks] Registration request accepted. Complete any email verification and obtain a sandbox key in Console before using MAIP commands.", vim.log.levels.INFO)
          end
        elseif status == 409 then
          vim.notify(
            "[Truthlocks] This email is already registered. Sign in to Console to manage your sandbox API key.",
            vim.log.levels.WARN
          )
        else
          local msg = "[Truthlocks] Registration failed (HTTP " .. status .. ")"
          if response_body ~= "" then
            local err_data = utils.json_decode(response_body)
            if err_data and err_data.message then
              msg = msg .. ": " .. err_data.message
            elseif err_data and err_data.error then
              msg = msg .. ": " .. err_data.error
            end
          end
          vim.notify(msg, vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

return M
