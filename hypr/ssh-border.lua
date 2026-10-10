-- Border colour for the ssh sessions the Fleetwatch popup opens (window class
-- org.omarchy.ssh), taken from the current Omarchy theme.
--
-- Load it at the end of ~/.config/hypr/hyprland.lua:
--
--   pcall(dofile, os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.frestina.fleetwatch/hypr/ssh-border.lua")
--
-- Omarchy reloads Hyprland on every theme switch, so this runs again and picks
-- again. Of the theme's colours it takes the one that looks most different from
-- the theme's own window border while staying clear on its background. Red is
-- left out so the border never reads as an error. With pcall, the line does
-- nothing once the plugin is removed.

local M = {}

local CANDIDATES = { "yellow", "magenta", "cyan", "green", "orange", "blue" }
-- When colors.toml is missing or unreadable: amber.
local FALLBACK = "e5c07b"
-- Themes from before the semantic palette only name ANSI colours.
local ANSI = { yellow = "color3", magenta = "color5", cyan = "color6", green = "color2", blue = "color4", background = "color0" }

local function read_colors(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local colors = {}
  for line in file:lines() do
    local key, value = line:match('^%s*([%w_]+)%s*=%s*["\']([^"\']*)["\']')
    if key then colors[key] = value end
  end
  file:close()
  return colors
end

-- "#rrggbb", "rgb(rrggbb)", "rgba(rrggbbaa)" or a gradient: the first colour's
-- six hex digits, or nil.
local function hex_of(value)
  if not value then return nil end
  return value:match("#(%x%x%x%x%x%x)") or value:match("rgba?%((%x%x%x%x%x%x)")
end

local function linear(u)
  return u <= 0.04045 and u / 12.92 or ((u + 0.055) / 1.055) ^ 2.4
end

-- OKLab, where distance follows how different two colours look.
local function oklab(hex)
  local r = linear(tonumber(hex:sub(1, 2), 16) / 255)
  local g = linear(tonumber(hex:sub(3, 4), 16) / 255)
  local b = linear(tonumber(hex:sub(5, 6), 16) / 255)
  local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
  local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
  local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
  return {
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  }
end

local function distance(a, b)
  local p, q = oklab(a), oklab(b)
  return math.sqrt((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 + (p[3] - q[3]) ^ 2)
end

local function color(colors, name)
  return hex_of(colors[name]) or hex_of(colors[ANSI[name] or ""])
end

-- The six hex digits to use for a theme's colors.toml contents.
function M.pick(colors)
  if not colors then return FALLBACK end
  -- The same choice Omarchy's hyprland.lua template makes for the border.
  local border = hex_of(colors.hyprland_active_border) or color(colors, "accent")
  local background = color(colors, "background")
  if not border or not background then return FALLBACK end
  local best, best_score = nil, nil
  for i, name in ipairs(CANDIDATES) do
    local hex = color(colors, name)
    if hex then
      -- Far from the border, still visible on the background; ties go to the
      -- earlier candidate.
      local score = math.min(distance(hex, border), 1.5 * distance(hex, background)) - 0.01 * i
      if not best_score or score > best_score then best, best_score = hex, score end
    end
  end
  return best or FALLBACK
end

function M.colors_path()
  return os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml"
end

function M.border_color(colors)
  local hex = M.pick(colors)
  -- Active, then inactive: the same colour, see-through.
  return "rgb(" .. hex .. ") rgba(" .. hex .. "88)"
end

-- Inside Hyprland, apply the rule; elsewhere (tests) only hand back M.
if o and o.window then
  o.window("^org\\.omarchy\\.ssh$", { border_color = M.border_color(read_colors(M.colors_path())) })
end

M.read_colors = read_colors
return M
