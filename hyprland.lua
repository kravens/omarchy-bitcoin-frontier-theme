-- Bitcoin Frontier theme overrides.
--
-- This file is owned by the theme, so omarchy-theme-set-templates leaves it
-- alone instead of regenerating it from colors.toml -- which is why the border
-- colours are repeated here by hand.

local active_border_color = "#f7931a"
local inactive_border_color = "rgba(595959aa)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },
})

-- Omarchy's default.hypr.windows tags every window "default-opacity" and gives
-- it opacity "0.985 0.96", so even the focused window is slightly transparent.
-- The theme's hyprland.lua is required after that file, so re-stating the rule
-- here wins: active fully opaque, inactive left alone.
o.window({ tag = "default-opacity" }, { opacity = "1.0 0.96" })
