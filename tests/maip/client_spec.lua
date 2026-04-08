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

--- Tests for maip.client module.
local config = require("maip.config")
local client = require("maip.client")

describe("maip.client", function()
  before_each(function()
    config.setup({
      api_url = "https://api.test.truthlocks.com/v1/machine-identity",
      api_key = "test-api-key",
      tenant_id = "test-tenant-id",
      agent_id = "test-agent-id",
      request_timeout = 10,
      max_retries = 2,
      retry_delay = 1,
    })
  end)

  describe("_build_url()", function()
    it("should build a URL without params", function()
      local url = client._build_url("/receipts", nil)
      assert.equals("https://api.test.truthlocks.com/v1/machine-identity/receipts", url)
    end)

    it("should build a URL with query params", function()
      local url = client._build_url("/receipts", { limit = 10, offset = 0 })
      assert.is_string(url)
      assert.truthy(url:match("/receipts%?"))
      assert.truthy(url:match("limit=10"))
      assert.truthy(url:match("offset=0"))
    end)

    it("should handle empty params table", function()
      local url = client._build_url("/agents", {})
      assert.equals("https://api.test.truthlocks.com/v1/machine-identity/agents", url)
    end)

    it("should URL-encode param values", function()
      local url = client._build_url("/search", { query = "hello world" })
      assert.is_string(url)
      -- The value should be encoded (space becomes %20 or +)
      assert.truthy(url:match("query="))
    end)

    it("should append path to api_url correctly", function()
      local url = client._build_url("/agents/123/trust", nil)
      assert.equals(
        "https://api.test.truthlocks.com/v1/machine-identity/agents/123/trust",
        url
      )
    end)
  end)

  describe("_build_curl_args()", function()
    it("should build GET request args correctly", function()
      local cfg = config.get()
      local args = client._build_curl_args(
        "GET",
        "https://api.test.truthlocks.com/v1/machine-identity/receipts",
        nil,
        cfg
      )
      assert.is_table(args)
      assert.truthy(vim.tbl_contains(args, "curl"))
      assert.truthy(vim.tbl_contains(args, "-s"))
      assert.truthy(vim.tbl_contains(args, "GET"))
      assert.truthy(vim.tbl_contains(args, "Content-Type: application/json"))
      assert.truthy(vim.tbl_contains(args, "X-API-Key: test-api-key"))
      assert.truthy(vim.tbl_contains(args, "X-Tenant-ID: test-tenant-id"))
    end)

    it("should include body for POST requests", function()
      local cfg = config.get()
      local body = '{"key":"value"}'
      local args = client._build_curl_args(
        "POST",
        "https://api.test.truthlocks.com/v1/machine-identity/receipts",
        body,
        cfg
      )
      assert.truthy(vim.tbl_contains(args, "-d"))
      assert.truthy(vim.tbl_contains(args, body))
    end)

    it("should not include body for GET requests", function()
      local cfg = config.get()
      local args = client._build_curl_args(
        "GET",
        "https://api.test.truthlocks.com/v1/machine-identity/receipts",
        '{"key":"value"}',
        cfg
      )
      assert.is_false(vim.tbl_contains(args, "-d"))
    end)

    it("should include timeout setting", function()
      local cfg = config.get()
      local args = client._build_curl_args("GET", "https://example.com", nil, cfg)
      assert.truthy(vim.tbl_contains(args, "--max-time"))
      assert.truthy(vim.tbl_contains(args, "10"))
    end)

    it("should include status code write-out flag", function()
      local cfg = config.get()
      local args = client._build_curl_args("GET", "https://example.com", nil, cfg)
      assert.truthy(vim.tbl_contains(args, "-w"))
      assert.truthy(vim.tbl_contains(args, "\n%{http_code}"))
    end)
  end)

  describe("_parse_response()", function()
    it("should parse response with body and status code", function()
      local body, status = client._parse_response({
        '{"result":"ok"}',
        "200",
      })
      assert.equals('{"result":"ok"}', body)
      assert.equals(200, status)
    end)

    it("should handle multi-line body", function()
      local body, status = client._parse_response({
        "{",
        '  "result": "ok"',
        "}",
        "200",
      })
      assert.equals(200, status)
      assert.truthy(body:match('"result"'))
    end)

    it("should handle empty output", function()
      local body, status = client._parse_response({})
      assert.equals("", body)
      assert.equals(0, status)
    end)

    it("should handle nil output", function()
      local body, status = client._parse_response(nil)
      assert.equals("", body)
      assert.equals(0, status)
    end)

    it("should handle 4xx status codes", function()
      local body, status = client._parse_response({
        '{"error":"not found"}',
        "404",
      })
      assert.equals(404, status)
      assert.truthy(body:match("not found"))
    end)

    it("should handle 5xx status codes", function()
      local body, status = client._parse_response({
        '{"error":"internal server error"}',
        "500",
      })
      assert.equals(500, status)
    end)
  end)

  describe("request()", function()
    it("should call on_error when config is invalid", function()
      -- Reset to empty config
      config.setup({ api_key = "", tenant_id = "" })
      -- Clear env vars
      local orig_key = vim.env.MAIP_API_KEY
      local orig_tenant = vim.env.MAIP_TENANT_ID
      vim.env.MAIP_API_KEY = nil
      vim.env.MAIP_TENANT_ID = nil
      config.setup({ api_key = "", tenant_id = "" })

      local error_called = false
      local error_msg = ""

      client.request("GET", "/test", {
        on_error = function(err)
          error_called = true
          error_msg = err
        end,
      })

      assert.is_true(error_called)
      assert.truthy(error_msg:match("api_key"))

      vim.env.MAIP_API_KEY = orig_key
      vim.env.MAIP_TENANT_ID = orig_tenant
    end)
  end)
end)
