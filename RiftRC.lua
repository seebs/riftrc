--[[ RiftRC
     A .rc file to run at startup.

]]--

local addoninfo, RiftRC = ...
local slashprint

RiftRC.edit_buffer = nil
RiftRC.edit_orig = nil
RiftRC.unsaved = {}
RiftRC.buffer = ''

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

function RiftRC.update()
  if RiftRC.live and RiftRC.window and RiftRC.window:GetVisible() then
    RiftRC.output(RiftRC.stash_value, true)
  end
end

function RiftRC.variables_loaded(addon)
  if addon == 'RiftRC' then
    RiftRC_dotRiftRC = RiftRC_dotRiftRC or { buffers = { riftrc = { data = '', autorun = true } }, }
    RiftRC.sv = RiftRC_dotRiftRC
    if not RiftRC.sv.buffers.riftrc then
      RiftRC.sv.buffers.riftrc = { data = '', autorun = true }
    end
    RiftRC.sorted_buffers = {}
    for name, value in pairs(RiftRC.sv.buffers) do
      if type(value.data) == 'table' then
        value.data = table.concat(value.data, '\n')
      end
      value.data = string.gsub(value.data, '\r', '\n')
      RiftRC.unsaved[name] = value.data
      table.insert(RiftRC.sorted_buffers, name)
    end
    table.sort(RiftRC.sorted_buffers)
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

