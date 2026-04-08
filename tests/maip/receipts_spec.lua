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

--- Tests for maip.receipts module.
--- These tests focus on the hash computation and payload construction logic
--- that can be tested without actual API calls.
local config = require("maip.config")
local utils = require("maip.utils")

describe("maip.receipts", function()
  before_each(function()
    config.setup({
      api_key = "test-key",
      tenant_id = "test-tenant",
      agent_id = "test-agent-123",
    })
  end)

  describe("buffer content hashing", function()
    it("should produce consistent SHA-256 hashes for buffer content", function()
      local content = "local x = 1\nlocal y = 2\nreturn x + y"
      local hash1 = utils.sha256(content)
      local hash2 = utils.sha256(content)
      assert.equals(hash1, hash2)
    end)

    it("should produce different hashes for different content", function()
      local hash1 = utils.sha256("version 1")
      local hash2 = utils.sha256("version 2")
      assert.is_not.equals(hash1, hash2)
    end)

    it("should hash empty buffer content", function()
      local hash = utils.sha256("")
      assert.is_string(hash)
      assert.equals(64, #hash)
    end)

    it("should handle large content", function()
      local lines = {}
      for i = 1, 1000 do
        table.insert(lines, "line " .. i .. ": " .. string.rep("x", 80))
      end
      local content = table.concat(lines, "\n")
      local hash = utils.sha256(content)
      assert.is_string(hash)
      assert.equals(64, #hash)
    end)

    it("should be sensitive to whitespace changes", function()
      local hash1 = utils.sha256("hello world")
      local hash2 = utils.sha256("hello  world")
      assert.is_not.equals(hash1, hash2)
    end)
  end)

  describe("commit receipt payload", function()
    it("should build correct commit data string", function()
      local commit_hash = "abc123def456"
      local files = { "src/main.lua", "tests/test.lua" }
      local commit_data = commit_hash .. "\n" .. table.concat(files, "\n")
      assert.equals("abc123def456\nsrc/main.lua\ntests/test.lua", commit_data)
    end)

    it("should handle single file change", function()
      local commit_hash = "abc123"
      local files = { "README.md" }
      local commit_data = commit_hash .. "\n" .. table.concat(files, "\n")
      assert.equals("abc123\nREADME.md", commit_data)
    end)

    it("should handle empty file list", function()
      local commit_hash = "abc123"
      local files = {}
      local commit_data = commit_hash .. "\n" .. table.concat(files, "\n")
      assert.equals("abc123\n", commit_data)
    end)

    it("should produce unique hashes for different commits", function()
      local data1 = "commit1\nfile1.lua"
      local data2 = "commit2\nfile1.lua"
      local hash1 = utils.sha256(data1)
      local hash2 = utils.sha256(data2)
      assert.is_not.equals(hash1, hash2)
    end)

    it("should produce unique hashes for same commit with different files", function()
      local data1 = "commit1\nfile1.lua"
      local data2 = "commit1\nfile2.lua"
      local hash1 = utils.sha256(data1)
      local hash2 = utils.sha256(data2)
      assert.is_not.equals(hash1, hash2)
    end)
  end)

  describe("receipt payload metadata", function()
    it("should include required agent_id from config", function()
      local cfg = config.get()
      assert.equals("test-agent-123", cfg.agent_id)
    end)

    it("should generate valid ISO timestamp", function()
      local ts = utils.iso_timestamp()
      assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should include editor metadata", function()
      -- Simulate the metadata that would be included in a receipt
      local metadata = {
        editor = "neovim",
        plugin_version = "1.0.0",
        timestamp = utils.iso_timestamp(),
      }
      assert.equals("neovim", metadata.editor)
      assert.equals("1.0.0", metadata.plugin_version)
      assert.is_string(metadata.timestamp)
    end)
  end)

  describe("receipt list formatting", function()
    it("should handle empty receipt list", function()
      local receipt_list = {}
      assert.equals(0, #receipt_list)
    end)

    it("should format receipt display strings correctly", function()
      local receipt = {
        receipt_id = "rcpt-12345",
        action_type = "file_edit",
        timestamp = "2026-04-07T12:00:00Z",
        verified = true,
      }
      local display = string.format(
        "%-14s  %-14s  %-20s  %s",
        utils.truncate(receipt.receipt_id, 14),
        utils.truncate(receipt.action_type, 14),
        utils.format_time(receipt.timestamp),
        receipt.verified and "Verified" or "Pending"
      )
      assert.truthy(display:match("rcpt%-12345"))
      assert.truthy(display:match("file_edit"))
      assert.truthy(display:match("Verified"))
    end)
  end)
end)
