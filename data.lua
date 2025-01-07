-- CR wduff: Set debug false.
local debug = true

local tech_item_group = {
  -- PrototypeBase
  type = "item-group",
  name = "technology",
  order = "zzzzz[technology]",
  -- ItemGroup
  icon = data.raw["utility-sprites"].default.technology_white.filename
}

local tech_item_subgroup = {
  -- PrototypeBase
  type = "item-subgroup",
  name = "technology",
  -- ItemSubGroup
  group = "technology"
}

local research_admin_building_tint = { r = 1, g = 0.2, b = 0.07, a = 1 }

local research_admin_building_icons = {
  { icon = data.raw["lab"]["lab"].icon,
    icon_size =  data.raw["lab"]["lab"].icon_size,
    tint = research_admin_building_tint
  }
}

local research_admin_building = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
research_admin_building.name = "research-admin-building"
research_admin_building.icons = research_admin_building_icons
research_admin_building.minable = { mining_time = 0.2, results = { { type = "item", name = "research-admin-building", amount = 1 } } }
local research_admin_building_sprite_layers = {}
for i, layer in pairs(data.raw["lab"]["lab"].off_animation.layers) do
  new_layer = table.deepcopy(layer)
  new_layer.tint = research_admin_building_tint
  new_layer.scale = 0.5/3
  research_admin_building_sprite_layers[i] = new_layer
end
local research_admin_building_sprite = { layers = research_admin_building_sprite_layers }
research_admin_building.sprites = {
  north = research_admin_building_sprite,
  east = research_admin_building_sprite,
  south = research_admin_building_sprite,
  west = research_admin_building_sprite
}

local research_admin_building_item = {
  -- PrototypeBase
  type = "item",
  name = "research-admin-building",
  order = "z[zz-research-admin-building]",
  subgroup = "production-machine",
  -- ItemPrototype
  stack_size = 10,
  weight = 100000,
  icons = research_admin_building_icons,
  place_result = "research-admin-building",
  flags = {
    "primary-place-result"
  }
}

local research_admin_building_enabled = false
local research_admin_building_energy = 5

local research_admin_building_ingredients = {
  { type = "item", name = "processing-unit", amount = 10 },
  { type = "item", name = "selector-combinator", amount = 10 },
  { type = "item", name = "lab", amount = 10 },
}

if debug then
  research_admin_building_enabled = true
  research_admin_building_energy = 0.1
  research_admin_building_ingredients = {}
end

local research_admin_building_recipe = {
  -- PrototypeBase
  type = "recipe",
  name = "research-admin-building",
  -- RecipePrototype
  enabled = research_admin_building_enabled,
  energy_required = research_admin_building_energy,
  ingredients = research_admin_building_ingredients,
  results = {
    { type = "item", name = "research-admin-building", amount = 1 }
  }
}

local research_admin_building_technology = {
  -- PrototypeBase
  type = "technology",
  name = "research-admin-building",
  --
  icons = research_admin_building_icons,
  unit = { count = 10, time = 60, ingredients = { { "automation-science-pack", 100 }, { "logistic-science-pack", 50 }, { "chemical-science-pack", 10 }, { "space-science-pack", 1 } } },
  prerequisites = { "advanced-combinators", "space-science-pack" },
  effects = {
    { type = "unlock-recipe",
      recipe = "research-admin-building"
    }
  }
}

data:extend{
  tech_item_group,
  tech_item_subgroup,
  research_admin_building,
  research_admin_building_item,
  research_admin_building_recipe,
  research_admin_building_technology
}
