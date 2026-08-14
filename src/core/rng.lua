local bit = require("bit")

local UINT32_MOD = 4294967296
local UINT32_MAX = UINT32_MOD - 1

local M = {}
local Stream = {}
Stream.__index = Stream

local function uint32(value)
  value = value % UINT32_MOD
  if value < 0 then value = value + UINT32_MOD end
  return value
end

local function hash_text(initial, text)
  local value = initial
  for index = 1, #text do
    value = uint32(value * 33 + text:byte(index))
  end
  return value
end

local function encoded_part(value)
  local kind = type(value)
  local rendered
  if kind == "number" then
    rendered = string.format("%.17g", value)
  elseif kind == "boolean" then
    rendered = value and "true" or "false"
  elseif value == nil then
    rendered = "nil"
  else
    rendered = tostring(value)
  end
  return kind .. ":" .. #rendered .. ":" .. rendered .. ";"
end

local function normalize_parts(first, ...)
  if type(first) == "table" and select("#", ...) == 0 then return first end
  return { first, ... }
end

function M.seed(first, ...)
  local parts = normalize_parts(first, ...)
  local hi = 2166136261
  local lo = 2246822519
  for index, value in ipairs(parts) do
    local encoded = encoded_part(value)
    hi = hash_text(uint32(hi + index * 97), encoded)
    lo = hash_text(uint32(lo + index * 193), encoded)
  end
  if hi == 0 and lo == 0 then lo = 1 end
  return { hi = hi, lo = lo }
end

function M.from_u32(value)
  return setmetatable({ state = uint32(value or 0) }, Stream)
end

function M.stream(root, ...)
  root = root or { hi = 0, lo = 0 }
  local parts = { root.hi or 0, root.lo or 0, ... }
  local derived = M.seed(parts)
  local state = uint32(bit.bxor(derived.hi, derived.lo))
  return M.from_u32(state)
end

function Stream:next_u32()
  self.state = uint32(self.state * 1664525 + 1013904223)
  return self.state
end

function Stream:float()
  return self:next_u32() / UINT32_MOD
end

function Stream:integer(minimum, maximum)
  if type(minimum) ~= "number" or type(maximum) ~= "number"
      or minimum % 1 ~= 0 or maximum % 1 ~= 0 or minimum > maximum then
    return nil, "integer bounds must be whole numbers with minimum <= maximum"
  end
  local span = maximum - minimum + 1
  return minimum + math.floor(self:float() * span)
end

function Stream:choice(rows)
  if type(rows) ~= "table" or #rows == 0 then
    return nil, "choice needs at least one row"
  end
  return rows[self:integer(1, #rows)]
end

M.UINT32_MAX = UINT32_MAX

return M
