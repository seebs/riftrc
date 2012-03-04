--[[ RiftRC
     A .rc file to run at startup.

]]--

local addoninfo, RiftRC = ...
local slashprint

RiftRC.rc = { buffer = {}, lines = 13, interact = true, point = "TOPLEFT", yoffset = 15 }
RiftRC.out = { buffer = {}, lines = 9, interact = false, point = "BOTTOMLEFT", yoffset = -30 }
RiftRC.list = { buffer = {}, lines = 10, interact = 'fancy', xoffset = -5, yoffset = 15, height = 48, width = 195, point = "TOPRIGHT" }
RiftRC.edit_buffer = nil
RiftRC.edit_orig = nil
RiftRC.unsaved = {}

function RiftRC.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function RiftRC.warn(fmt, ...)
  local out = string.format(fmt or 'nil', ...)
  if RiftRC.rc_feedback and RiftRC.window and RiftRC.window:GetVisible() then
    RiftRC.rc_feedback:SetText(out)
    print(out)
  else
    print(out)
  end
end

-- messages that are only interesting if window is up
function RiftRC.message(fmt, ...)
  if RiftRC.rc_feedback then
    RiftRC.warn(fmt, ...)
  end
end

function RiftRC.shallowcopy(tab)
  local new = {}
  if tab and type(tab) == 'table' then
    for k, v in pairs(tab) do 
      new[k] = v
    end
  end
  return new
end

function RiftRC.variables_loaded(addon)
  if addon == 'RiftRC' then
    RiftRC_dotRiftRC = RiftRC_dotRiftRC or { buffers = {}, }
    RiftRC.sv = RiftRC_dotRiftRC
    for name, value in pairs(RiftRC.sv.buffers) do
      RiftRC.unsaved[name] = RiftRC.shallowcopy(value.data)
    end
    RiftRC.load_buffer('riftrc')
  end
end

function RiftRC.run_buffers()
  local skipped = {}
  if RiftRC.sv and RiftRC.sv.buffers then
    for name, buffer in pairs(RiftRC.sv.buffers) do
      if buffer.autorun then
	local value = RiftRC.run_buffer(string.format('"%s"', name), buffer.data)
	if name == 'riftrc' then
	  RiftRC.output(value)
	end
      else
        table.insert(skipped, name)
      end
    end
    if #skipped > 0 then
      RiftRC.printf("Skipped: ", table.concat(skipped, ', '))
    end
  else
    RiftRC.printf("run_buffers: Didn't find buffers.")
  end
end