function RiftRC.output(value, quiet)
  RiftRC.stash_value = value
  local pretty = {}
  if not RiftRC.out or not RiftRC.out.text then
    return
  end
  if not slashprint then
    slashprint = Inspect.Addon.Detail('SlashPrint')
    if slashprint then
      slashprint = slashprint.data
    end
  end
  if slashprint then
    slashprint.dump(pretty, value)
    if not quiet then
      RiftRC.message("Dumped %s into table, %d item%s.", tostring(value), #pretty, #pretty ~= 1 and 's' or '')
    end
  else
    table.insert(pretty, tostring(value))
  end
  RiftRC.out:text(table.concat(pretty, '\n'))
  RiftRC.out:check_scrollbar()
end

function RiftRC.run_buffer(name, buffer)
  if not buffer then
    buffer = RiftRC.unsaved[name] or (RiftRC.list.u.buffers[name] and RiftRC.list.u.buffers[name].data)
    if not buffer then
      RiftRC.warn("Can't find buffer '%s' to run.", tostring(name))
      return
    end
  end
  func, err = loadstring(buffer)
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
  value = RiftRC.run_buffer('edit buffer', RiftRC.buffer)
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
    RiftRC.window:SetVisible(false)
  end
end

function RiftRC.new_rc()
  local new_name
  for i = 1, 100 do
    new_name = 'untitled ' .. i
    if not RiftRC.list.u.buffers[new_name] then
      break
    end
  end
  RiftRC.output(nil)
  RiftRC.unsaved[new_name] = {}
  RiftRC.list.u.buffers[new_name] = { autorun = true, data = '' }
  table.insert(RiftRC.list.data, new_name)
  RiftRC.list:display()
  RiftRC.load_buffer(new_name)
end

function RiftRC.del_rc()
  local name = RiftRC.edit_orig
  if name == 'riftrc' then
    return
  else
    local best_guess = nil
    local this_one = nil
    --[[
      If the one we picked was #1, we obviously want to go to #2.
      If the one we picked was later, either we want the one after
      it, or we want the one before it if it was the last one.  So,
      we pick the one before it, and continue; if we get another
      one, we use that one and stop looking.

      Note that since you can't delete the riftrc member, in theory
      there should always be at least one other...
      ]]--
    if RiftRC.list.data then
      for index, value in ipairs(RiftRC.list.data) do
	if best_guess then
	  best_guess = value
	  break
	end
        if value == name then
	  this_one = index
	  if index == 1 then
	    best_guess = RiftRC.list.data[2]
	    break
	  end
	  best_guess = RiftRC.list.data[index - 1]
	end
      end
    end
    table.remove(RiftRC.list.data, this_one)
    RiftRC.sv.trash = RiftRC.sv.trash or {}
    if RiftRC.list.u.buffers[name] then
      RiftRC.sv.trash[name] = RiftRC.list.u.buffers[name].data
    end
    RiftRC.list.u.buffers[name] = nil
    if RiftRC.unsaved[name] then
      RiftRC.sv.trash[name] = RiftRC.unsaved[name]
    end
    RiftRC.unsaved[name] = nil
    RiftRC.list:display()
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

  RiftRC.rcframe = UI.CreateFrame('Frame', 'RiftRC', window:GetContent())
  RiftRC.rcframe:SetPoint('TOPLEFT', window:GetContent(), 'TOPLEFT', 5, 20)
  RiftRC.rcframe:SetWidth(570)
  RiftRC.rcframe:SetHeight(280)

  RiftRC.outframe = UI.CreateFrame('Frame', 'RiftRC', window:GetContent())
  RiftRC.outframe:SetPoint('BOTTOMLEFT', window:GetContent(), 'BOTTOMLEFT', 5, -32)
  RiftRC.outframe:SetWidth(570)
  RiftRC.outframe:SetHeight(170)

  dummyframe = UI.CreateFrame('RiftTextfield', 'RiftRC', window:GetContent())
  dummyframe:SetPoint('TOPLEFT', window:GetContent(), 'TOPLEFT')

  RiftRC.rc = Library.LibScrollyTextThing.create(RiftRC.rcframe, 'RiftRC', '',
  	{ editable = true, autoindent = true, number = true }, 'RIGHT', RiftRC.change_rc)
  RiftRC.out = Library.LibScrollyTextThing.create(RiftRC.outframe, 'RiftRC', '',
  	{ number = true }, 'RIGHT', nil)

  RiftRC.out.background:SetBackgroundColor(0.1, 0.1, 0.1, 0.3)
  RiftRC.rc.background:SetBackgroundColor(0.1, 0.1, 0.1, 0.3)

  RiftRC.listframe = UI.CreateFrame('Frame', 'RiftRC', window:GetContent())
  RiftRC.listframe:SetPoint('TOPRIGHT', window:GetContent(), 'TOPRIGHT', -5, 20)
  RiftRC.listframe:SetWidth(185)
  RiftRC.listframe:SetHeight(479)

  local list_aux = {
    borders = {},
    checks = {},
    fields = {},
    labels = {},
    line_counts = {},
  }

  RiftRC.list = Library.LibItemList.create(RiftRC.listframe, 'RiftRC', list_aux, 10, 'RIGHT', RiftRC.make_listitem, RiftRC.show_listitem, RiftRC.select_listitem)
  RiftRC.list.u.buffers = RiftRC.sv.buffers

  for idx, name in ipairs(RiftRC.sorted_buffers) do
    if name == 'riftrc' then
      RiftRC.list.selected = idx
      break
    end
  end
  RiftRC.list:display(RiftRC.sorted_buffers)

  local label = UI.CreateFrame("Text", "RiftRC", window)
  label:SetPoint("TOPLEFT", RiftRC.rcframe, "BOTTOMLEFT", 35, 0)
  label:SetFontColor(0.7, 0.7, 0.7, 1)
  label:SetText("Status:")

  RiftRC.rc_errors = UI.CreateFrame("Text", "RiftRC", window)
  RiftRC.rc_errors:SetPoint("TOPLEFT", RiftRC.rcframe, "BOTTOMLEFT", 75, 0)
  RiftRC.rc_errors:SetPoint("BOTTOMRIGHT", RiftRC.rcframe, "BOTTOMRIGHT", 0, 23)
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
  RiftRC.list:display()
  RiftRC.change_rc()
  RiftRC.output(RiftRC.stash_value, true)

  return window
end

-- interactions with LibItemList
function RiftRC.make_listitem(tab, frame, i)

  tab.u.borders[i] = UI.CreateFrame("Frame", "list" .. i, frame)
  tab.u.borders[i]:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, 1)
  tab.u.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
  tab.u.borders[i]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, -1)
  tab.u.borders[i]:SetMouseMasking('limited')

  tab.u.fields[i] = UI.CreateFrame("Frame", "list" .. i, tab.u.borders[i])
  tab.u.fields[i]:SetPoint("TOPLEFT", tab.u.borders[i], "TOPLEFT", 2, 2)
  tab.u.fields[i]:SetPoint("BOTTOMRIGHT", tab.u.borders[i], "BOTTOMRIGHT", -2, -2)
  tab.u.fields[i]:SetBackgroundColor(0.1, 0.1, 0.1, 0.8)
  tab.u.fields[i]:SetMouseMasking('limited')

  tab.u.checks[i] = UI.CreateFrame("RiftCheckbox", "check" .. i, tab.u.fields[i])
  tab.u.checks[i]:SetPoint("BOTTOMRIGHT", tab.u.fields[i], "BOTTOMRIGHT", -2, -2)
  tab.u.checks[i].Event.CheckboxChange = function() RiftRC.check_box(i) end

  tab.u.labels[i] = UI.CreateFrame("Text", "RiftRC", tab.u.fields[i])
  tab.u.labels[i]:SetPoint("TOPLEFT", tab.u.fields[i], "TOPLEFT", 2, 2)
  tab.u.labels[i]:SetFontColor(0.9, 0.9, 0.9, 1)
  tab.u.labels[i]:SetMouseMasking('limited')

  tab.u.line_counts[i] = UI.CreateFrame("Text", "RiftRC", tab.u.fields[i])
  tab.u.line_counts[i]:SetPoint("TOPLEFT", tab.u.fields[i], "TOPLEFT", 2, 22)
  tab.u.line_counts[i]:SetFontColor(0.9, 0.9, 0.7, 1)
  tab.u.line_counts[i]:SetMouseMasking('limited')
