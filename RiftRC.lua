--[[ RiftRC
     A .rc file to run at startup.

]]--

local addoninfo, RiftRC = ...
local slashprint

RiftRC.rc = { buffer = {}, lines = 15, interact = true, point = "TOPLEFT", yoffset = 15 }
RiftRC.out = { buffer = {}, lines = 9, interact = false, point = "BOTTOMLEFT", yoffset = 0 }
RiftRC.list = { buffer = {}, lines = 10, interact = 'fancy', xoffset = -5, yoffset = 15, height = 48, width = 195, point = "TOPRIGHT" }
RiftRC.edit_buffer = 'riftrc'

function RiftRC.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function RiftRC.variables_loaded(addon)
  if addon == 'RiftRC' then
    RiftRC_dotRiftRC = RiftRC_dotRiftRC or { buffers = {}, }
    RiftRC.rc.buffer = {}
    RiftRC.sv = RiftRC_dotRiftRC
    RiftRC.load_buffer('riftrc')
  end
end

function RiftRC.run_buffers()
  RiftRC.printf("Running buffers.")
  if RiftRC.sv and RiftRC.sv.buffers then
    for name, buffer in pairs(RiftRC.sv.buffers) do
      if buffer.autorun then
	if name == 'riftrc' then
	  -- special handling
	  RiftRC.run_rc()
	else
	  RiftRC.run_buffer(string.format('"%s"', name), buffer.data)
	end
      end
    end
  else
    RiftRC.printf("run_buffers: Didn't find buffers.")
  end
end

function RiftRC.run_buffer(name, buffer)
  local code = table.concat(RiftRC.rc.buffer, "\n")
  func, err = loadstring(code)
  if func then
    local status, value = pcall(func)
    if not status then
      RiftRC.printf("Failed to execute: %s", value)
    else
      return value
    end
  else
    RiftRC.printf("Failed to load code from %s.", name)
  end
end