function RiftRC.output(value)
  local pretty = {}
  if not slashprint then
    slashprint = Inspect.Addon.Detail('SlashPrint')
    if slashprint then
      slashprint = slashprint.data
    end
  end
  if slashprint then
    slashprint.dump(pretty, value)
    RiftRC.message("Dumped %s into table, %d item%s.", tostring(value), #pretty, #pretty == 1 and 's' or '')
  else
    table.insert(pretty, tostring(value))
  end
  RiftRC.out.buffer = pretty
  RiftRC.check_scrollbar(RiftRC.out)
  RiftRC.show_buffer(RiftRC.out)
end

function RiftRC.run_buffer(name, buffer)
  if not buffer then
    buffer = RiftRC.unsaved[name] or (RiftRC.list.buffer[name] and RiftRC.list.buffer[name].data)
    if not buffer then
      RiftRC.warn("Can't find buffer '%s' to run.", tostring(name))
      return
    end
  end
  local code = table.concat(buffer, "\n")
  func, err = loadstring(code)
  if func then
    local status, value = pcall(func)
    if not status then
      RiftRC.warn("Failed to execute: %s", value)
    else
      return value
    end
  else
    RiftRC.warn("Failed to load code from %s.", name)
  end
end

function RiftRC.run_rc()
  value = RiftRC.run_buffer('edit buffer', RiftRC.rc.buffer)
  RiftRC.output(value)
end

function RiftRC.mousemove(window, x, y)
  if RiftRC.sv then
    RiftRC.sv.window_x = x
    RiftRC.sv.window_y = y
  end
end

function RiftRC.closewindow()
  if RiftRC.window then
    for i, frame in pairs(RiftRC.rc.ui.fields) do
      frame:SetKeyFocus(false)
    end
    RiftRC.window:SetVisible(false)
  end
end

function RiftRC.subUI(window, ui_spec)
  local tab = {}

  local line_height, xoffset, yoffset

  line_height = ui_spec.height or 20
  xoffset = ui_spec.xoffset or 5
  yoffset = ui_spec.yoffset or 0
  tab.background = UI.CreateFrame("Frame", "RiftRC", window)
  tab.background:SetPoint(ui_spec.point, window, ui_spec.point, xoffset, yoffset)
  tab.background:SetHeight(ui_spec.lines * line_height + 10)
  tab.background:SetWidth(ui_spec.width or (window:GetWidth() - 200))
  -- for debugging, set to non-zero alpha
  tab.background:SetBackgroundColor(0.1, 0.1, 0.6, 0)

  local width = tab.background:GetWidth()
  local height = tab.background:GetHeight()

  tab.scrollbar = UI.CreateFrame("RiftScrollbar", "RiftRC", tab.background)
  tab.scrollbar:SetPoint("TOPRIGHT", tab.background, "TOPRIGHT", -2, 5)
  tab.scrollbar:SetHeight(height - 10)
  -- Only active when there is scrolletry to do
  tab.scrollbar:SetEnabled(false)
  tab.scrollbar:SetRange(0, 1)
  tab.scrollbar:SetPosition(0)
  tab.scrollbar.Event.ScrollbarChange = function() RiftRC.show_buffer(ui_spec) end
  tab.background.Event.WheelBack = function() tab.scrollbar:Nudge(3) end
  tab.background.Event.WheelForward = function() tab.scrollbar:Nudge(-3) end
  local w = tab.scrollbar:GetWidth()

  ui_spec.offset = 0

  tab.fields = {}
  tab.labels = {}
  if ui_spec.interact == 'fancy' then
    tab.outer = {}
    tab.borders = {}
    tab.checks = {}
    tab.line_counts = {}
  end
  for i = 1, ui_spec.lines do
    if ui_spec.interact == 'fancy' then
      tab.outer[i] = UI.CreateFrame("Frame", "list" .. i, tab.background)
      tab.outer[i]:SetPoint("TOPLEFT", tab.background, "TOPLEFT", 5, 5 + line_height * (i - 1))
      tab.outer[i]:SetWidth(width - w - 10)
      tab.outer[i]:SetHeight(line_height)
      tab.outer[i]:SetBackgroundColor(0, 0, 0, 0)

      tab.borders[i] = UI.CreateFrame("Frame", "list" .. i, tab.outer[i])
      tab.borders[i]:SetPoint("TOPLEFT", tab.outer[i], "TOPLEFT", 1, 1)
      tab.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
      tab.borders[i]:SetPoint("BOTTOMRIGHT", tab.outer[i], "BOTTOMRIGHT", -1, -1)
      tab.fields[i] = UI.CreateFrame("Frame", "list" .. i, tab.borders[i])
      tab.fields[i]:SetPoint("TOPLEFT", tab.borders[i], "TOPLEFT", 2, 2)
      tab.fields[i]:SetPoint("BOTTOMRIGHT", tab.borders[i], "BOTTOMRIGHT", -2, -2)
      tab.fields[i]:SetBackgroundColor(0.1, 0.1, 0.1, 0.8)
      tab.fields[i].Event.LeftClick = function() RiftRC.select_buffer(i) end

      tab.checks[i] = UI.CreateFrame("RiftCheckbox", "check" .. i, tab.fields[i])
      tab.checks[i]:SetPoint("BOTTOMRIGHT", tab.fields[i], "BOTTOMRIGHT", -2, -2)
      tab.checks[i].Event.CheckboxChange = function() RiftRC.check_box(i) end

      tab.labels[i] = UI.CreateFrame("Text", "RiftRC", tab.fields[i])
      tab.labels[i]:SetPoint("TOPLEFT", tab.fields[i], "TOPLEFT", 2, 2)
      tab.labels[i]:SetFontColor(0.9, 0.9, 0.9, 1)

      tab.line_counts[i] = UI.CreateFrame("Text", "RiftRC", tab.fields[i])
      tab.line_counts[i]:SetPoint("TOPLEFT", tab.fields[i], "TOPLEFT", 2, 22)
      tab.line_counts[i]:SetFontColor(0.9, 0.9, 0.7, 1)
      -- do nothing yet
      -- do nothing yet
    else
      tab.fields[i] = UI.CreateFrame(ui_spec.interact and "RiftTextfield" or "Text", "RiftRC", tab.background)
      tab.fields[i]:SetPoint("TOPLEFT", tab.background, "TOPLEFT", 35, 5 + line_height * (i - 1))
      tab.fields[i]:SetHeight(line_height)
      tab.fields[i]:SetWidth(width - 40 - w)
      tab.fields[i]:SetBackgroundColor(0, 0, 0, 0.8)
      tab.labels[i] = UI.CreateFrame("Text", "RiftRC", tab.background)
      tab.labels[i]:SetPoint("TOPRIGHT", tab.background, "TOPLEFT", 33, 5 + line_height * (i - 1))
      tab.labels[i]:SetFontColor(0.7, 0.7, 0.4, 1)
      if ui_spec.interact then
	tab.fields[i].Event.TextfieldChange = function() RiftRC.change_rc(i) end
	tab.fields[i].Event.KeyDown = function(event, key) RiftRC.key_press(i, event, key) end
      end
    end
  end
  return tab
end

function RiftRC.new_rc()
  local new_name
  for i = 1, 100 do
    new_name = 'untitled ' .. i
    if not RiftRC.list.buffer[new_name] then
      break
    end
  end
  RiftRC.output(nil)
  RiftRC.unsaved[new_name] = {}
  RiftRC.list.buffer[new_name] = { autorun = true, data = {} }
  RiftRC.show_buffer(RiftRC.list)
  RiftRC.load_buffer(new_name)
end

function RiftRC.del_rc()
  local name = RiftRC.edit_orig
  if name == 'riftrc' then
    return
  else
    local best_guess = nil
    --[[
      If the one we picked was #1, we obviously want to go to #2.
      If the one we picked was later, either we want the one after
      it, or we want the one before it if it was the last one.  So,
      we pick the one before it, and continue; if we get another
      one, we use that one and stop looking.

      Note that since you can't delete the riftrc member, in theory
      there should always be at least one other...
      ]]--
    if RiftRC.list.indexed_buffer then
      for index, value in ipairs(RiftRC.list.indexed_buffer) do
	if best_guess then
	  best_guess = value
	  break
	end
        if value == name then
	  if index == 1 then
	    best_guess = RiftRC.list.indexed_buffer[2]
	    break
	  end
	  best_guess = RiftRC.list.indexed_buffer[index - 1]
	end
      end
    end
    RiftRC.sv.trash = RiftRC.sv.trash or {}
    if RiftRC.list.buffer[name] then
      RiftRC.sv.trash[name] = RiftRC.list.buffer[name].data
    end
    RiftRC.list.buffer[name] = nil
    if RiftRC.unsaved[name] then
      RiftRC.sv.trash[name] = RiftRC.unsaved[name]
    end
    RiftRC.unsaved[name] = nil
    RiftRC.show_buffer(RiftRC.list)
    RiftRC.load_buffer(best_guess or 'riftrc')
    RiftRC.warn("Deleted %s. (Stored in RiftRC_dotRiftRC.trash['%s'])", name, name)
  end
end

function RiftRC.makewindow()
  if not RiftRC.ui then
    return nil
  end
  local window = UI.CreateFrame("RiftWindow", "RiftRC", RiftRC.ui)
  if not window then
    return nil
  end
  window:SetWidth(800)
  window:SetHeight(600)
  window:SetTitle('.riftrc')
  window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RiftRC.sv and RiftRC.sv.window_x or 150, RiftRC.sv and RiftRC.sv.window_y or 150)
  Library.LibDraggable.draggify(window, RiftRC.mousemove)

  local l, t, r, b = window:GetTrimDimensions()
  r = r * -1
  b = b * -1

  RiftRC.closebutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.closebutton:SetSkin("close")
  RiftRC.closebutton:SetPoint("TOPRIGHT", window, "TOPRIGHT", r + 5, 17)
  RiftRC.closebutton.Event.LeftPress = RiftRC.closewindow

  RiftRC.buffer_label = UI.CreateFrame("RiftTextfield", "RiftRC", window)
  RiftRC.buffer_label:SetPoint("TOPLEFT", window, "TOPLEFT", 95, 53)
  RiftRC.buffer_label:SetHeight(20)
  RiftRC.buffer_label:SetWidth(200)
  RiftRC.buffer_label:SetBackgroundColor(0.4, 0.4, 0.4, 0.8)
  RiftRC.buffer_label:SetText("edit")
  RiftRC.buffer_label.Event.TextfieldChange = RiftRC.buffer_rename
  RiftRC.buffer_label:SetVisible(false)

  RiftRC.buffer_field = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.buffer_field:SetPoint("TOPLEFT", window, "TOPLEFT", 95, 53)
  RiftRC.buffer_field:SetHeight(20)
  RiftRC.buffer_field:SetWidth(200)
  RiftRC.buffer_field:SetText("edit")
  RiftRC.buffer_field:SetVisible(true)

  RiftRC.rc.ui = RiftRC.subUI(window:GetContent(), RiftRC.rc)
  RiftRC.out.ui = RiftRC.subUI(window:GetContent(), RiftRC.out)
  RiftRC.list.ui = RiftRC.subUI(window:GetContent(), RiftRC.list)
  RiftRC.list.buffer = RiftRC.sv.buffers

  local label = UI.CreateFrame("Text", "RiftRC", window)
  label:SetPoint("TOPLEFT", RiftRC.rc.ui.background, "BOTTOMLEFT", 35, -5)
  label:SetFontColor(0.7, 0.7, 0.7, 1)
  label:SetText("Status:")

  RiftRC.rc_errors = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.rc_errors:SetPoint("TOPLEFT", RiftRC.rc.ui.background, "BOTTOMLEFT", 75, -5)
  RiftRC.rc_errors:SetPoint("BOTTOMRIGHT", RiftRC.rc.ui.background, "BOTTOMRIGHT", 0, 23)
  RiftRC.rc_errors:SetText('')

  RiftRC.rc_feedback = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.rc_feedback:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", l + 39, b - 10)
  RiftRC.rc_feedback:SetText('')
  label:SetFontColor(0.8, 0.8, 0.8, 1)

  RiftRC.revert_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.revert_rcbutton.Event.LeftPress = function() RiftRC.load_buffer() end
  RiftRC.revert_rcbutton:SetPoint("TOPRIGHT", window, "TOPRIGHT", r - 72, 45)
  RiftRC.revert_rcbutton:SetText("REVERT")

  RiftRC.save_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.save_rcbutton.Event.LeftPress = RiftRC.save_rc
  RiftRC.save_rcbutton:SetPoint("TOPRIGHT", RiftRC.revert_rcbutton, "TOPLEFT", 5, 0)
  RiftRC.save_rcbutton:SetText("SAVE")

  RiftRC.run_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.run_rcbutton.Event.LeftPress = RiftRC.run_rc
  RiftRC.run_rcbutton:SetPoint("TOPRIGHT", RiftRC.save_rcbutton, "TOPLEFT", 5, 0)
  RiftRC.run_rcbutton:SetText("RUN")

  RiftRC.new_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.new_rcbutton.Event.LeftPress = RiftRC.new_rc
  RiftRC.new_rcbutton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", r - 15, b)
  RiftRC.new_rcbutton:SetText("NEW")

  RiftRC.del_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.del_rcbutton.Event.LeftPress = RiftRC.del_rc
  RiftRC.del_rcbutton:SetPoint("BOTTOMRIGHT", RiftRC.new_rcbutton, "BOTTOMLEFT", 5, 0)
  RiftRC.del_rcbutton:SetText("DELETE")
  RiftRC.del_rcbutton:SetEnabled(false)

  RiftRC.load_buffer('riftrc')
  RiftRC.show_buffer(RiftRC.out)
  RiftRC.show_buffer(RiftRC.list)
  RiftRC.change_rc(1)

  return window
