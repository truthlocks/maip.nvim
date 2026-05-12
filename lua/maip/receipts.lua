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

--- MAIP Neovim receipt management.
--- Handles creating, verifying, and listing MAIP receipts.
--- @module maip.receipts
local client = require("maip.client")
local config = require("maip.config")
local utils = require("maip.utils")
local ui = require("maip.ui")

local M = {}

--- Create a receipt for the current buffer content.
--- Hashes the buffer text with SHA-256, includes file path, git branch, and commit.
--- @param bufnr number|nil Buffer number (defaults to current buffer).
--- @param callback function|nil Callback receiving the created receipt data.
function M.create_for_buffer(bufnr, callback)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = config.get()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, "\n")
  local content_hash = utils.sha256(content)

  local file_path = vim.api.nvim_buf_get_name(bufnr)
  if file_path == "" then
    file_path = "[unnamed buffer]"
  end

  local git_branch = utils.git_branch()
  local git_commit = utils.git_commit_hash_full()

  local payload = {
    agent_id = cfg.agent_id,
    action_type = "file_edit",
    input_hash = content_hash,
    output_hash = content_hash,
    metadata = {
      file_path = file_path,
      file_size = #content,
      line_count = #lines,
      git_branch = git_branch,
      git_commit = git_commit,
      editor = "neovim",
      plugin_version = "1.0.0",
      timestamp = utils.iso_timestamp(),
    },
  }

  ui.notify("Creating receipt for " .. vim.fn.fnamemodify(file_path, ":t") .. "...")

  client.post("/agent-receipts", {
    body = payload,
    on_success = function(data)
      ui.notify("Receipt created: " .. (data.receipt_id or "unknown"))
      if callback then
        callback(data)
      end
    end,
    on_error = function(err)
      ui.error("Failed to create receipt: " .. err)
      if callback then
        callback(nil)
      end
    end,
  })
end

--- Create a receipt for a git commit.
--- Called automatically when auto_receipt_on_commit is enabled.
--- @param commit_hash string The full git commit hash.
--- @param files_changed table List of file paths changed in the commit.
--- @param callback function|nil Callback receiving the created receipt data.
function M.create_for_commit(commit_hash, files_changed, callback)
  local cfg = config.get()

  local commit_data = commit_hash .. "\n" .. table.concat(files_changed, "\n")
  local commit_content_hash = utils.sha256(commit_data)

  local git_branch = utils.git_branch()
  local remote_url = utils.git_remote_url()

  local payload = {
    agent_id = cfg.agent_id,
    action_type = "git_commit",
    input_hash = commit_content_hash,
    output_hash = commit_content_hash,
    metadata = {
      commit_hash = commit_hash,
      files_changed = files_changed,
      files_count = #files_changed,
      git_branch = git_branch,
      remote_url = remote_url,
      editor = "neovim",
      plugin_version = "1.0.0",
      timestamp = utils.iso_timestamp(),
    },
  }

  ui.notify("Creating receipt for commit " .. commit_hash:sub(1, 8) .. "...")

  client.post("/agent-receipts", {
    body = payload,
    on_success = function(data)
      ui.notify("Commit receipt created: " .. (data.receipt_id or "unknown"))
      if callback then
        callback(data)
      end
    end,
    on_error = function(err)
      ui.error("Failed to create commit receipt: " .. err)
      if callback then
        callback(nil)
      end
    end,
  })
end

--- Verify a receipt by its ID.
--- @param receipt_id string The receipt ID to verify.
--- @param callback function|nil Callback receiving the verification result.
function M.verify(receipt_id, callback)
  if not receipt_id or receipt_id == "" then
    ui.error("Receipt ID is required")
    if callback then
      callback(nil)
    end
    return
  end

  ui.notify("Verifying receipt " .. receipt_id .. "...")

  local encoded_id = vim.uri_encode(receipt_id, "rfc2396")
  client.get("/agent-receipts/" .. encoded_id, {
    on_success = function(data)
      local status = data.status or "unknown"
      local verified = status == "valid"

      local result_lines = {
        "Receipt Verification Result",
        "═══════════════════════════════════════",
        "",
        "  Receipt ID:  " .. (data.receipt_id or receipt_id),
        "  Status:      " .. status,
        "  Verified:    " .. tostring(verified),
      }

      if data.agent_id then
        table.insert(result_lines, "  Agent ID:    " .. data.agent_id)
      end
      if data.created_at then
        table.insert(result_lines, "  Created:     " .. utils.format_time(data.created_at))
      end
      if data.delegation_chain_hash then
        table.insert(result_lines, "  Chain Hash:  " .. utils.truncate(data.delegation_chain_hash, 40))
      end
      if status == "expired" then
        table.insert(result_lines, "")
        table.insert(result_lines, "  ⚠ Receipt has expired")
      elseif status == "superseded" then
        table.insert(result_lines, "")
        table.insert(result_lines, "  ⚠ Receipt has been superseded by a newer receipt")
      elseif not verified then
        table.insert(result_lines, "")
        table.insert(result_lines, "  ✗ Receipt status is " .. status)
      end

      table.insert(result_lines, "")

      ui.float("MAIP Receipt Verification", result_lines)

      if callback then
        callback({ valid = verified, status = status, receipt = data })
      end
    end,
    on_error = function(err)
      ui.error("Verification failed: " .. err)
      if callback then
        callback(nil)
      end
    end,
  })
end

--- List receipts with optional filters.
--- @param filters table|nil Filter options (limit, offset, agent_id, action_type).
--- @param callback function Callback receiving the list of receipts.
function M.list(filters, callback)
  filters = filters or {}

  local params = {}
  if filters.limit then
    params.limit = filters.limit
  end
  if filters.offset then
    params.offset = filters.offset
  end
  if filters.agent_id then
    params.agent_id = filters.agent_id
  end
  if filters.action_type then
    params.action_type = filters.action_type
  end

  client.get("/agent-receipts/filter", {
    params = params,
    on_success = function(data)
      local receipt_list = data.receipts or data.items or data
      if type(receipt_list) ~= "table" then
        receipt_list = {}
      end
      if callback then
        callback(receipt_list)
      end
    end,
    on_error = function(err)
      ui.error("Failed to list receipts: " .. err)
      if callback then
        callback({})
      end
    end,
  })
end

--- Show receipts in a floating window.
--- @param receipt_list table List of receipt objects.
function M.show_list_float(receipt_list)
  if not receipt_list or #receipt_list == 0 then
    ui.notify("No receipts found")
    return
  end

  local lines = {
    "MAIP Receipts",
    "═══════════════════════════════════════════════════════════",
    "",
    string.format(
      "  %-14s  %-14s  %-20s  %s",
      "Receipt ID",
      "Action",
      "Timestamp",
      "Status"
    ),
    "  " .. string.rep("─", 70),
  }

  for _, receipt in ipairs(receipt_list) do
    local status_str = receipt.status or "unknown"
    table.insert(
      lines,
      string.format(
        "  %-14s  %-14s  %-20s  %s",
        utils.truncate(receipt.receipt_id or "?", 14),
        utils.truncate(receipt.action or receipt.action_type or "?", 14),
        utils.format_time(receipt.created_at or receipt.timestamp or ""),
        status_str
      )
    )
  end

  table.insert(lines, "")
  table.insert(lines, "  Total: " .. #receipt_list .. " receipts")
  table.insert(lines, "")

  ui.float("MAIP Receipts", lines, { width = 80 })
end

return M