function RiftRC.run_rc(args)
  if not slashprint then
    slashprint = Inspect.Addon.Detail('SlashPrint')
    if slashprint then
      slashprint = slashprint.data
    end
  end
  value = RiftRC.run_buffer('edit buffer', RiftRC.rc.buffer)

  local pretty = {}
  if slashprint then
    slashprint.dump(pretty, value)
    -- RiftRC.printf("Dumped %s into table, %d items.", tostring(value), #pretty)
  else
    RiftRC.printf("No slashprint.")
    table.insert(pretty, tostring(value))
  end
  RiftRC.out.buffer = pretty
  RiftRC.check_scrollbar(RiftRC.out)
  RiftRC.show_buffer(RiftRC.out)
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
    tab.line_counts = {}
  end
  for i = 1, ui_spec.lines do
    if ui_spec.interact == 'fancy' then
      tab.fields[i] = UI.CreateFrame("Frame", "list" .. i, tab.background)
      tab.fields[i]:SetPoint("TOPLEFT", tab.background, "TOPLEFT", 5, 5 + line_height * (i - 1))
      tab.fields[i]:SetWidth(width - w - 10)
      tab.fields[i]:SetHeight(line_height)
      tab.fields[i]:SetBackgroundColor(0.1, 0.1, 0.6, 0.8)

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
  RiftRC.printf("not implemented")
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

  RiftRC.buffer_label = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.buffer_label:SetPoint("TOPLEFT", window, "TOPLEFT", 95, 55)
  RiftRC.buffer_label:SetFontColor(0.9, 0.9, 0.7, 1)
  RiftRC.buffer_label:SetText("edit")

  RiftRC.rc.ui = RiftRC.subUI(window:GetContent(), RiftRC.rc)
  RiftRC.out.ui = RiftRC.subUI(window:GetContent(), RiftRC.out)
  RiftRC.list.ui = RiftRC.subUI(window:GetContent(), RiftRC.list)
  RiftRC.list.buffer = RiftRC.sv.buffers

  local label = UI.CreateFrame("Text", "RiftRC", window)
  label:SetPoint("TOPLEFT", RiftRC.rc.ui.background, "BOTTOMLEFT", 33, -3)
  label:SetFontColor(0.7, 0.7, 0.7, 1)
  label:SetText("Status:")

  RiftRC.rc_errors = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.rc_errors:SetPoint("TOPLEFT", RiftRC.rc.ui.background, "BOTTOMLEFT", 72, -3)
  RiftRC.rc_errors:SetPoint("BOTTOMRIGHT", RiftRC.rc.ui.background, "BOTTOMRIGHT", 0, 23)
  RiftRC.rc_errors:SetText('')

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

  RiftRC.check_scrollbars()
  RiftRC.load_buffer('riftrc')
  RiftRC.show_buffer(RiftRC.rc)
  RiftRC.show_buffer(RiftRC.out)
  RiftRC.show_buffer(RiftRC.list)
  RiftRC.change_rc(1)

  return window
end

function RiftRC.load_buffer(buffer)
  buffer = buffer or RiftRC.edit_buffer or 'riftrc'
  RiftRC.rc.buffer = {}
  if RiftRC.sv and RiftRC.sv.buffers and RiftRC.sv.buffers[buffer] and RiftRC.sv.buffers[buffer].data then
    for _, line in ipairs(RiftRC.sv.buffers[buffer].data) do
      table.insert(RiftRC.rc.buffer, line)
    end
  end
  RiftRC.edit_buffer = buffer
  if RiftRC.buffer_label then
    RiftRC.buffer_label:SetText(buffer)
  end
  RiftRC.show_buffer(RiftRC.rc)
end

function RiftRC.save_rc()
  if not RiftRC.edit_buffer then
    RiftRC.printf("save_rc: No idea what buffer I'm editing.")
    return
  end
  if not (RiftRC.sv and RiftRC.sv.buffers) then
    RiftRC.printf("save_rc: Can't find buffer storage.")
  end
  if not RiftRC.sv.buffers then
    RiftRC.sv.buffers = {}
  end
  if not RiftRC.sv.buffers[RiftRC.edit_buffer] then
    RiftRC.sv.buffers[RiftRC.edit_buffer] = { autorun = true, data = {} }
  end
  local buff = RiftRC.sv.buffers[RiftRC.edit_buffer]
  buff.data = {}
  for _, line in ipairs(RiftRC.rc.buffer) do
    table.insert(buff.data, line)
  end
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
      else
        ui_spec.ui.fields[i]:SetText(line)
        ui_spec.ui.labels[i]:SetText(tostring(index))
      end
    else
      if ui_spec.interact == 'fancy' then
        ui_spec.ui.labels[i]:SetText('')
        ui_spec.ui.line_counts[i]:SetText('')
      else
        ui_spec.ui.fields[i]:SetText('')
        ui_spec.ui.labels[i]:SetText('')
      end
    end
  end
end

function RiftRC.show_riftrc()
  RiftRC.show_buffer(RiftRC.rc)
end

function RiftRC.check_scrollbars()
  RiftRC.check_scrollbar(RiftRC.rc)
  RiftRC.check_scrollbar(RiftRC.out)
end

function RiftRC.check_scrollbar(ui_spec)
  if #ui_spec.buffer > ui_spec.lines then
    if ui_spec.ui and ui_spec.ui.scrollbar then
      ui_spec.ui.scrollbar:SetRange(0, #ui_spec.buffer - ui_spec.lines)
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
  local text = field and field:GetText()
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
      before = string.sub(text, 1, cursor)
      after = string.sub(text, cursor + 1)
      RiftRC.rc.buffer[index] = before
      table.insert(RiftRC.rc.buffer, index + 1, after)
      RiftRC.check_scrollbar(RiftRC.rc)
      if #RiftRC.rc.buffer > RiftRC.rc.lines then
        RiftRC.rc.offset = RiftRC.rc.offset + 1
      end
      if idx < RiftRC.rc.lines then
        idx = idx + 1
      end
      RiftRC.rc.ui.fields[idx]:SetKeyFocus(true)
      RiftRC.rc.ui.fields[idx]:SetCursor(0)
      RiftRC.show_riftrc()
    end
  end
  --RiftRC.printf("key: [%d] cur %d %s|%s", string.byte(key) or -1,
  --	cursor,
  --	string.sub(text, 1, cursor), string.sub(text, cursor + 1))
end

function RiftRC.change_rc(idx)
  local new = RiftRC.rc.ui.fields[idx] and RiftRC.rc.ui.fields[idx]:GetText()
  if new then
    local index = idx + RiftRC.rc.offset
    for i = 1, index do
      RiftRC.rc.buffer[i] = RiftRC.rc.buffer[i] or ''
    end
    RiftRC.rc.buffer[index] = new
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
  if not args then
    RiftRC.printf("Usage error.")
    return
  end
  RiftRC.gui()
end

Library.LibGetOpt.makeslash("", "RiftRC", "rc", RiftRC.slashcommand)

table.insert(Event.Addon.SavedVariables.Load.End, { RiftRC.variables_loaded, "RiftRC", "variable loaded hook" })
table.insert(Event.Addon.Startup.End, { RiftRC.run_buffers, "RiftRC", "run riftrc" })