end

function RiftRC.check_box(index)
  local ui_spec = RiftRC.list
  if not ui_spec then
    return
  end
  if ui_spec.ui and ui_spec.ui.scrollbar then
    ui_spec.offset = math.floor(ui_spec.ui.scrollbar:GetPosition())
  else
    ui_spec.offset = 0
  end
  local check = ui_spec.ui.checks[index]:GetChecked()
  local index = index + ui_spec.offset
  local item = ui_spec.indexed_buffer and ui_spec.indexed_buffer[index]
  if item and RiftRC.list.buffer[item] then
    RiftRC.list.buffer[item].autorun = check
  end
  RiftRC.show_buffer(RiftRC.list)
end

function RiftRC.select_buffer(index)
  local ui_spec = RiftRC.list
  if not ui_spec then
    return
  end
  RiftRC.message('')
  if ui_spec.ui and ui_spec.ui.scrollbar then
    ui_spec.offset = math.floor(ui_spec.ui.scrollbar:GetPosition())
  else
    ui_spec.offset = 0
  end
  index = index + ui_spec.offset
  item = ui_spec.indexed_buffer and ui_spec.indexed_buffer[index]
  if item then
    RiftRC.load_buffer(item)
  end
end

function RiftRC.load_buffer(name)
  if RiftRC.edit_buffer then
    RiftRC.unsaved[RiftRC.edit_buffer] = RiftRC.shallowcopy(RiftRC.rc.buffer)
  end
  if not name then
    name = RiftRC.edit_orig
  end
  if not RiftRC.unsaved[name] then
    RiftRC.warn("No buffer named '%s'.", name)
    return
  end
  RiftRC.rc.buffer = RiftRC.shallowcopy(RiftRC.unsaved[name])
  RiftRC.edit_buffer = name
  RiftRC.edit_orig = name
  if RiftRC.buffer_label then
    RiftRC.buffer_label:SetText(name)
  end
  if RiftRC.buffer_field then
    RiftRC.buffer_field:SetText(name)
  end
  if RiftRC.del_rcbutton then
    if name == 'riftrc' then
      RiftRC.del_rcbutton:SetEnabled(false)
      RiftRC.buffer_field:SetVisible(true)
      RiftRC.buffer_label:SetVisible(false)
    else
      RiftRC.del_rcbutton:SetEnabled(true)
      RiftRC.buffer_field:SetVisible(false)
      RiftRC.buffer_label:SetVisible(true)
    end
  end
  RiftRC.show_buffer(RiftRC.rc)
  RiftRC.show_buffer(RiftRC.list)
  RiftRC.change_rc(1)
  RiftRC.message("Loaded %s.", name)
  if RiftRC.save_rcbutton then
    RiftRC.save_rcbutton:SetEnabled(false)
  end
