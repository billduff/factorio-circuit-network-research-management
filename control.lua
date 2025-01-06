local debug = false

function debug_print(string)
  if debug then
    game.print(string, { skip = defines.print_skip.never })
  end
end

local function create_gui(player)
  local window = player.gui.relative.add{
    type = "frame",
    name = "research-admin-building-circuit-settings-window",
    caption = "Circuit connection",
    direction = "vertical",
    anchor = {
      gui = defines.relative_gui_type.constant_combinator_gui,
      position = defines.relative_gui_position.right
    }
  }

  local set_research = window.add{
    type = "flow",
    name = "set-research",
    direction = "horizontal"
  }

  set_research.add{
    type = "checkbox",
    name = "set-research-checkbox",
    state = false
  }

  set_research.add{
    type = "label",
    name = "set-research-label",
    caption = "Set research",
  }

  window.add{
    type = "line",
    name = "line1",
  }

  local read_research = window.add{
    type = "flow",
    name = "read-research",
    direction = "horizontal"
  }

  read_research.add{
    type = "checkbox",
    name = "read-research-checkbox",
    state = false
  }

  read_research.add{
    type = "label",
    name = "read-research-label",
    caption = "Read current research"
  }

  window.add{
    type = "line",
    name = "line2",
  }

  local output_cost = window.add{
    type = "flow",
    name = "output-cost",
    direction = "horizontal"
  }

  output_cost.add{
    type = "checkbox",
    name = "output-cost-checkbox",
    state = false
  }

  output_cost.add{
    type = "label",
    name = "output-cost-label",
    caption = "Output cost"
  }

  window.add{
    type = "choose-elem-button",
    name = "output-cost-tech-choice",
    elem_type = "technology"
  }
end

local function setup_gui(player, window, unit_number, state_tags, type)
  local gui_tags = { research_admin_building_unit_number = unit_number, type = type }
  local set_research_checkbox = window["set-research"]["set-research-checkbox"]
  set_research_checkbox.state = state_tags.set_research_checked
  set_research_checkbox.tags = gui_tags

  local read_research_checkbox = window["read-research"]["read-research-checkbox"]
  read_research_checkbox.state = state_tags.read_research_checked
  read_research_checkbox.tags = gui_tags

  local output_cost_checkbox = window["output-cost"]["output-cost-checkbox"]
  output_cost_checkbox.state = state_tags.output_cost_checked
  output_cost_checkbox.tags = gui_tags

  local output_cost_tech_choice = window["output-cost-tech-choice"]
  output_cost_tech_choice.elem_value = state_tags.output_cost_chosen_tech
  output_cost_tech_choice.tags = gui_tags
end

local function tech_signals_of_network(network)
  if network == nil or network.signals == nil then
    return {}
  else
    local tech_signals = {}
    for _, signal in ipairs(network.signals) do
      if signal.signal.type == "virtual" and prototypes.virtual_signal[signal.signal.name].subgroup.name == "technology" then
        tech_signals[signal.signal.name] = signal.count
      end
    end
    return tech_signals
  end
end

local function add_dicts(dicts)
  local res = {}
  for _, dict in ipairs(dicts) do
    for key, value in pairs(dict) do
      if res[key] == nil then
        res[key] = value
      else
        res[key] = res[key] + value
      end
    end
  end
  return res
end

