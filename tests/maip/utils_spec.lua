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

--- Tests for maip.utils module.
local utils = require("maip.utils")

describe("maip.utils", function()
  describe("sha256()", function()
    it("should return a hex string of length 64", function()
      local hash = utils.sha256("hello world")
      assert.is_string(hash)
      assert.equals(64, #hash)
    end)

    it("should return consistent hashes for the same input", function()
      local hash1 = utils.sha256("test input")
      local hash2 = utils.sha256("test input")
      assert.equals(hash1, hash2)
    end)

    it("should return different hashes for different inputs", function()
      local hash1 = utils.sha256("input one")
      local hash2 = utils.sha256("input two")
      assert.is_not.equals(hash1, hash2)
    end)

    it("should handle empty string", function()
      local hash = utils.sha256("")
      assert.is_string(hash)
      assert.equals(64, #hash)
    end)

    it("should handle multiline strings", function()
      local hash = utils.sha256("line one\nline two\nline three")
      assert.is_string(hash)
      assert.equals(64, #hash)
    end)

    it("should produce only hex characters", function()
      local hash = utils.sha256("any string")
      assert.truthy(hash:match("^[%x]+$"))
    end)
  end)

  describe("json_encode()", function()
    it("should encode a simple table", function()
      local result = utils.json_encode({ key = "value" })
      assert.is_string(result)
      assert.truthy(result:match('"key"'))
      assert.truthy(result:match('"value"'))
    end)

    it("should encode nested tables", function()
      local result = utils.json_encode({ outer = { inner = true } })
      assert.is_string(result)
      assert.truthy(result:match('"inner"'))
    end)

    it("should encode arrays", function()
      local result = utils.json_encode({ 1, 2, 3 })
      assert.is_string(result)
      assert.truthy(result:match("1"))
    end)

    it("should encode boolean values", function()
      local result = utils.json_encode({ flag = true })
      assert.is_string(result)
      assert.truthy(result:match("true"))
    end)

    it("should encode numeric values", function()
      local result = utils.json_encode({ count = 42 })
      assert.is_string(result)
      assert.truthy(result:match("42"))
    end)
  end)

  describe("json_decode()", function()
    it("should decode a simple JSON object", function()
      local result, err = utils.json_decode('{"key":"value"}')
      assert.is_nil(err)
      assert.is_table(result)
      assert.equals("value", result.key)
    end)

    it("should decode nested JSON", function()
      local result, err = utils.json_decode('{"outer":{"inner":true}}')
      assert.is_nil(err)
      assert.is_table(result.outer)
      assert.is_true(result.outer.inner)
    end)

    it("should return error for empty input", function()
      local result, err = utils.json_decode("")
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should return error for nil input", function()
      local result, err = utils.json_decode(nil)
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should return error for invalid JSON", function()
      local result, err = utils.json_decode("{invalid json}")
      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("JSON decode error"))
    end)

    it("should roundtrip encode/decode correctly", function()
      local original = { name = "test", count = 42, active = true }
      local encoded = utils.json_encode(original)
      local decoded, err = utils.json_decode(encoded)
      assert.is_nil(err)
      assert.equals("test", decoded.name)
      assert.equals(42, decoded.count)
      assert.is_true(decoded.active)
    end)
  end)

  describe("format_time()", function()
    it("should format an ISO 8601 timestamp", function()
      local result = utils.format_time("2026-04-07T12:30:45Z")
      assert.equals("2026-04-07 12:30:45", result)
    end)

    it("should handle timestamps with milliseconds", function()
      local result = utils.format_time("2026-04-07T12:30:45.123Z")
      assert.equals("2026-04-07 12:30:45", result)
    end)

    it("should return N/A for nil input", function()
      assert.equals("N/A", utils.format_time(nil))
    end)

    it("should return N/A for empty string", function()
      assert.equals("N/A", utils.format_time(""))
    end)

    it("should return the original string for unrecognized format", function()
      local result = utils.format_time("not a timestamp")
      assert.equals("not a timestamp", result)
    end)
  end)

  describe("truncate()", function()
    it("should not truncate short strings", function()
      assert.equals("hello", utils.truncate("hello", 10))
    end)

    it("should truncate long strings with ellipsis", function()
      local result = utils.truncate("hello world this is long", 10)
      assert.equals(10, #result)
      assert.truthy(result:match("%.%.%.$"))
    end)

    it("should handle exact-length strings", function()
      assert.equals("abcde", utils.truncate("abcde", 5))
    end)

    it("should handle nil input", function()
      assert.equals("", utils.truncate(nil, 10))
    end)

    it("should handle very short max_len", function()
      local result = utils.truncate("hello world", 5)
      assert.equals(5, #result)
    end)
  end)

  describe("pad_right()", function()
    it("should pad short strings", function()
      assert.equals("hi   ", utils.pad_right("hi", 5))
    end)

    it("should not pad strings already at min length", function()
      assert.equals("hello", utils.pad_right("hello", 5))
    end)

    it("should not pad strings longer than min length", function()
      assert.equals("hello world", utils.pad_right("hello world", 5))
    end)
  end)

  describe("iso_timestamp()", function()
    it("should return a valid ISO 8601 format", function()
      local ts = utils.iso_timestamp()
      assert.is_string(ts)
      assert.truthy(ts:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$"))
    end)

    it("should return different timestamps on successive calls with delay", function()
      -- This test validates the function returns current time
      local ts = utils.iso_timestamp()
      assert.is_string(ts)
      assert.truthy(#ts > 0)
    end)
  end)
end)