end

function RiftRC.buffer_rename()
  RiftRC.edit_buffer = RiftRC.buffer_label:GetText()
  if RiftRC.edit_buffer ~= RiftRC.edit_orig and RiftRC.list.buffer[RiftRC.edit_buffer] then
    RiftRC.save_rcbutton:SetEnabled(false)
  else
    RiftRC.save_rcbutton:SetEnabled(true)
  end
end

function RiftRC.save_rc()
  local name = RiftRC.edit_buffer
  local oldname = RiftRC.edit_orig
  if not name then
    RiftRC.printf("save_rc: No idea what buffer I'm editing.")
    return
  end
  if not (RiftRC.sv and RiftRC.sv.buffers) then
    RiftRC.printf("save_rc: Can't find buffer storage.")
  end
  if not RiftRC.sv.buffers then
    RiftRC.sv.buffers = {}
  end
  if name ~= oldname then
    RiftRC.unsaved[name] = RiftRC.unsaved[oldname]
    RiftRC.unsaved[oldname] = nil
    RiftRC.list.buffer[name] = RiftRC.list.buffer[oldname]
    RiftRC.list.buffer[oldname] = nil
    RiftRC.warn("Renaming %s to %s.", oldname, name)
    RiftRC.edit_orig = RiftRC.edit_buffer
  else
    RiftRC.warn("Saving %s.", RiftRC.edit_buffer)
  end
  local buff = RiftRC.list.buffer[name]
  if not buff then
    RiftRC.message("Huh? Can't find buffer for '%s'.", name)
  else
    buff.data = RiftRC.shallowcopy(RiftRC.rc.buffer)
  end
  if RiftRC.rc_savebutton then
    RiftRC.rc_savebutton:SetEnabled(false)
  end
  RiftRC.show_buffer(RiftRC.list)