end

function RiftRC.show_listitem(frametable, i, itemtable, itemindex, selected)
  local item = itemtable[itemindex]
  if item then
    local details = RiftRC.sv.buffers[item]
    if not details then
      RiftRC.printf("No details for name %s", item)
    end
    local _, lines = string.gsub(details.data, "\n", "\n")
    frametable.u.labels[i]:SetText(tostring(item))
    frametable.u.line_counts[i]:SetText("Lines: " .. lines)
    if selected then
      frametable.u.borders[i]:SetBackgroundColor(0.5, 0.5, 0.3, 0.8)
    else
      frametable.u.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
    end
    frametable.u.checks[i]:SetVisible(true)
    frametable.u.checks[i]:SetChecked(details.autorun or false)
  else
    frametable.u.labels[i]:SetText('')
    frametable.u.line_counts[i]:SetText('')
    frametable.u.borders[i]:SetBackgroundColor(0.3, 0.3, 0.3, 0.8)
    frametable.u.checks[i]:SetVisible(false)
  end
end

function RiftRC.select_listitem(frametable, frameindex, itemtable, itemindex)
  local tab = frametable
  if not tab then
    return
  end
  item = itemtable[itemindex]
  if item then
    RiftRC.load_buffer(item)
  end
end

function RiftRC.check_box(idx)
  local tab = RiftRC.list
  if not tab then
    return
  end
  local check = tab.u.checks[idx]:GetChecked()
  local index = idx + tab.offset
  local item = tab.data and tab.data[index]
  if item and tab.u.buffers[item] then
    tab.u.buffers[item].autorun = check
  end
  RiftRC.list:display()
end

function RiftRC.load_buffer(name)
  if RiftRC.edit_buffer then
    RiftRC.unsaved[RiftRC.edit_buffer] = RiftRC.buffer
  end
  if not name then
    name = RiftRC.edit_orig
  end
  if not RiftRC.unsaved[name] then
    RiftRC.warn("No buffer named '%s'.", name)
    return
  end
  RiftRC.buffer = RiftRC.unsaved[name]
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
  if RiftRC.list and RiftRC.list.data then
    for idx, itemname in ipairs(RiftRC.list.data) do
      if itemname == name then
	RiftRC.list.selected = idx
	break
      end
    end
  end
  if RiftRC.rc and RiftRC.rc.text then
    RiftRC.rc:text(RiftRC.buffer)
  end
  if RiftRC.list then
    RiftRC.list:display()
  end
  RiftRC.change_rc()
  RiftRC.message("Loaded %s.", name)
  if RiftRC.save_rcbutton then
    RiftRC.save_rcbutton:SetEnabled(false)
  end
