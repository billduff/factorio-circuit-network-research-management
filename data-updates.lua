for _, tech in pairs(data.raw.technology) do
  local localised_name = nil
  if tech.name:find("-%d+$") then
    local localised_generic_name = { "technology-name." .. tech.name:gsub("-%d+$", "") }
    if tech.max_level == "infinite" then
      localised_name = localised_generic_name
    else
      local i, j = tech.name:find("-%d+$")
      local level = tech.name:sub(i+1, j)
      localised_name = { "", localised_generic_name, " ", level }
    end
  else
    localised_name = { "technology-name." .. tech.name }
  end

  local icons = nil
  if tech.icons then
    icons = { tech.icons[1] }
    for i, icon in ipairs(tech.icons) do
      new_icon = table.deepcopy(icon)
      new_icon.scale = 0.5
      icons[i] = new_icon
    end
  end

  local tech_signal = {
    -- PrototypeBase
    type = "virtual-signal",
    name = tech.name,
    localised_name = localised_name,
    subgroup = "technology",
    -- VirtualSignalPrototype
    icons = icons,
    icon = tech.icon,
    icon_size = tech.icon_size,
    icon_mipmaps = tech.icon_mipmaps
  }

  data:extend{tech_signal}
end