end

function RiftRC.show_buffer(ui_spec)
  if ui_spec.ui and ui_spec.ui.scrollbar then
    ui_spec.offset = math.floor(ui_spec.ui.scrollbar:GetPosition())
  else
    -- haven't got a window yet.
    return
  end
  local indexed_buffer
  if ui_spec.interact == 'fancy' then
    indexed_buffer = {}
    for k, v in pairs(ui_spec.buffer) do
      table.insert(indexed_buffer, k)
    end
    table.sort(indexed_buffer)
    ui_spec.indexed_buffer = indexed_buffer
  else
    indexed_buffer = ui_spec.buffer
  end
  for i = 1, ui_spec.lines do
    local index = i + ui_spec.offset
    local line = indexed_buffer[index]
    if line then
      if ui_spec.interact == 'fancy' then
        local details = ui_spec.buffer[line]
        ui_spec.ui.labels[i]:SetText(tostring(line))
        ui_spec.ui.line_counts[i]:SetText("Lines: " .. #details.data)
	if line == RiftRC.edit_buffer then
          ui_spec.ui.borders[i]:SetBackgroundColor(0.5, 0.5, 0.3, 0.8)
	else
          ui_spec.ui.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
	end
	ui_spec.ui.checks[i]:SetVisible(true)
	ui_spec.ui.checks[i]:SetChecked(details.autorun or false)
      else
        ui_spec.ui.fields[i]:SetText(line)
        ui_spec.ui.labels[i]:SetText(tostring(index))
      end
    else
      if ui_spec.interact == 'fancy' then
        ui_spec.ui.labels[i]:SetText('')
        ui_spec.ui.line_counts[i]:SetText('')
	ui_spec.ui.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
	ui_spec.ui.checks[i]:SetVisible(false)
      else
        ui_spec.ui.fields[i]:SetText('')
        ui_spec.ui.labels[i]:SetText('')
      end
    end
  end
  RiftRC.check_scrollbar(ui_spec)
end

function RiftRC.show_riftrc()
  RiftRC.show_buffer(RiftRC.rc)
end

function RiftRC.check_scrollbars()
  RiftRC.check_scrollbar(RiftRC.rc)
  RiftRC.check_scrollbar(RiftRC.out)
  RiftRC.check_scrollbar(RiftRC.list)
end

function RiftRC.check_scrollbar(ui_spec)
  local buffer = ui_spec.buffer
  if ui_spec.interact == 'fancy' then
    buffer = ui_spec.indexed_buffer
  end
  if #buffer > ui_spec.lines then
    if ui_spec.ui and ui_spec.ui.scrollbar then
      ui_spec.ui.scrollbar:SetRange(0, #buffer - ui_spec.lines)
      ui_spec.ui.scrollbar:SetPosition(ui_spec.offset or 0)
      ui_spec.ui.scrollbar:SetEnabled(true)
    end
  else
    if ui_spec.ui and ui_spec.ui.scrollbar then
      ui_spec.ui.scrollbar:SetEnabled(false)
      ui_spec.ui.scrollbar:SetRange(0, 1)
      ui_spec.ui.scrollbar:SetPosition(0)
      ui_spec.offset = 0
    end
  end
end

function RiftRC.key_press(idx, event, key)
  local field = RiftRC.rc.ui.fields[idx]
  local text = field and field:GetText() or ''
  local cursor = field and field:GetCursor()
  local index = idx + RiftRC.rc.offset
  if key then
    if string.byte(key) == 8 then
      if idx > 1 and cursor < 1 then
	old = RiftRC.rc.buffer[index - 1] or ''
	RiftRC.rc.ui.fields[idx - 1]:SetKeyFocus(true)
	RiftRC.rc.buffer[index - 1] = old .. ' ' .. text
	RiftRC.rc.ui.fields[idx - 1]:SetText(RiftRC.rc.buffer[index - 1])
	RiftRC.rc.ui.fields[idx - 1]:SetCursor(#old + 1)
	if RiftRC.rc.offset > 0 then
	  RiftRC.rc.offset = RiftRC.rc.offset - 1
	end
        table.remove(RiftRC.rc.buffer, index)
	RiftRC.check_scrollbar(RiftRC.rc)
      end
      RiftRC.show_riftrc()
    elseif string.byte(key) == 13 then
      local spaces = string.match(text, '^(%s*)') or ''
      if string.find(text, '{$') or string.find(text, ' do$') or string.find(text, ' then$') then
        spaces = spaces .. '  '
      end
      RiftRC.printf("in <%s>: <%s> leading space", text, spaces)
      before = string.sub(text, 1, cursor)
      after = string.sub(text, cursor + 1)
      RiftRC.rc.buffer[index] = before
      table.insert(RiftRC.rc.buffer, index + 1, spaces .. after)
      RiftRC.check_scrollbar(RiftRC.rc)
      if #RiftRC.rc.buffer > RiftRC.rc.lines then
        RiftRC.rc.offset = RiftRC.rc.offset + 1
      else
        idx = idx + 1
      end
      RiftRC.show_riftrc()
      RiftRC.rc.ui.fields[idx]:SetKeyFocus(true)
      RiftRC.rc.ui.fields[idx]:SetCursor(#spaces)
    end
  end
  --RiftRC.printf("key: [%d] cur %d %s|%s", string.byte(key) or -1,
  --	cursor,
  --	string.sub(text, 1, cursor), string.sub(text, cursor + 1))
end

function RiftRC.change_rc(idx)
  if not RiftRC.rc.ui then
    return
  end
  local new = RiftRC.rc.ui.fields[idx] and RiftRC.rc.ui.fields[idx]:GetText()
  if new then
    local index = idx + RiftRC.rc.offset
    for i = 1, index do
      RiftRC.rc.buffer[i] = RiftRC.rc.buffer[i] or ''
    end
    if RiftRC.rc.buffer[index] ~= new then
      RiftRC.rc.buffer[index] = new
      RiftRC.save_rcbutton:SetEnabled(true)
    end
    code = table.concat(RiftRC.rc.buffer, "\n")
    func, err = loadstring(code)
    if func then
      RiftRC.rc_errors:SetText('OK')
      RiftRC.rc_errors:SetFontColor(0, 0.9, 0.3, 1)
      RiftRC.run_rcbutton:SetEnabled(true)
    else
      RiftRC.rc_errors:SetText(err)
      RiftRC.run_rcbutton:SetEnabled(false)
      RiftRC.rc_errors:SetFontColor(0.8, 0.2, 0.2, 1)
    end
    RiftRC.show_riftrc()
  end
end

function RiftRC.gui()
  RiftRC.ui = RiftRC.ui or UI.CreateContext("RiftRC")
  RiftRC.window = RiftRC.window or RiftRC.makewindow()
  if RiftRC.window then
    RiftRC.window:SetVisible(true)
  else
    RiftRC.printf("Can't display GUI.")
  end
end

function RiftRC.slashcommand(args)
  if not slashprint then
    slashprint = Inspect.Addon.Detail('SlashPrint')
    if slashprint then
      slashprint = slashprint.data
    end
  end
  if not args then
    RiftRC.printf("Usage error.")
    return
  end
  if args.n then
    if #args.leftover_args > 0 or args.r then
      RiftRC.warn("Can't specify arguments to new.")
    else
      RiftRC.gui()
      RiftRC.new_rc()
    end
  end
  if #args.leftover_args > 0 then
    if args.r then
      for _, name in ipairs(args.leftover_args) do
        local value = RiftRC.run_buffer(name)
	if value ~= nil then
	  local pretty = {}
	  if slashprint then
	    slashprint.dump(pretty, value)
	  else
	    table.insert(pretty, tostring(value))
	  end
	  for _, line in ipairs(pretty) do
	    print(line)
	  end
	end
      end
    else
      if #args.leftover_args ~= 1 then
        RiftRC.printf("Pick a single component.")
	return
      else
        RiftRC.gui()
	RiftRC.load_buffer(args.leftover_args[1])
      end
    end
  else
    RiftRC.gui()
    if args.r then
      RiftRC.run_rc()
    end
  end
end

Library.LibGetOpt.makeslash("nr", "RiftRC", "rc", RiftRC.slashcommand)

table.insert(Event.Addon.SavedVariables.Load.End, { RiftRC.variables_loaded, "RiftRC", "variable loaded hook" })
table.insert(Event.Addon.Startup.End, { RiftRC.run_buffers, "RiftRC", "run riftrc" })