end

function RiftRC.buffer_rename()
  RiftRC.edit_buffer = RiftRC.buffer_label:GetText()
  if RiftRC.edit_buffer ~= RiftRC.edit_orig and RiftRC.sv.buffers[RiftRC.edit_buffer] then
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
    RiftRC.list.u.buffers[name] = RiftRC.list.u.buffers[oldname]
    RiftRC.list.u.buffers[oldname] = nil
    RiftRC.warn("Renaming %s to %s.", oldname, name)
    RiftRC.edit_orig = RiftRC.edit_buffer
    local this_one = nil
    for index, n in ipairs(RiftRC.list.data) do
      if n == oldname then
        this_one = index
	break
      end
    end
    if this_one then
      RiftRC.list.data[this_one] = name
      table.sort(RiftRC.list.data)
      for index, n in ipairs(RiftRC.list.data) do
	if n == name then
	  RiftRC.list.selected = index
	  break
	end
      end
    end
  else
    RiftRC.warn("Saving %s.", RiftRC.edit_buffer)
  end
  local buff = RiftRC.list.u.buffers[name]
  if not buff then
    RiftRC.message("Huh? Can't find buffer for '%s'.", name)
  else
    buff.data = RiftRC.buffer
  end
  if RiftRC.rc_savebutton then
    RiftRC.rc_savebutton:SetEnabled(false)
  end
  RiftRC.list:display()
end

function RiftRC.check_scrollbars()
  RiftRC.rc:check_scrollbar()
  RiftRC.out:check_scrollbar()
  RiftRC.list:check_scrollbar()
end

function RiftRC.change_rc()
  if not RiftRC.rc or not RiftRC.rc.text then
    return
  end
  local new = RiftRC.rc:text()
  if new then
    if new ~= RiftRC.buffer then
      RiftRC.buffer = new
      RiftRC.save_rcbutton:SetEnabled(true)
    end
    func, err = loadstring(RiftRC.buffer)
    if func then
      RiftRC.rc_errors:SetText('OK')
      RiftRC.rc_errors:SetFontColor(0, 0.9, 0.3, 1)
      RiftRC.run_rcbutton:SetEnabled(true)
    else
      RiftRC.rc_errors:SetText(err)
      RiftRC.run_rcbutton:SetEnabled(false)
      RiftRC.rc_errors:SetFontColor(0.8, 0.2, 0.2, 1)
    end
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
  if args.l then
    RiftRC.live = not RiftRC.live
  end
  if args.n then
    if #args.leftover_args > 0 or args.r then
      RiftRC.warn("Can't run, or specify arguments to, new buffer.")
    else
      RiftRC.gui()
      RiftRC.new_rc()
    end
  end
  if #args.leftover_args > 0 then
    if args.e then
      if #args.leftover_args ~= 1 then
        RiftRC.printf("Pick a single component.")
	return
      else
        RiftRC.gui()
	RiftRC.load_buffer(args.leftover_args[1])
      end
    else
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
      return
    end
  else
    RiftRC.gui()
  end
  if args.r then
    RiftRC.run_rc()
  end
end

Library.LibGetOpt.makeslash("elnr", "RiftRC", "rc", RiftRC.slashcommand)

table.insert(Event.System.Update.Begin, { RiftRC.update, "RiftRC", "update hook" })
table.insert(Event.Addon.SavedVariables.Load.End, { RiftRC.variables_loaded, "RiftRC", "variable loaded hook" })
table.insert(Event.Addon.Startup.End, { RiftRC.run_buffers, "RiftRC", "run riftrc" })
