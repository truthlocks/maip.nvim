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

--- Tests for maip.config module.
local config = require("maip.config")

describe("maip.config", function()
  -- Reset state before each test
  before_each(function()
    config.options = {}
    config._initialized = false
  end)

  describe("defaults", function()
    it("should have a valid api_url default", function()
      assert.is_string(config.defaults.api_url)
      assert.truthy(config.defaults.api_url:match("^https://"))
    end)

    it("should have empty string defaults for credentials", function()
      assert.equals("", config.defaults.api_key)
      assert.equals("", config.defaults.tenant_id)
      assert.equals("", config.defaults.agent_id)
    end)

    it("should have boolean defaults for feature flags", function()
      assert.is_true(config.defaults.auto_receipt_on_commit)
      assert.is_true(config.defaults.show_trust_virtual_text)
      assert.is_true(config.defaults.telescope)
    end)

    it("should have numeric defaults for timeouts and intervals", function()
      assert.equals(60, config.defaults.trust_refresh_interval)
      assert.equals(30, config.defaults.request_timeout)
      assert.equals(3, config.defaults.max_retries)
      assert.equals(1, config.defaults.retry_delay)
    end)

    it("should have keymap defaults", function()
      assert.is_table(config.defaults.keymaps)
      assert.equals("<leader>mc", config.defaults.keymaps.create_receipt)
      assert.equals("<leader>mv", config.defaults.keymaps.verify_receipt)
      assert.equals("<leader>ml", config.defaults.keymaps.list_receipts)
      assert.equals("<leader>mt", config.defaults.keymaps.show_trust)
      assert.equals("<leader>mr", config.defaults.keymaps.register_agent)
      assert.equals("<leader>md", config.defaults.keymaps.dashboard)
    end)

    it("should have sign configuration for all trust levels", function()
      assert.is_table(config.defaults.signs)
      assert.is_table(config.defaults.signs.high_trust)
      assert.is_table(config.defaults.signs.medium_trust)
      assert.is_table(config.defaults.signs.low_trust)
      assert.is_string(config.defaults.signs.high_trust.text)
      assert.is_string(config.defaults.signs.high_trust.hl)
    end)

    it("should have trust threshold defaults", function()
      assert.is_table(config.defaults.trust_thresholds)
      assert.equals(0.8, config.defaults.trust_thresholds.high)
      assert.equals(0.5, config.defaults.trust_thresholds.medium)
    end)
  end)

  describe("setup()", function()
    it("should initialize with defaults when no opts provided", function()
      local result = config.setup()
      assert.is_table(result)
      assert.equals(config.defaults.api_url, result.api_url)
      assert.is_true(config._initialized)
    end)

    it("should merge user options with defaults", function()
      config.setup({
        api_key = "my-key",
        tenant_id = "my-tenant",
      })
      assert.equals("my-key", config.options.api_key)
      assert.equals("my-tenant", config.options.tenant_id)
      -- Other defaults should remain
      assert.equals(config.defaults.api_url, config.options.api_url)
    end)

    it("should deep merge nested tables", function()
      config.setup({
        keymaps = {
          create_receipt = "<leader>xc",
        },
      })
      -- Overridden keymap
      assert.equals("<leader>xc", config.options.keymaps.create_receipt)
      -- Other keymaps should retain defaults
      assert.equals("<leader>mv", config.options.keymaps.verify_receipt)
    end)

    it("should fall back to env vars for empty credentials", function()
      -- Set env vars
      local original_key = vim.env.MAIP_API_KEY
      local original_tenant = vim.env.MAIP_TENANT_ID
      local original_agent = vim.env.MAIP_AGENT_ID

      vim.env.MAIP_API_KEY = "env-api-key"
      vim.env.MAIP_TENANT_ID = "env-tenant-id"
      vim.env.MAIP_AGENT_ID = "env-agent-id"

      config.setup()

      assert.equals("env-api-key", config.options.api_key)
      assert.equals("env-tenant-id", config.options.tenant_id)
      assert.equals("env-agent-id", config.options.agent_id)

      -- Restore original env
      vim.env.MAIP_API_KEY = original_key
      vim.env.MAIP_TENANT_ID = original_tenant
      vim.env.MAIP_AGENT_ID = original_agent
    end)

    it("should prefer explicit opts over env vars", function()
      local original_key = vim.env.MAIP_API_KEY
      vim.env.MAIP_API_KEY = "env-key"

      config.setup({ api_key = "explicit-key" })
      assert.equals("explicit-key", config.options.api_key)

      vim.env.MAIP_API_KEY = original_key
    end)

    it("should set _initialized to true", function()
      assert.is_false(config._initialized)
      config.setup()
      assert.is_true(config._initialized)
    end)
  end)

  describe("get()", function()
    it("should return options after setup", function()
      config.setup({ api_key = "test" })
      local result = config.get()
      assert.equals("test", result.api_key)
    end)

    it("should error if setup has not been called", function()
      assert.has_error(function()
        config.get()
      end)
    end)
  end)

  describe("is_initialized()", function()
    it("should return false before setup", function()
      assert.is_false(config.is_initialized())
    end)

    it("should return true after setup", function()
      config.setup()
      assert.is_true(config.is_initialized())
    end)
  end)

  describe("validate()", function()
    it("should fail when api_key is empty", function()
      config.setup({ api_key = "", tenant_id = "tenant" })
      local ok, err = config.validate()
      assert.is_false(ok)
      assert.truthy(err:match("api_key"))
    end)

    it("should fail when tenant_id is empty", function()
      config.setup({ api_key = "key", tenant_id = "" })
      -- Unset env var for this test
      local original = vim.env.MAIP_TENANT_ID
      vim.env.MAIP_TENANT_ID = nil
      config.setup({ api_key = "key", tenant_id = "" })
      local ok, err = config.validate()
      assert.is_false(ok)
      assert.truthy(err:match("tenant_id"))
      vim.env.MAIP_TENANT_ID = original
    end)

    it("should pass when both api_key and tenant_id are set", function()
      config.setup({ api_key = "key", tenant_id = "tenant" })
      local ok, err = config.validate()
      assert.is_true(ok)
      assert.is_nil(err)
    end)
  end)
end)
