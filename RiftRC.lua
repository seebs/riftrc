--[[ RiftRC
     A .rc file to run at startup.

]]--

local addoninfo, RiftRC = ...

RiftRC.buffer = {}
RiftRC.lines = 18

function RiftRC.printf(fmt, ...)
  print(string.format(fmt or 'nil', ...))
end

function RiftRC.variables_loaded(addon)
  if addon == 'RiftRC' then
    RiftRC_dotRiftRC = RiftRC_dotRiftRC or { riftrc = {}, scratch = {} }
    RiftRC.buffer = {}
    for _, v in ipairs(RiftRC_dotRiftRC.riftrc) do
      table.insert(RiftRC.buffer, v)
    end
  end
end

function RiftRC.run_rc(args)
  local code = table.concat(RiftRC.buffer, "\n")
  func, err = loadstring(code)
  if func then
    local status, value = pcall(func)
    if not status then
      RiftRC.printf("Failed to execute: %s", value)
    end
  else
    print("riftrc didn't load: %s", err)
  end
end

function RiftRC.mousemove(window, x, y)
  if RiftRC_dotRiftRC then
    RiftRC_dotRiftRC.window_x = x
    RiftRC_dotRiftRC.window_y = y
  end
end

function RiftRC.closewindow()
  if RiftRC.window then
    for i, frame in pairs(RiftRC.rc_fields) do
      frame:SetKeyFocus(false)
    end
    RiftRC.window:SetVisible(false)
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
  window:SetHeight(500)
  window:SetTitle('.riftrc')
  window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", RiftRC_dotRiftRC and RiftRC_dotRiftRC.window_x or 150, RiftRC_dotRiftRC and RiftRC_dotRiftRC.window_y or 150)
  Library.LibDraggable.draggify(window, RiftRC.mousemove)

  local l, t, r, b = window:GetTrimDimensions()
  r = r * -1
  b = b * -1

  RiftRC.closebutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.closebutton:SetSkin("close")
  RiftRC.closebutton:SetPoint("TOPRIGHT", window, "TOPRIGHT", r + 5, 17)
  RiftRC.closebutton.Event.LeftPress = RiftRC.closewindow

  RiftRC.rc_background = UI.CreateFrame("Frame", "RiftRC", window)
  RiftRC.rc_background:SetPoint("TOPLEFT", window, "TOPLEFT", l + 5, t + 25)
  RiftRC.rc_background:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", r - 5, t + 400)
  RiftRC.rc_background:SetBackgroundColor(0.1, 0.1, 0.1, 0.3)
  local width = RiftRC.rc_background:GetWidth()
  local height = RiftRC.rc_background:GetHeight()

  RiftRC.rc_scrollbar = UI.CreateFrame("RiftScrollbar", "RiftRC", RiftRC.rc_background)
  RiftRC.rc_scrollbar:SetPoint("TOPRIGHT", RiftRC.rc_background, "TOPRIGHT", -2, 0)
  RiftRC.rc_scrollbar:SetHeight(height)
  -- Only active when there is scrolletry to do
  RiftRC.rc_scrollbar:SetEnabled(false)
  RiftRC.rc_scrollbar:SetRange(0, 1)
  RiftRC.rc_scrollbar:SetPosition(0)
  RiftRC.rc_scrollbar.Event.ScrollbarChange = RiftRC.show_riftrc
  window.Event.WheelBack = function() RiftRC.rc_scrollbar:Nudge(3) end
  window.Event.WheelForward = function() RiftRC.rc_scrollbar:Nudge(-3) end
  local w = RiftRC.rc_scrollbar:GetWidth()

  RiftRC.rc_offset = 0

  RiftRC.rc_fields = {}
  RiftRC.rc_labels = {}
  for i = 1, RiftRC.lines do
    RiftRC.rc_labels[i] = UI.CreateFrame("Text", "RiftRC", RiftRC.rc_background)
    RiftRC.rc_fields[i] = UI.CreateFrame("RiftTextfield", "RiftRC", RiftRC.rc_background)
    RiftRC.rc_labels[i]:SetPoint("TOPRIGHT", RiftRC.rc_background, "TOPLEFT", 30, -15 + 20 * i)
    RiftRC.rc_labels[i]:SetFontColor(0.7, 0.7, 0.4, 1)
    RiftRC.rc_fields[i]:SetPoint("TOPLEFT", RiftRC.rc_background, "TOPLEFT", 35, -15 + 20 * i)
    RiftRC.rc_fields[i]:SetHeight(20)
    RiftRC.rc_fields[i]:SetWidth(width - 40 - w)

    RiftRC.rc_fields[i]:SetBackgroundColor(0, 0, 0, 1)
    RiftRC.rc_fields[i].Event.TextfieldChange = function() RiftRC.change_rc(i) end
    RiftRC.rc_fields[i].Event.KeyDown = function(event, key) RiftRC.key_press(i, event, key) end
  end

  local label = UI.CreateFrame("Text", "RiftRC", window)
  label:SetPoint("TOPLEFT", RiftRC.rc_background, "BOTTOMLEFT", 0, 3)
  label:SetFontColor(0.7, 0.7, 0.7, 1)
  label:SetText("Status:")

  RiftRC.rc_errors = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.rc_errors:SetPoint("TOPLEFT", RiftRC.rc_background, "BOTTOMLEFT", 50, 3)
  RiftRC.rc_errors:SetPoint("BOTTOMRIGHT", RiftRC.rc_background, "BOTTOMRIGHT", 0, 35)
  RiftRC.rc_errors:SetText('')

  RiftRC.run_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.run_rcbutton.Event.LeftPress = RiftRC.run_rc
  RiftRC.run_rcbutton:SetPoint("TOPRIGHT", window, "TOPRIGHT", r - 200, t - 10)
  RiftRC.run_rcbutton:SetText("RUN")

  RiftRC.save_rcbutton = UI.CreateFrame("RiftButton", "RiftRC", window)
  RiftRC.save_rcbutton.Event.LeftPress = RiftRC.save_rc
  RiftRC.save_rcbutton:SetPoint("TOPRIGHT", window, "TOPRIGHT", r - 70, t - 10)
  RiftRC.save_rcbutton:SetText("SAVE")

  RiftRC.scrollbar_check()
  RiftRC.show_riftrc()
  RiftRC.change_rc(1)

  return window
