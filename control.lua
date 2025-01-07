-- CR wduff: Set debug false.
local debug = true

local function debug_print(string)
  if debug then
    game.print(string, { skip = defines.print_skip.never })
  end
end

-- CR wduff: Add tooltips.
local function add_checkbox_with_signal_choice(parent, name, caption, default_signal)
  local flow = parent.add{
    type = "flow",
    name = name .. "-flow",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  }

  flow.add{
    type = "checkbox",
    name = name,
    caption = caption,
    state = false,
    enabled = false,
  }

  flow.add{
    type = "choose-elem-button",
    name = name .. "_signal_choice",
    style = "slot_button_in_shallow_frame",
    elem_type = "signal",
    signal = { type = "virtual", name = default_signal },
    enabled = false,
  }

  return flow
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

  local window = window.add{
    type = "frame",
    name = "research-admin-building-circuit-settings-window-inset",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding"
  }

  window.add{
    type = "radiobutton",
    name = "none",
    caption = "None",
    state = true,
  }

  window.add{
    type = "line",
    name = "line1"
  }

  window.add{
    type = "radiobutton",
    name = "set-research",
    caption = "Set research",
    state = false,
  }

  window.add{
    type = "line",
    name = "line2"
  }

  window.add{
    type = "radiobutton",
    name = "read-research",
    caption = "Read current research",
    state = false,
  }

  window.add{
    type = "line",
    name = "line3"
  }

  local choose_elem_flow = window.add{
    type = "flow",
    name = "choose-elem-flow",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  }

  -- CR wduff: This breaks my "traverse the parent" hack...
  choose_elem_flow.add{
    type = "radiobutton",
    name = "output-info",
    caption = "Output technology info for",
    state = false,
  }

  choose_elem_flow.add{
    type = "choose-elem-button",
    name = "output_info_tech_choice",
    style = "slot_button_in_shallow_frame",
    elem_type = "technology"
  }

  window.add{
    type = "label",
    name = "outputs-label",
    caption = "Outputs",
    style = "caption_label"
  }

  add_checkbox_with_signal_choice(window, "output_unit_count", "# of units needed to research", "signal-U")

  window.add{
    type = "checkbox",
    name = "output_unit_ingredients",
    caption = "Unit ingredients",
    state = false,
    enabled = false,
  }

  add_checkbox_with_signal_choice(window, "output_unit_energy", "Seconds per unit", "signal-T")

  add_checkbox_with_signal_choice(window, "output_progress", "Progress (out of 10000)", "signal-P")

  add_checkbox_with_signal_choice(window, "output_researched", "Researched", "signal-R")

  window.add{
    type = "checkbox",
    name = "output_prereqs",
    caption = "Prerequisite technologies",
    state = false,
    enabled = false,
  }

  window.add{
    type = "checkbox",
    name = "output_successors",
    caption = "Successor technologies",
    state = false,
    enabled = false,
  }

  window.add{
    type = "checkbox",
    name = "output_unlocks",
    caption = "Products unlocked",
    state = false,
    enabled = false,
  }
end

local function iter_gui_elt_descendants(gui_elt, func)
  func(gui_elt)
  for _, child in ipairs(gui_elt.children) do
    iter_gui_elt_descendants(child, func)
  end
end

