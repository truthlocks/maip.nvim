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

--- MAIP Neovim plugin utility functions.
--- Provides hashing, JSON encoding/decoding, time formatting, and async helpers.
--- @module maip.utils
local M = {}

--- Compute the SHA-256 hash of a string.
--- Uses vim.fn.sha256 when available, falls back to external sha256sum.
--- @param str string The input string to hash.
--- @return string The hex-encoded SHA-256 digest.
function M.sha256(str)
  if vim.fn.exists("*sha256") == 1 then
    return vim.fn.sha256(str)
  end

  local tmpfile = vim.fn.tempname()
  local f = io.open(tmpfile, "w")
  if not f then
    error("[MAIP] Failed to create temp file for SHA-256 computation")
  end
  f:write(str)
  f:close()

  local handle = io.popen("sha256sum " .. vim.fn.shellescape(tmpfile) .. " 2>/dev/null")
  if not handle then
    os.remove(tmpfile)
    error("[MAIP] sha256sum command not available")
  end

  local result = handle:read("*a")
  handle:close()
  os.remove(tmpfile)

  local hash = result:match("^(%x+)")
  if not hash then
    error("[MAIP] Failed to parse SHA-256 output")
  end
  return hash
end

--- Encode a Lua table as a JSON string.
--- @param tbl table The Lua table to encode.
--- @return string The JSON string.
function M.json_encode(tbl)
  return vim.fn.json_encode(tbl)
end

--- Decode a JSON string into a Lua table.
--- @param str string The JSON string to decode.
--- @return table|nil The decoded Lua table, or nil on failure.
--- @return string|nil Error message on failure.
function M.json_decode(str)
  if str == nil or str == "" then
    return nil, "Empty input string"
  end

  local ok, result = pcall(vim.fn.json_decode, str)
  if not ok then
    return nil, "JSON decode error: " .. tostring(result)
  end
  return result, nil
end

--- Format an ISO 8601 timestamp for human-readable display.
--- @param timestamp string ISO 8601 timestamp (e.g. "2026-04-07T12:00:00Z").
--- @return string Formatted time string.
function M.format_time(timestamp)
  if not timestamp or timestamp == "" then
    return "N/A"
  end

  local year, month, day, hour, min, sec =
    timestamp:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not year then
    return timestamp
  end

  return string.format("%s-%s-%s %s:%s:%s", year, month, day, hour, min, sec)
end

--- Get the current git branch name.
--- @return string|nil The branch name, or nil if not in a git repo.
function M.git_branch()
  local handle = io.popen("git rev-parse --abbrev-ref HEAD 2>/dev/null")
  if not handle then
    return nil
  end
  local branch = handle:read("*l")
  handle:close()
  if branch and branch ~= "" then
    return branch
  end
  return nil
end

--- Get the current git commit hash (short form).
--- @return string|nil The short commit hash, or nil if not in a git repo.
function M.git_commit_hash()
  local handle = io.popen("git rev-parse --short HEAD 2>/dev/null")
  if not handle then
    return nil
  end
  local hash = handle:read("*l")
  handle:close()
  if hash and hash ~= "" then
    return hash
  end
  return nil
end

--- Get the full git commit hash.
--- @return string|nil The full commit hash, or nil if not in a git repo.
function M.git_commit_hash_full()
  local handle = io.popen("git rev-parse HEAD 2>/dev/null")
  if not handle then
    return nil
  end
  local hash = handle:read("*l")
  handle:close()
  if hash and hash ~= "" then
    return hash
  end
  return nil
end

--- Get the list of files changed in the most recent git commit.
--- @return table A list of file paths.
function M.git_files_changed()
  local handle = io.popen("git diff-tree --no-commit-id --name-only -r HEAD 2>/dev/null")
  if not handle then
    return {}
  end
  local files = {}
  for line in handle:lines() do
    if line and line ~= "" then
      table.insert(files, line)
    end
  end
  handle:close()
  return files
end

--- Get the git remote origin URL.
--- @return string|nil The remote URL, or nil if not available.
function M.git_remote_url()
  local handle = io.popen("git remote get-url origin 2>/dev/null")
  if not handle then
    return nil
  end
  local url = handle:read("*l")
  handle:close()
  if url and url ~= "" then
    return url
  end
  return nil
end

--- Schedule a function to run on the Neovim main loop.
--- Wraps vim.schedule for safe UI updates from async callbacks.
--- @param fn function The function to schedule.
function M.schedule(fn)
  vim.schedule(fn)
end

--- Truncate a string to a maximum length, appending ellipsis if truncated.
--- @param str string The input string.
--- @param max_len number Maximum allowed length.
--- @return string The truncated string.
function M.truncate(str, max_len)
  if not str then
    return ""
  end
  if #str <= max_len then
    return str
  end
  return str:sub(1, max_len - 3) .. "..."
end

--- Pad a string to a minimum length with spaces on the right.
--- @param str string The input string.
--- @param min_len number Minimum length.
--- @return string The padded string.
function M.pad_right(str, min_len)
  if #str >= min_len then
    return str
  end
  return str .. string.rep(" ", min_len - #str)
end

--- Generate a timestamp in ISO 8601 format.
--- @return string The current UTC timestamp.
function M.iso_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

return M