end

function RiftRC.save_rc()
  RiftRC_dotRiftRC.riftrc = {}
  for _, line in ipairs(RiftRC.buffer) do
    table.insert(RiftRC_dotRiftRC.riftrc, line)
  end
end

function RiftRC.show_riftrc()
  RiftRC.rc_offset = RiftRC.rc_scrollbar:GetPosition()
  for i = 1, RiftRC.lines do
    local index = i + RiftRC.rc_offset
    local line = RiftRC.buffer[index]
    if line then
      RiftRC.rc_fields[i]:SetText(line)
      RiftRC.rc_labels[i]:SetText(tostring(index))
    else
      RiftRC.rc_fields[i]:SetText('')
      RiftRC.rc_labels[i]:SetText('')
    end
  end
end

function RiftRC.scrollbar_check()
  if #RiftRC.buffer > RiftRC.lines then
    RiftRC.rc_scrollbar:SetRange(0, #RiftRC.buffer - RiftRC.lines)
    RiftRC.rc_scrollbar:SetPosition(RiftRC.rc_offset)
    RiftRC.rc_scrollbar:SetEnabled(true)
  else
    RiftRC.rc_scrollbar:SetEnabled(false)
    RiftRC.rc_scrollbar:SetRange(0, 1)
    RiftRC.rc_scrollbar:SetPosition(0)
    RiftRC.rc_offset = 0
  end
end

function RiftRC.key_press(idx, event, key)
  local field = RiftRC.rc_fields[idx]
  local text = field and field:GetText()
  local cursor = field and field:GetCursor()
  local index = idx + RiftRC.rc_offset
  if key then
    if string.byte(key) == 8 then
      if idx > 1 and cursor < 1 then
	old = RiftRC.buffer[index - 1] or ''
	RiftRC.rc_fields[idx - 1]:SetKeyFocus(true)
	RiftRC.buffer[index - 1] = old .. ' ' .. text
	RiftRC.rc_fields[idx - 1]:SetText(RiftRC.buffer[index - 1])
	RiftRC.rc_fields[idx - 1]:SetCursor(#old + 1)
        table.remove(RiftRC.buffer, index)
	RiftRC.scrollbar_check()
      end
      RiftRC.show_riftrc()
    elseif string.byte(key) == 13 then
      before = string.sub(text, 1, cursor)
      after = string.sub(text, cursor + 1)
      RiftRC.buffer[index] = before
      table.insert(RiftRC.buffer, index + 1, after)
      RiftRC.scrollbar_check()
      if #RiftRC.buffer > RiftRC.lines then
        RiftRC.rc_offset = RiftRC.rc_offset + 1
      end
      RiftRC.rc_fields[idx + 1]:SetKeyFocus(true)
      RiftRC.rc_fields[idx + 1]:SetCursor(0)
      RiftRC.show_riftrc()
    end
  end
  --RiftRC.printf("key: [%d] cur %d %s|%s", string.byte(key) or -1,
  --	cursor,
  --	string.sub(text, 1, cursor), string.sub(text, cursor + 1))
end

function RiftRC.change_rc(idx)
  local new = RiftRC.rc_fields[idx] and RiftRC.rc_fields[idx]:GetText()
  if new then
    local index = idx + RiftRC.rc_offset
    for i = 1, index do
      RiftRC.buffer[i] = RiftRC.buffer[i] or ''
    end
    RiftRC.buffer[index] = new
    code = table.concat(RiftRC.buffer, "\n")
    func, err = loadstring(code)
    if func then
      RiftRC.rc_errors:SetText('OK')
      RiftRC.rc_errors:SetFontColor(0, 0.9, 0.3, 1)
      RiftRC.run_rcbutton:SetEnabled(true)
      RiftRC.save_rcbutton:SetEnabled(true)
    else
      RiftRC.rc_errors:SetText(err)
      RiftRC.run_rcbutton:SetEnabled(false)
      RiftRC.save_rcbutton:SetEnabled(false)
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
table.insert(Event.Addon.Startup.End, { RiftRC.run_rc, "RiftRC", "run riftrc" })