local function setup_gui(window, unit_number, type)
  local state_tags = nil
  if type == "ghost" then
    state_tags = storage.research_admin_building_ghosts[unit_number].tags
  else
    state_tags = storage.research_admin_buildings[unit_number].tags
  end

  local gui_tags = { research_admin_building_unit_number = unit_number, type = type }

  iter_gui_elt_descendants(window, function(gui_elt)
    if gui_elt.type == "radiobutton" then
      if state_tags.mode_of_operation == gui_elt.name then
        gui_elt.state = true
      else
        gui_elt.state = false
      end
      gui_elt.tags = gui_tags
    end

    if gui_elt.type == "checkbox" then
      gui_elt.enabled = state_tags.mode_of_operation == "output-info"
      gui_elt.state = state_tags[gui_elt.name]
      gui_elt.tags = gui_tags
    end

    if gui_elt.type == "choose-elem-button" then
      gui_elt.enabled = state_tags.mode_of_operation == "output-info"
      gui_elt.elem_value = state_tags[gui_elt.name]
      gui_elt.tags = gui_tags
    end
  end)
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
  local state_tags = research_admin_building.tags

  local tech_signals = nil
  if state_tags.mode_of_operation == "set-research" then
    local red_network = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local green_network = entity.get_circuit_network(defines.wire_connector_id.circuit_green)
    tech_signals = add_dicts{tech_signals_of_network(red_network),tech_signals_of_network(green_network)}
  end

  local new_filters = {}

  if state_tags.mode_of_operation == "read-research" then
    local tech = force.current_research
    if tech ~= nil then
      new_filters[#new_filters+1] = { value = tech.name, min = 1 }
    end
  end

  if state_tags.mode_of_operation == "output-info" then
    local tech_name = state_tags.output_info_tech_choice
    if tech_name ~= nil then
      local tech = force.technologies[tech_name]

      if state_tags.output_unit_count and state_tags.output_unit_count_signal_choice then
        local signal = state_tags.output_unit_count_signal_choice
        new_filters[#new_filters+1] = {
          value = { type = signal.type, name = signal.name, quality = signal.quality or "normal" },
          min = tech.research_unit_count
        }
      end

      if state_tags.output_unit_ingredients then
        for _, item in ipairs(tech.research_unit_ingredients) do
          new_filters[#new_filters+1] = {
            value = { type = item.type, name = item.name, quality = "normal", comparator = "=" },
            min = item.amount
          }
        end
      end

      if state_tags.output_unit_energy and state_tags.output_unit_energy_signal_choice then
        local signal = state_tags.output_unit_energy_signal_choice
        new_filters[#new_filters+1] = {
          value = { type = signal.type, name = signal.name, quality = signal.quality or "normal" },
          min = math.floor(tech.research_unit_energy)
        }
      end

      if state_tags.output_progress and state_tags.output_progress_signal_choice then
        local signal = state_tags.output_progress_signal_choice
        new_filters[#new_filters+1] = {
          value = { type = signal.type, name = signal.name, quality = signal.quality or "normal" },
          min = math.floor(tech.saved_progress * 10000)
        }
      end

      if state_tags.output_researched and state_tags.output_researched_signal_choice then
        local signal = state_tags.output_researched_signal_choice

        -- CR wduff: Update this to include the level.
        local researched = 0
        if tech.researched then
          researched = 1
        end

        -- A zero signal has the same circuit-network effect as no signal but we create it anyway
        -- because it makes it easier for the use to see that it's working.
        new_filters[#new_filters+1] = {
          value = { type = signal.type, name = signal.name, quality = signal.quality or "normal" },
          min = researched
        }
      end

      if state_tags.output_prereqs then
        for tech_name, _ in pairs(tech.prerequisites) do
          new_filters[#new_filters+1] = { value = tech_name, min = 1 }
        end
      end

      if state_tags.output_successors then
        for tech_name, _ in pairs(tech.successors) do
          new_filters[#new_filters+1] = { value = tech_name, min = 1 }
        end
      end

      if state_tags.output_unlocks then
        for _, effect in ipairs(tech.prototype.effects) do
          if effect.type == "unlock-recipe" then
            local recipe = prototypes.recipe[effect.recipe]
            for _, product in ipairs(recipe.products) do
              new_filters[#new_filters+1] = {
                value = { type = product.type, name = product.name, quality = "normal", comparator = "=" },
                min = 1
              }
            end
          end
        end
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

local function initial_state_tags()
  return {
    mode_of_operation = "none",
    output_unit_count = false,
    output_unit_ingredients = false,
    output_unit_energy = false,
    output_progress = false,
    output_researched = false,
    output_prereqs = false,
    output_successors = false,
    output_unlocks = false,
    output_info_tech_choice = nil,
    output_unit_count_signal_choice = { type = "virtual", name = "signal-U" },
    output_unit_energy_signal_choice = { type = "virtual", name = "signal-T" },
    output_progress_signal_choice = { type = "virtual", name = "signal-P" },
    output_researched_signal_choice = { type = "virtual", name = "signal-R" },
  }
end

local function add_research_admin_building(entity, tags)
  debug_print("add_research_admin_building")
  debug_print(entity.unit_number)
  debug_print(entity.name)
  if not tags then
    tags = initial_state_tags()
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
    entity.tags = initial_state_tags()
  end
end

local function copy_research_admin_building(source_unit_number, destination_unit_number)
  -- CR wduff: Need to use different tables for ghosts.
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
        setup_gui(window, unit_number, "ghost")
      else
        setup_gui(window, unit_number, "normal")
      end
      window.visible = true
    else
      window.visible = false
    end
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element

  if element.get_mod() == "circuit-network-research-management" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type

    if element.type == "radiobutton" and element.state then
      local window = game.get_player(event.player_index).gui.relative["research-admin-building-circuit-settings-window"]
      -- CR wduff: Make a shared function for tag update?
      if type == "ghost" then
        local tags = storage.research_admin_building_ghosts[unit_number].tags
        tags.mode_of_operation = element.name
        storage.research_admin_building_ghosts[unit_number].tags = tags
        setup_gui(window, unit_number, "ghost")
      else
        storage.research_admin_buildings[unit_number].tags.mode_of_operation = element.name
        setup_gui(window, unit_number, "normal")
      end
    end

    if element.type == "checkbox" then
      if type == "ghost" then
        local tags = storage.research_admin_building_ghosts[unit_number].tags
        tags[element.name] = element.state
        storage.research_admin_building_ghosts[unit_number].tags = tags
      else
        storage.research_admin_buildings[unit_number].tags[element.name] = element.state
      end
    end
  end
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element

  if element.get_mod() == "circuit-network-research-management" then
    local unit_number = element.tags.research_admin_building_unit_number
    local type = element.tags.type
    if type == "ghost" then
      local tags = storage.research_admin_building_ghosts[unit_number].tags
      tags[element.name] = element.elem_value
      storage.research_admin_building_ghosts[unit_number].tags = tags
    else
      storage.research_admin_buildings[unit_number].tags[element.name] = element.elem_value
    end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  if event.tick % 32 == 0 then
    update_signals_all()
  end
end)