local function update_signals(research_admin_building)
  local entity = research_admin_building.entity
  local force = entity.force

  local tech_signals = nil
  if research_admin_building.tags.set_research_checked then
    local red_network = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local green_network = entity.get_circuit_network(defines.wire_connector_id.circuit_green)
    tech_signals = add_dicts{tech_signals_of_network(red_network),tech_signals_of_network(green_network)}
  end

  local new_filters = {}

  if research_admin_building.tags.read_research_checked then
    local tech = force.current_research
    if tech ~= nil then
      local progress = force.research_progress
      local progress_int = math.ceil(progress * 100)
      if progress_int == 0 then
        progress_int = 1
      end
      new_filters[#new_filters+1] = { value = tech.name; min = progress_int }
    end
  end

  if research_admin_building.tags.output_cost_checked then
    local tech_name = research_admin_building.tags.output_cost_chosen_tech
    if tech_name ~= nil then
      local tech = force.technologies[tech_name]
      local count = tech.research_unit_count
      for _, item in ipairs(tech.research_unit_ingredients) do
        new_filters[#new_filters+1] = {
          value = { type = item.type, name = item.name, quality = "normal", comparator = "=" },
          min = item.amount * count
        }
      end
    end
  end

  -- CR wduff: Figure out how to prevent the user from editing this stuff, then initialize it once
  -- when the building is placed instead of setting it every time.
  local control_behavior = entity.get_control_behavior()
  control_behavior.enabled = true
  if control_behavior.sections_count == 0 then
    control_behavior.add_section()
  else
    while control_behavior.sections_count > 1 do
      control_behavior.remove_section(control_behavior.sections_count)
    end
  end
  local logistic_section = control_behavior.get_section(1)
  logistic_section.active = true
  logistic_section.filters = new_filters

  return force, tech_signals
end

-- CR wduff: This comment is no longer accurate.
-- We read and write circuit network state once every ~half second, as well as any time something
-- happens to the research queue, and just after any updates to a research admin building. This way
-- it feels snappy around interesting events, and isn't too slow around circuit network updates,
-- without doing work on every tick.
local function update_signals_all()
  local all_tech_signals = {}

  for _, research_admin_building in pairs(storage.research_admin_buildings) do
    -- CR wduff: Why do I need this validity check?
    if research_admin_building.entity.valid then
      local force, tech_signals = update_signals(research_admin_building)
      if tech_signals then
        tech_signals_for_force = all_tech_signals[force.name]
        if tech_signals_for_force then
          tech_signals_for_force.signals = add_dicts{tech_signals_for_force.signals, tech_signals}
        else
          all_tech_signals[force.name] = { force = force, signals = tech_signals }
        end
      end
    end
  end

  for _, tech_signals_for_force in pairs(all_tech_signals) do
    local force = tech_signals_for_force.force
    local tech_signals = tech_signals_for_force.signals
    local tech_signals_array = {}
    for name, count in pairs(tech_signals) do
      tech_signals_array[#tech_signals_array+1] = { name = name, count = count }
    end
    table.sort(
      tech_signals_array,
      function(s1, s2)
        if s1.count == s2.count then
          return s1.name < s2.name
        else
          return s1.count > s2.count
        end
      end)

    local any_changes = false
    local new_queue = {}
    for i, signal in ipairs(tech_signals_array) do
      if not force.research_queue[i] or force.research_queue[i].name ~= signal.name then
        any_changes = true
      end
      new_queue[#new_queue+1] = signal.name
    end

    if any_changes or #force.research_queue > #new_queue then
      debug_print("setting research queue")
      debug_print(serpent.block(new_queue))
      force.research_queue = new_queue
    end
  end
end

local function add_research_admin_building(entity, tags)
  debug_print("add_research_admin_building")
  debug_print(entity.unit_number)
  debug_print(entity.name)
  if not tags then
    tags = {
      set_research_checked = false,
      read_research_checked = false,
      output_cost_checked = false,
      output_cost_chosen_tech = nil
    }
  end
  storage.research_admin_buildings[entity.unit_number] = {
    tags = tags or initial_state_tags,
    entity = entity
  }
end

local function add_research_admin_building_ghost(entity)
  debug_print("add_research_admin_building_ghost")
  debug_print(entity.unit_number)
  debug_print(entity.name)
  storage.research_admin_building_ghosts[entity.unit_number] = entity
  if not entity.tags then
    entity.tags = {
      set_research_checked = false,
      read_research_checked = false,
      output_cost_checked = false,
      output_cost_chosen_tech = nil
    }
  end
end

local function copy_research_admin_building(source_unit_number, destination_unit_number)
  storage.research_admin_buildings[destination_unit_number].tags =
    storage.research_admin_buildings[source_unit_number].tags
end

local entity_event_filters = {
  { filter = "name", name = "research-admin-building" },
  { filter = "ghost_name", name = "research-admin-building" }
}


local function is_research_admin_building_or_ghost(entity)
  return
    entity.name == "research-admin-building"
    or (entity.name == "entity-ghost" and entity.ghost_name == "research-admin-building")
end

local function on_entity_built(event)
  debug_print(serpent.block{ event_id = event.name, tags = event.tags })
  local entity = event.entity
  debug_print(serpent.block{ tags = event.tags })
  if entity.name == "entity-ghost" then
    add_research_admin_building_ghost(entity)
  else
    add_research_admin_building(entity, event.tags)
  end
end

local function on_entity_removed(entity)
  if entity.name == "entity-ghost" then
    storage.research_admin_building_ghosts[entity.unit_number] = nil
  else
    storage.research_admin_buildings[entity.unit_number] = nil
  end
end

script.on_init(function()
  storage.research_admin_buildings = {}
  storage.research_admin_building_ghosts = {}
  for _, player in pairs(game.players) do
    if player.gui.relative["research-admin-building-circuit-settings-window"] == nil then
      create_gui(player)
    end
  end
end)

script.on_configuration_changed(function(changes)
  this_mod_change = changes.mod_changes["circuit-network-research-management"]
  if this_mod_change.old_version == "0.0.2" then
    local research_admin_buildings = {}
    for unit_number, research_admin_building in pairs(storage.research_admin_buildings) do
      research_admin_buildings[unit_number] = {
        tags = {
          set_research_checked = research_admin_building.set_research_checked,
          read_research_checked = research_admin_building.read_research_checked,
          output_cost_checked = research_admin_building.output_cost_checked,
          output_cost_chosen_tech = research_admin_building.output_cost_chosen_tech,
         },
         entity = research_admin_building.entity
      }
    end
    storage.research_admin_buildings = research_admin_buildings
    storage.research_admin_building_ghosts = {}
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  create_gui(game.get_player(event.player_index))
end)

-- We don't currently need to do anything for [on_player_removed] because the only per-player state
-- we have is a gui, which attached to player.gui, which should get cleaned up by the game.

script.on_event(defines.events.on_built_entity, on_entity_built, entity_event_filters)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, entity_event_filters)
script.on_event(defines.events.on_space_platform_built_entity, on_entity_built, entity_event_filters)
-- CR wduff: What, if anything, should we actually do with this event?
script.on_event(defines.events.script_raised_revive, on_entity_built, entity_event_filters)

script.on_event(defines.events.on_player_mined_entity, function(event)
  debug_print("on_player_mined_entity")
  on_entity_removed(event.entity)
end,
entity_event_filters)

script.on_event(defines.events.on_robot_mined_entity, function(event)
  debug_print("on_robot_mined_entity")
  on_entity_removed(event.entity)
end,
entity_event_filters)

script.on_event(defines.events.on_space_platform_mined_entity, function(event)
  debug_print("on_space_platform_mined_entity")
  on_entity_removed(event.entity)
end,
entity_event_filters)

script.on_event(defines.events.on_pre_ghost_deconstructed, function(event)
  debug_print("on_pre_ghost_deconstructed")
  on_entity_removed(event.ghost)
end,
entity_event_filters)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  local source = event.source
  local destination = event.destination
  debug_print(serpent.block({
    source = { name = source.name, unit_number = source.unit_number },
    destination = { name = destination.name, unit_number = destination.unit_number }
  }))
  if is_research_admin_building_or_ghost(source) and is_research_admin_building_or_ghost(destination) then
    copy_research_admin_building(source.unit_number, destination.unit_number)
  end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  debug_print("on_player_setup_blueprint")
  local stack = event.stack
  if stack and stack.is_blueprint_setup() then
    for i, entity in pairs(event.mapping.get()) do
      if is_research_admin_building_or_ghost(entity) then
        if entity.name == "entity-ghost" then
          stack.set_blueprint_entity_tags(i, entity.tags)
        else
          local research_admin_building = storage.research_admin_buildings[entity.unit_number]
          stack.set_blueprint_entity_tags(i, research_admin_building.tags)
        end
      end
    end
  end
end)

-- CR wduff: Consider cloning the gui before extending it, so we don't have to toggle visibility
-- every time, and so we can make the logistics section read only.
script.on_event(defines.events.on_gui_opened, function(event)
  local player = game.get_player(event.player_index)
  if event.gui_type == defines.gui_type.entity
     and (event.entity.type == "constant-combinator"
          or (event.entity.name == "entity-ghost" and event.entity.ghost_type == "constant-combinator"))
  then
    local window = player.gui.relative["research-admin-building-circuit-settings-window"]
    local entity = event.entity
    debug_print(serpent.block{ on_gui_opened = entity.name })
    if is_research_admin_building_or_ghost(entity) then
      local unit_number = entity.unit_number
      if entity.name == "entity-ghost" then
        setup_gui(player, window, unit_number, storage.research_admin_building_ghosts[unit_number].tags, "ghost")
      else
        setup_gui(player, window, unit_number, storage.research_admin_buildings[unit_number].tags, "normal")
      end
      window.visible = true
    else
      window.visible = false
    end
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  local name = element.name

  if name == "set-research-checkbox" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type
    if type == "ghost" then
      local tags = storage.research_admin_building_ghosts[unit_number].tags
      tags.set_research_checked = element.state
      storage.research_admin_building_ghosts[unit_number].tags = tags
    else
      storage.research_admin_buildings[unit_number].tags.set_research_checked = element.state
    end
  end

  if name == "read-research-checkbox" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type
    if type == "ghost" then
      local tags = storage.research_admin_building_ghosts[unit_number].tags
      tags.read_research_checked = element.state
      storage.research_admin_building_ghosts[unit_number].tags = tags
    else
      storage.research_admin_buildings[unit_number].tags.read_research_checked = element.state
    end
  end

  if name == "output-cost-checkbox" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type
    if type == "ghost" then
      local tags = storage.research_admin_building_ghosts[unit_number].tags
      tags.output_cost_checked = element.state
      storage.research_admin_building_ghosts[unit_number].tags = tags
    else
      storage.research_admin_buildings[unit_number].tags.output_cost_checked = element.state
    end
  end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element

  if element.name == "output-cost-tech-choice" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type
    if type == "ghost" then
      local tags = storage.research_admin_building_ghosts[unit_number].tags
      tags.output_cost_chosen_tech = element.elem_value
      storage.research_admin_building_ghosts[unit_number].tags = tags
    else
      storage.research_admin_buildings[unit_number].tags.output_cost_chosen_tech = element.elem_value
    end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick % 32 == 0 then
    update_signals_all()
  end
end)
