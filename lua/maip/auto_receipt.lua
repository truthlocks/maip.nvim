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

--- MAIP Neovim auto-receipt generation.
--- Automatically creates MAIP receipts when git commits are made.
--- Integrates with native gitcommit filetype, fugitive, and neogit.
--- @module maip.auto_receipt
local config = require("maip.config")
local receipts = require("maip.receipts")
local utils = require("maip.utils")
local ui = require("maip.ui")

local M = {}

--- Autocmd group ID for MAIP auto-receipt.
--- @type number|nil
M._augroup = nil

--- Whether auto-receipt is currently active.
--- @type boolean
M._active = false

--- Set up autocmds for automatic receipt generation on git commit.
--- Creates receipts when:
---   1. A gitcommit buffer is written (native git commit workflow).
---   2. Fugitive's :Git commit completes (if fugitive is installed).
---   3. Neogit commit completes (if neogit is installed).
function M.setup()
  local cfg = config.get()
  if not cfg.auto_receipt_on_commit then
    return
  end

  M._augroup = vim.api.nvim_create_augroup("MAIPAutoReceipt", { clear = true })

  -- Native gitcommit: fires when the COMMIT_EDITMSG buffer is written
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = M._augroup,
    pattern = "COMMIT_EDITMSG",
    callback = function()
      M._on_commit_write()
    end,
    desc = "MAIP: Create receipt on git commit message write",
  })

  -- Also listen for the gitcommit filetype in case of different git workflows
  vim.api.nvim_create_autocmd("FileType", {
    group = M._augroup,
    pattern = "gitcommit",
    callback = function(ev)
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = M._augroup,
        buffer = ev.buf,
        once = true,
        callback = function()
          M._on_commit_write()
        end,
        desc = "MAIP: Create receipt on gitcommit filetype write",
      })
    end,
    desc = "MAIP: Set up receipt hook for gitcommit buffers",
  })

  -- Fugitive integration: listen for User event after commit
  vim.api.nvim_create_autocmd("User", {
    group = M._augroup,
    pattern = "FugitiveChanged",
    callback = function()
      M._on_fugitive_changed()
    end,
    desc = "MAIP: Create receipt on fugitive commit",
  })

  -- Neogit integration: listen for NeogitPushComplete and NeogitCommitComplete
  vim.api.nvim_create_autocmd("User", {
    group = M._augroup,
    pattern = "NeogitCommitComplete",
    callback = function()
      M._on_neogit_commit()
    end,
    desc = "MAIP: Create receipt on neogit commit",
  })

  M._active = true
end

--- Tear down auto-receipt autocmds.
function M.teardown()
  if M._augroup then
    vim.api.nvim_del_augroup_by_id(M._augroup)
    M._augroup = nil
  end
  M._active = false
end

--- Handle the COMMIT_EDITMSG write event.
--- Waits briefly for git to finish processing, then creates a receipt.
function M._on_commit_write()
  -- Defer slightly to let git finish the commit
  vim.defer_fn(function()
    local commit_hash = utils.git_commit_hash_full()
    if not commit_hash then
      return
    end

    local files_changed = utils.git_files_changed()
    if #files_changed == 0 then
      return
    end

    receipts.create_for_commit(commit_hash, files_changed, nil)
  end, 500)
end

--- Handle the fugitive FugitiveChanged event.
--- Checks if HEAD moved (indicating a new commit) and creates a receipt.
function M._on_fugitive_changed()
  vim.defer_fn(function()
    local commit_hash = utils.git_commit_hash_full()
    if not commit_hash then
      return
    end

    -- Check if this is actually a new commit by comparing with cache
    if M._last_commit_hash == commit_hash then
      return
    end
    M._last_commit_hash = commit_hash

    local files_changed = utils.git_files_changed()
    if #files_changed == 0 then
      return
    end

    receipts.create_for_commit(commit_hash, files_changed, nil)
  end, 300)
end

--- Handle the neogit NeogitCommitComplete event.
function M._on_neogit_commit()
  vim.defer_fn(function()
    local commit_hash = utils.git_commit_hash_full()
    if not commit_hash then
      return
    end

    local files_changed = utils.git_files_changed()
    if #files_changed == 0 then
      return
    end

    receipts.create_for_commit(commit_hash, files_changed, nil)
  end, 500)
end

--- Check whether auto-receipt is currently active.
--- @return boolean
function M.is_active()
  return M._active
end

--- Last known commit hash, used to detect new commits in fugitive integration.
--- @type string|nil
M._last_commit_hash = nil

return M
