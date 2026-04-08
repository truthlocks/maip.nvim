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

--- MAIP Neovim async HTTP client.
--- Uses curl via vim.fn.jobstart for non-blocking requests.
--- Supports retry with exponential backoff.
--- @module maip.client
local config = require("maip.config")
local utils = require("maip.utils")

local M = {}

--- Build the full URL for an API path.
--- @param path string The API endpoint path (e.g. "/receipts").
--- @param params table|nil Optional query parameters.
--- @return string The full URL with query string.
local function build_url(path, params)
  local cfg = config.get()
  local url = cfg.api_url .. path

  if params and next(params) then
    local parts = {}
    for k, v in pairs(params) do
      table.insert(parts, vim.uri_encode(tostring(k)) .. "=" .. vim.uri_encode(tostring(v)))
    end
    url = url .. "?" .. table.concat(parts, "&")
  end

  return url
end

--- Build the curl command arguments for a request.
--- @param method string HTTP method (GET, POST, PUT, DELETE).
--- @param url string The full request URL.
--- @param body string|nil JSON body string for POST/PUT.
--- @param cfg table The plugin configuration.
--- @return table The list of curl arguments.
local function build_curl_args(method, url, body, cfg)
  local args = {
    "curl",
    "-s",
    "-X",
    method,
    "-H",
    "Content-Type: application/json",
    "-H",
    "Accept: application/json",
    "-H",
    "X-API-Key: " .. cfg.api_key,
    "-H",
    "X-Tenant-ID: " .. cfg.tenant_id,
    "--max-time",
    tostring(cfg.request_timeout),
    "-w",
    "\n%{http_code}",
  }

  if body and (method == "POST" or method == "PUT" or method == "PATCH") then
    table.insert(args, "-d")
    table.insert(args, body)
  end

  table.insert(args, url)
  return args
end

--- Parse the curl response, splitting the body from the HTTP status code.
--- @param output table List of output lines from curl.
--- @return string body The response body.
--- @return number status The HTTP status code.
local function parse_response(output)
  if not output or #output == 0 then
    return "", 0
  end

  local all_lines = {}
  for _, line in ipairs(output) do
    table.insert(all_lines, line)
  end

  local status_line = all_lines[#all_lines] or ""
  local status = tonumber(status_line) or 0

  if status > 0 then
    table.remove(all_lines, #all_lines)
  end

  -- Remove any trailing empty lines before the status code
  while #all_lines > 0 and all_lines[#all_lines] == "" do
    table.remove(all_lines, #all_lines)
  end

  local body = table.concat(all_lines, "\n")
  return body, status
end

--- Execute an async HTTP request to the MAIP API.
--- @param method string HTTP method (GET, POST, PUT, DELETE).
--- @param path string API path (e.g. "/receipts").
--- @param opts table Request options.
---   - body (table|nil): Request body to be JSON-encoded.
---   - params (table|nil): Query parameters.
---   - on_success (function): Callback receiving (data: table).
---   - on_error (function): Callback receiving (err: string).
---   - retry_count (number|nil): Internal retry counter.
function M.request(method, path, opts)
  local cfg = config.get()
  opts = opts or {}
  opts.retry_count = opts.retry_count or 0

  local ok, err = config.validate()
  if not ok then
    if opts.on_error then
      opts.on_error(err)
    end
    return
  end

  local url = build_url(path, opts.params)
  local body_str = nil
  if opts.body then
    body_str = utils.json_encode(opts.body)
  end

  local curl_args = build_curl_args(method, url, body_str, cfg)
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
      utils.schedule(function()
        if exit_code ~= 0 then
          local retry_max = cfg.max_retries
          if opts.retry_count < retry_max then
            local delay = cfg.retry_delay * math.pow(2, opts.retry_count)
            vim.defer_fn(function()
              opts.retry_count = opts.retry_count + 1
              M.request(method, path, opts)
            end, delay * 1000)
            return
          end

          local stderr_msg = table.concat(stderr_lines, "\n")
          if opts.on_error then
            opts.on_error("curl failed (exit " .. exit_code .. "): " .. stderr_msg)
          end
          return
        end

        local body, status = parse_response(stdout_lines)

        if status >= 200 and status < 300 then
          local data, decode_err = utils.json_decode(body)
          if decode_err then
            if opts.on_error then
              opts.on_error("Failed to parse response: " .. decode_err)
            end
            return
          end
          if opts.on_success then
            opts.on_success(data)
          end
        elseif status == 401 or status == 403 then
          if opts.on_error then
            opts.on_error("Authentication failed (HTTP " .. status .. "). Check your API key.")
          end
        elseif status == 429 then
          local retry_max = cfg.max_retries
          if opts.retry_count < retry_max then
            local delay = cfg.retry_delay * math.pow(2, opts.retry_count + 1)
            vim.defer_fn(function()
              opts.retry_count = opts.retry_count + 1
              M.request(method, path, opts)
            end, delay * 1000)
            return
          end
          if opts.on_error then
            opts.on_error("Rate limited (HTTP 429). Try again later.")
          end
        else
          local retry_max = cfg.max_retries
          if status >= 500 and opts.retry_count < retry_max then
            local delay = cfg.retry_delay * math.pow(2, opts.retry_count)
            vim.defer_fn(function()
              opts.retry_count = opts.retry_count + 1
              M.request(method, path, opts)
            end, delay * 1000)
            return
          end

          local msg = "HTTP " .. status
          if body and body ~= "" then
            local err_data = utils.json_decode(body)
            if err_data and err_data.message then
              msg = msg .. ": " .. err_data.message
            elseif err_data and err_data.error then
              msg = msg .. ": " .. err_data.error
            else
              msg = msg .. ": " .. utils.truncate(body, 200)
            end
          end
          if opts.on_error then
            opts.on_error(msg)
          end
        end
      end)
    end,
  })
end

--- Make an async GET request.
--- @param path string API path.
--- @param opts table Request options (params, on_success, on_error).
function M.get(path, opts)
  M.request("GET", path, opts)
end

--- Make an async POST request.
--- @param path string API path.
--- @param opts table Request options (body, on_success, on_error).
function M.post(path, opts)
  M.request("POST", path, opts)
end

--- Make an async PUT request.
--- @param path string API path.
--- @param opts table Request options (body, on_success, on_error).
function M.put(path, opts)
  M.request("PUT", path, opts)
end

--- Make an async DELETE request.
--- @param path string API path.
--- @param opts table Request options (on_success, on_error).
function M.delete(path, opts)
  M.request("DELETE", path, opts)
end

-- Expose internal functions for testing
M._build_url = build_url
M._build_curl_args = build_curl_args
M._parse_response = parse_response

return M
