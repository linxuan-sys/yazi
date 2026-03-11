--- @since 26.1.4

local path_sep = package.config:sub(1, 1)

local DEFAULT_SPECIAL_KEYS = {
  create_temp = "<Enter>",
  fuzzy_search = "<Space>",
  history = "<Tab>",
  previous_dir = "<Backspace>",
}

local function get_fzf_delimiter()
  if ya.target_family() == "windows" then
    return "--delimiter=\\t"
  else
    return "--delimiter='\t'"
  end
end

local get_hovered_path = ya.sync(function(state)
  local h = cx.active.current.hovered
  if h then
    local path = tostring(h.url)
    if h.cha.is_dir then
      if ya.target_family() == "windows" and path:match("^[A-Za-z]:$") then
        return path .. "\\"
      end
      return path
    end
    return path
  else
    return ''
  end
end)

local is_hovered_directory = ya.sync(function(state)
  local h = cx.active.current.hovered
  if h then
    return h.cha.is_dir
  end
  return false
end)

local get_current_dir_path = ya.sync(function()
  local path = tostring(cx.active.current.cwd)
  if ya.target_family() == "windows" and path:match("^[A-Za-z]:$") then
    return path .. "\\"
  end
  return path
end)

local get_state_attr = ya.sync(function(state, attr)
  return state[attr]
end)

local set_state_attr = ya.sync(function(state, attr, value)
  state[attr] = value
end)

local set_bookmarks = ya.sync(function(state, path, value)
  state.bookmarks[path] = value
end)

local set_temp_bookmarks = ya.sync(function(state, path, value)
  state.temp_bookmarks[path] = value
end)

local get_temp_bookmarks = ya.sync(function(state)
  return state.temp_bookmarks
end)

local get_current_tab_idx = ya.sync(function(state)
  return cx.tabs.idx
end)

local get_directory_history = ya.sync(function(state)
  return state.directory_history
end)

local add_to_history = ya.sync(function(state, tab_idx, path)
  if not state.directory_history[tab_idx] then
    state.directory_history[tab_idx] = {}
  end

  local history = state.directory_history[tab_idx]
  local history_size = state.history_size or 10

  for i = #history, 1, -1 do
    if history[i] == path then
      table.remove(history, i)
    end
  end

  table.insert(history, 1, path)

  while #history > history_size do
    table.remove(history, #history)
  end
end)

local get_tab_history = ya.sync(function(state, tab_idx)
  return state.directory_history[tab_idx] or {}
end)

local function ensure_directory(path)
  local dir_path = path:match("(.+)[\\/][^\\/]*$")
  if not dir_path then
    return
  end
  if ya.target_family() == "windows" then
    os.execute('mkdir "' .. dir_path:gsub("/", "\\") .. '" 2>nul')
  else
    os.execute('mkdir -p "' .. dir_path .. '"')
  end
end

local function normalize_path(path)
  local normalized_path = tostring(path):gsub("[\\/]+", path_sep)

  if ya.target_family() == "windows" then
    if normalized_path:match("^[A-Za-z]:[\\/]*$") then
      normalized_path = normalized_path:gsub("^([A-Za-z]:)[\\/]*", "%1\\")
    else
      normalized_path = normalized_path:gsub("^([A-Za-z]:)[\\/]+", "%1\\")
      normalized_path = normalized_path:gsub("[\\/]+$", "")
    end
  else
    if normalized_path ~= "/" then
      normalized_path = normalized_path:gsub("[\\/]+$", "")
    end
  end

  return normalized_path
end

local function apply_home_alias(path)
  if not path or path == "" then
    return path
  end

  local home_alias_enabled = get_state_attr("home_alias_enabled")
  if home_alias_enabled == false then
    return path
  end

  if path:sub(1, 1) == "~" then
    return path
  end

  local home = os.getenv("HOME")
  if ya.target_family() == "windows" and (not home or home == "") then
    home = os.getenv("USERPROFILE")
  end
  if not home or home == "" then
    return path
  end

  local normalized_home = normalize_path(home)
  if not normalized_home or normalized_home == "" then
    return path
  end

  local sep = path_sep

  if ya.target_family() == "windows" then
    local path_lower = path:lower()
    local home_lower = normalized_home:lower()
    if path_lower == home_lower then
      return "~"
    end
    local prefix_lower = (normalized_home .. sep):lower()
    if path_lower:sub(1, #prefix_lower) == prefix_lower then
      return "~" .. path:sub(#normalized_home + 1)
    end
  else
    if path == normalized_home then
      return "~"
    end
    local prefix = normalized_home .. sep
    if path:sub(1, #prefix) == prefix then
      return "~" .. path:sub(#normalized_home + 1)
    end
  end

  return path
end

local function normalize_special_key(value, default)
  if value == nil then
    return default
  end
  if value == false then
    return nil
  end
  if type(value) == "string" then
    local trimmed = value:gsub("^%s*(.-)%s*$", "%1")
    if trimmed == "" then
      return nil
    end
    return trimmed
  end
  if type(value) == "table" then
    local seq = {}
    for _, item in ipairs(value) do
      if type(item) == "string" then
        local trimmed = item:gsub("^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
          table.insert(seq, trimmed)
        end
      end
    end
    if #seq == 0 then
      return nil
    end
    return seq
  end
  return default
end

local function truncate_long_folder_names(path, max_folder_length)
  if not max_folder_length or max_folder_length <= 0 then
    return path
  end

  local separator = ya.target_family() == "windows" and "\\" or "/"
  local parts = {}

  for part in path:gmatch("[^" .. separator .. "]+") do
    if #part > max_folder_length then
      local keep_length = math.max(3, math.floor(max_folder_length * 0.4))
      local truncated = part:sub(1, keep_length) .. "..."
      table.insert(parts, truncated)
    else
      table.insert(parts, part)
    end
  end

  local result = table.concat(parts, separator)

  if path:sub(1, 1) == separator then
    result = separator .. result
  end

  return result
end

local function truncate_path(path, max_parts)
  max_parts = max_parts or 3
  local normalized_path = normalize_path(path)
  normalized_path = apply_home_alias(normalized_path)

  local parts = {}
  local separator = ya.target_family() == "windows" and "\\" or "/"

  if ya.target_family() == "windows" then
    local drive, rest = normalized_path:match("^([A-Za-z]:\\)(.*)$")
    if drive then
      table.insert(parts, drive)
      if rest and rest ~= "" then
        for part in rest:gmatch("[^\\]+") do
          table.insert(parts, part)
        end
      end
    else
      for part in normalized_path:gmatch("[^\\]+") do
        table.insert(parts, part)
      end
    end
  else
    if normalized_path:sub(1, 1) == "/" then
      table.insert(parts, "/")
      local rest = normalized_path:sub(2)
      if rest ~= "" then
        for part in rest:gmatch("[^/]+") do
          table.insert(parts, part)
        end
      end
    elseif normalized_path:sub(1, 1) == "~" then
      table.insert(parts, "~")
      local rest = normalized_path:sub(2)
      if rest:sub(1, 1) == "/" then
        rest = rest:sub(2)
      end
      if rest ~= "" then
        for part in rest:gmatch("[^/]+") do
          table.insert(parts, part)
        end
      end
    else
      for part in normalized_path:gmatch("[^/]+") do
        table.insert(parts, part)
      end
    end
  end

  if #parts > max_parts then
    local result_parts = {}
    local first_part = parts[1]

    if ya.target_family() == "windows" and first_part:match("^[A-Za-z]:\\$") then
      first_part = first_part:sub(1, -2)
    end

    if ya.target_family() ~= "windows" and first_part == "/" then
      table.insert(result_parts, "")
    else
      table.insert(result_parts, first_part)
    end

    table.insert(result_parts, "…")
    for i = #parts - max_parts + 2, #parts do
      table.insert(result_parts, parts[i])
    end

    local out = table.concat(result_parts, separator)
    if ya.target_family() ~= "windows" then
      out = out:gsub("^//+", "/")
    end
    return out
  else
    return normalized_path
  end
end

local function path_to_desc(path)
  local path_truncate_enabled = get_state_attr("path_truncate_enabled")
  local result_path = apply_home_alias(normalize_path(path))

  local path_truncate_long_names_enabled = get_state_attr("path_truncate_long_names_enabled")
  if path_truncate_long_names_enabled == true then
    local max_folder_length = get_state_attr("path_max_folder_name_length") or 20
    result_path = truncate_long_folder_names(result_path, max_folder_length)
  end

  if path_truncate_enabled == true then
    local max_depth = get_state_attr("path_max_depth") or 3
    result_path = truncate_path(result_path, max_depth)
  end

  return result_path
end

local function get_display_width(str)
  return ui.Line(str):width()
end

local function truncate_long_folder_names(path, max_folder_length)
  if not max_folder_length or max_folder_length <= 0 then
    return path
  end

  local separator = ya.target_family() == "windows" and "\\" or "/"
  local parts = {}
  local is_windows = ya.target_family() == "windows"

  if is_windows then
    local drive, rest = path:match("^([A-Za-z]:\\)(.*)$")
    if drive then
      table.insert(parts, drive:sub(1, -2))
      if rest and rest ~= "" then
        for part in rest:gmatch("[^\\]+") do
          if #part > max_folder_length then
            local keep_length = math.max(3, math.floor(max_folder_length * 0.4))
            local truncated = part:sub(1, keep_length) .. "..."
            table.insert(parts, truncated)
          else
            table.insert(parts, part)
          end
        end
      end
      return table.concat(parts, separator)
    end
  end

  for part in path:gmatch("[^" .. (separator == "\\" and "\\\\" or separator) .. "]+") do
    if #part > max_folder_length then
      local keep_length = math.max(3, math.floor(max_folder_length * 0.4))
      local truncated = part:sub(1, keep_length) .. "..."
      table.insert(parts, truncated)
    else
      table.insert(parts, part)
    end
  end

  local result = table.concat(parts, separator)

  if path:sub(1, 1) == separator then
    result = separator .. result
  end

  return result
end

local function path_to_desc_for_fzf(path)
  local fzf_path_truncate_enabled = get_state_attr("fzf_path_truncate_enabled")
  local result_path = apply_home_alias(normalize_path(path))

  local fzf_path_truncate_long_names_enabled = get_state_attr("fzf_path_truncate_long_names_enabled")
  if fzf_path_truncate_long_names_enabled == true then
    local max_folder_length = get_state_attr("fzf_path_max_folder_name_length") or 20
    result_path = truncate_long_folder_names(result_path, max_folder_length)
  end

  if fzf_path_truncate_enabled == true then
    local max_depth = get_state_attr("fzf_path_max_depth") or 5
    result_path = truncate_path(result_path, max_depth)
  end

  return result_path
end

local function path_to_desc_for_history(path)
  local history_fzf_path_truncate_enabled = get_state_attr("history_fzf_path_truncate_enabled")
  local result_path = apply_home_alias(normalize_path(path))

  local history_fzf_path_truncate_long_names_enabled = get_state_attr("history_fzf_path_truncate_long_names_enabled")
  if history_fzf_path_truncate_long_names_enabled == true then
    local max_folder_length = get_state_attr("history_fzf_path_max_folder_name_length") or 30
    result_path = truncate_long_folder_names(result_path, max_folder_length)
  end

  if history_fzf_path_truncate_enabled == true then
    local max_depth = get_state_attr("history_fzf_path_max_depth") or 5
    result_path = truncate_path(result_path, max_depth)
  end

  return result_path
end

local function format_bookmark_for_menu(tag, key)
  return tag
end

local function format_bookmark_for_fzf(tag, path, key, max_tag_width, max_path_width)
  local tag_width = math.max(max_tag_width, 15)
  local path_width = math.max(max_path_width or 30, 30)

  local formatted_tag = tag
  local tag_display_width = get_display_width(tag)
  if tag_display_width > tag_width then
    formatted_tag = tag:sub(1, tag_width - 3) .. "..."
  else
    formatted_tag = tag .. string.rep(" ", tag_width - tag_display_width)
  end

  local display_path = path_to_desc_for_fzf(path)
  local formatted_path = display_path
  local path_display_width = get_display_width(display_path)
  if path_display_width > path_width then
    formatted_path = display_path:sub(1, path_width - 3) .. "..."
  else
    formatted_path = display_path .. string.rep(" ", path_width - path_display_width)
  end

  local key_display = ""
  if key then
    if type(key) == "table" then
      key_display = table.concat(key, ",")
    elseif type(key) == "string" and #key > 0 then
      key_display = key
    else
      key_display = tostring(key)
    end
  end

  return formatted_tag .. "  " .. formatted_path .. "  " .. key_display
end

local function sort_bookmarks(bookmarks, key1, key2, reverse)
  reverse = reverse or false
  table.sort(bookmarks, function(x, y)
    if not x or not y then return false end
    local x_key1, y_key1 = x[key1], y[key1]
    local x_key2, y_key2 = x[key2], y[key2]
    if x_key1 == nil and y_key1 == nil then
      if x_key2 == nil and y_key2 == nil then
        return false
      elseif x_key2 == nil then
        return false
      elseif y_key2 == nil then
        return true
      else
        return tostring(x_key2) < tostring(y_key2)
      end
    elseif x_key1 == nil then
      return false
    elseif y_key1 == nil then
      return true
    else
      return tostring(x_key1) < tostring(y_key1)
    end
  end)
  if reverse then
    local n = #bookmarks
    for i = 1, math.floor(n / 2) do
      bookmarks[i], bookmarks[n - i + 1] = bookmarks[n - i + 1], bookmarks[i]
    end
  end
  return bookmarks
end

local action_save, action_jump, action_delete, which_find, fzf_find, fzf_find_for_rename, fzf_history

local function get_all_bookmarks()
  local all_b = {}
  local config_b = get_state_attr("config_bookmarks")
  local user_b = get_state_attr("bookmarks")

  for path, item in pairs(config_b) do
    all_b[path] = item
  end
  for path, item in pairs(user_b) do
    all_b[path] = item
  end
  return all_b
end

local function serialize_key_for_file(key)
  if type(key) == "table" then
    return table.concat(key, ",")
  elseif type(key) == "string" then
    return key
  else
    return tostring(key)
  end
end

local function deserialize_key_from_file(key_str)
  if not key_str or key_str == "" then
    return ""
  end

  key_str = key_str:gsub("^%s*(.-)%s*$", "%1")
  if key_str == "" then
    return ""
  end

  if key_str:find(",") then
    local seq = {}
    for token in key_str:gmatch("[^,%s]+") do
      token = token:gsub("^%s*(.-)%s*$", "%1")
      if token ~= "" then
        if token:match("^<.->$") then
          table.insert(seq, token)
        else
          for _, cp in utf8.codes(token) do
            table.insert(seq, utf8.char(cp))
          end
        end
      end
    end
    return seq
  end

  if key_str:match("^<.->$") then
    return key_str
  end

  if utf8.len(key_str) > 1 then
    local seq = {}
    for _, cp in utf8.codes(key_str) do
      table.insert(seq, utf8.char(cp))
    end
    return seq
  else
    return key_str
  end
end

local save_to_file = function(mb_path, bookmarks)
  ensure_directory(mb_path)
  local file = io.open(mb_path, "w")
  if file == nil then
    ya.notify { title = "Bookmarks Error", content = "Cannot create bookmark file: " .. mb_path, timeout = 2, level = "error" }
    return
  end
  local array = {}
  for _, item in pairs(bookmarks) do
    table.insert(array, item)
  end
  sort_bookmarks(array, "tag", "key", true)
  for _, item in ipairs(array) do
    local serialized_key = serialize_key_for_file(item.key)
    file:write(string.format("%s\t%s\t%s\n", item.tag, item.path, serialized_key))
  end
  file:close()
end

fzf_find = function()
  local mb_path = get_state_attr("path")
  local temp_bookmarks = get_temp_bookmarks()

  local permit = ui.hide()
  local temp_file_path = nil
  local cmd

  local all_perm_bookmarks = get_all_bookmarks()

  temp_file_path = os.tmpname()
  local temp_file = io.open(temp_file_path, "w")
  if temp_file then
    local all_fzf_items = {}
    local max_tag_width = 0
    local max_path_width = 0

    if temp_bookmarks and next(temp_bookmarks) then
      local temp_array = {}
      for _, item in pairs(temp_bookmarks) do
        if item and item.tag and item.path and item.key then table.insert(temp_array, item) end
      end
      sort_bookmarks(temp_array, "tag", "key", true)
      for _, item in ipairs(temp_array) do
        local tag_with_prefix = "[TEMP] " .. item.tag
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = tag_with_prefix, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(tag_with_prefix))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if all_perm_bookmarks and next(all_perm_bookmarks) then
      local perm_array = {}
      for _, item in pairs(all_perm_bookmarks) do
        table.insert(perm_array, item)
      end
      sort_bookmarks(perm_array, "tag", "key", true)
      for _, item in ipairs(perm_array) do
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = item.tag, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(item.tag))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if #all_fzf_items > 0 then
      for _, item in ipairs(all_fzf_items) do
        local formatted_line = format_bookmark_for_fzf(item.tag, item.path, item.key, max_tag_width, max_path_width)
        temp_file:write(formatted_line .. "\t" .. item.path .. "\n")
      end
      temp_file:close()
      cmd = string.format("fzf %s --with-nth=1 --prompt=\"Search > \" < \"%s\"", get_fzf_delimiter(), temp_file_path)
    else
      temp_file:close()
      cmd = "echo No bookmarks found | fzf --prompt=\"Search > \""
    end
  else
    cmd = "echo No bookmarks found | fzf --prompt=\"Search > \""
  end


  local handle = io.popen(cmd, "r")
  local result = ""
  if handle then
    result = string.gsub(handle:read("*all") or "", "^%s*(.-)%s*$", "%1")
    handle:close()
  end

  if temp_file_path then os.remove(temp_file_path) end
  permit:drop()

  if result and result ~= "" and result ~= "No bookmarks found" then
    local tab_pos = result:find("\t")
    if tab_pos then
      return result:sub(tab_pos + 1)
    end
  end
  return nil
end

fzf_find_for_rename = function()
  local mb_path = get_state_attr("path")
  local temp_bookmarks = get_temp_bookmarks()

  local permit = ui.hide()
  local temp_file_path = nil
  local cmd

  local all_perm_bookmarks = get_all_bookmarks()

  temp_file_path = os.tmpname()
  local temp_file = io.open(temp_file_path, "w")
  if temp_file then
    local all_fzf_items = {}
    local max_tag_width = 0
    local max_path_width = 0

    if temp_bookmarks and next(temp_bookmarks) then
      local temp_array = {}
      for _, item in pairs(temp_bookmarks) do
        if item and item.tag and item.path and item.key then table.insert(temp_array, item) end
      end
      sort_bookmarks(temp_array, "tag", "key", true)
      for _, item in ipairs(temp_array) do
        local tag_with_prefix = "[TEMP] " .. item.tag
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = tag_with_prefix, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(tag_with_prefix))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if all_perm_bookmarks and next(all_perm_bookmarks) then
      local perm_array = {}
      for _, item in pairs(all_perm_bookmarks) do
        table.insert(perm_array, item)
      end
      sort_bookmarks(perm_array, "tag", "key", true)
      for _, item in ipairs(perm_array) do
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = item.tag, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(item.tag))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if #all_fzf_items > 0 then
      for _, item in ipairs(all_fzf_items) do
        local formatted_line = format_bookmark_for_fzf(item.tag, item.path, item.key, max_tag_width, max_path_width)
        temp_file:write(formatted_line .. "\t" .. item.path .. "\n")
      end
      temp_file:close()
      cmd = string.format("fzf %s --with-nth=1 --prompt=\"Rename > \" < \"%s\"", get_fzf_delimiter(), temp_file_path)
    else
      temp_file:close()
      cmd = "echo No bookmarks found | fzf --prompt=\"Rename > \""
    end
  else
    cmd = "echo No bookmarks found | fzf --prompt=\"Rename > \""
  end

  local handle = io.popen(cmd, "r")
  local result = ""
  if handle then
    result = string.gsub(handle:read("*all") or "", "^%s*(.-)%s*$", "%1")
    handle:close()
  end

  if temp_file_path then os.remove(temp_file_path) end
  permit:drop()

  if result and result ~= "" and result ~= "No bookmarks found" then
    local tab_pos = result:find("\t")
    if tab_pos then
      return result:sub(tab_pos + 1)
    end
  end
  return nil
end

fzf_find_multi = function()
  local temp_bookmarks = get_temp_bookmarks()
  local user_bookmarks = get_state_attr("bookmarks")

  local permit = ui.hide()
  local temp_file_path = nil
  local cmd

  temp_file_path = os.tmpname()
  local temp_file = io.open(temp_file_path, "w")
  if temp_file then
    local all_fzf_items = {}
    local max_tag_width = 0
    local max_path_width = 0

    if temp_bookmarks and next(temp_bookmarks) then
      local temp_array = {}
      for _, item in pairs(temp_bookmarks) do
        if item and item.tag and item.path and item.key then table.insert(temp_array, item) end
      end
      sort_bookmarks(temp_array, "tag", "key", true)
      for _, item in ipairs(temp_array) do
        local tag_with_prefix = "[TEMP] " .. item.tag
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = tag_with_prefix, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(tag_with_prefix))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if user_bookmarks and next(user_bookmarks) then
      local user_array = {}
      for _, item in pairs(user_bookmarks) do
        table.insert(user_array, item)
      end
      sort_bookmarks(user_array, "tag", "key", true)
      for _, item in ipairs(user_array) do
        local display_path = path_to_desc_for_fzf(item.path)
        table.insert(all_fzf_items, { tag = item.tag, path = item.path, key = item.key or "" })
        max_tag_width = math.max(max_tag_width, get_display_width(item.tag))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end

    if #all_fzf_items > 0 then
      for _, item in ipairs(all_fzf_items) do
        local formatted_line = format_bookmark_for_fzf(item.tag, item.path, item.key, max_tag_width, max_path_width)
        temp_file:write(formatted_line .. "\t" .. item.path .. "\n")
      end
      temp_file:close()
      cmd = string.format("fzf --multi %s --with-nth=1 --prompt=\"Delete > \" < \"%s\"",
        get_fzf_delimiter(), temp_file_path)
    else
      temp_file:close()
      cmd = "echo No deletable bookmarks found | fzf --prompt=\"Delete > \""
    end
  else
    cmd = "echo No deletable bookmarks found | fzf --prompt=\"Delete > \""
  end

  local handle = io.popen(cmd, "r")
  local result = ""
  if handle then
    result = handle:read("*all") or ""
    handle:close()
  end

  if temp_file_path then os.remove(temp_file_path) end
  permit:drop()

  if result and result ~= "" and result ~= "No deletable bookmarks found" then
    local paths = {}
    for line in result:gmatch("[^\r\n]+") do
      line = string.gsub(line, "^%s*(.-)%s*$", "%1")
      if line ~= "" then
        local tab_pos = line:find("\t")
        if tab_pos then
          table.insert(paths, line:sub(tab_pos + 1))
        end
      end
    end
    return paths
  end
  return {}
end

fzf_history = function()
  local current_tab = get_current_tab_idx()
  local history = get_tab_history(current_tab)
  local current_path = normalize_path(get_current_dir_path())

  local filtered_history = {}
  if history then
    for _, path in ipairs(history) do
      if path ~= current_path then
        table.insert(filtered_history, path)
      end
    end
  end

  if not filtered_history or #filtered_history == 0 then
    return nil
  end

  local permit = ui.hide()
  local temp_file_path = os.tmpname()
  local temp_file = io.open(temp_file_path, "w")

  if temp_file then
    for i, path in ipairs(filtered_history) do
      local display_path = path_to_desc_for_history(path)
      local formatted_line = string.format("%2d. %s", i, display_path)
      temp_file:write(formatted_line .. "\t" .. path .. "\n")
    end
    temp_file:close()

    local cmd = string.format("fzf %s --with-nth=1 --prompt=\"History > \" < \"%s\"",
      get_fzf_delimiter(), temp_file_path)
    local handle = io.popen(cmd, "r")
    local result = ""
    if handle then
      result = string.gsub(handle:read("*all") or "", "^%s*(.-)%s*$", "%1")
      handle:close()
    end

    os.remove(temp_file_path)
    permit:drop()

    if result and result ~= "" then
      local tab_pos = result:find("\t")
      if tab_pos then
        return result:sub(tab_pos + 1)
      end
    end
  else
    permit:drop()
  end

  return nil
end

local create_special_menu_items = function()
  local special_items = {}
  local special_keys = get_state_attr("special_keys") or DEFAULT_SPECIAL_KEYS
  local create_temp_key = special_keys.create_temp
  if create_temp_key then
    table.insert(special_items, { desc = "Create temporary bookmark", on = create_temp_key, path = "__CREATE_TEMP__" })
  end

  local fuzzy_search_key = special_keys.fuzzy_search
  if fuzzy_search_key then
    table.insert(special_items, { desc = "Fuzzy search", on = fuzzy_search_key, path = "__FUZZY_SEARCH__" })
  end

  local current_tab = get_current_tab_idx()
  local history = get_tab_history(current_tab)
  local current_path = normalize_path(get_current_dir_path())

  local filtered_history = {}
  if history then
    for _, path in ipairs(history) do
      if path ~= current_path then
        table.insert(filtered_history, path)
      end
    end
  end

  local history_key = special_keys.history
  if history_key and filtered_history and #filtered_history > 0 then
    table.insert(special_items, { desc = "Directory history", on = history_key, path = "__HISTORY__" })
  end

  local previous_dir_key = special_keys.previous_dir
  if previous_dir_key and filtered_history and filtered_history[1] then
    local previous_dir = filtered_history[1]
    local display_path = path_to_desc(previous_dir)
    table.insert(special_items, { desc = "<- " .. display_path, on = previous_dir_key, path = previous_dir })
  end

  return special_items
end

which_find = function()
  local bookmarks = get_all_bookmarks()
  local temp_bookmarks = get_temp_bookmarks()

  local cands_static = create_special_menu_items()
  local cands_bookmarks = {}

  local all_bookmark_items = {}
  local max_tag_width = 0
  local max_path_width = 0

  if temp_bookmarks then
    for path, item in pairs(temp_bookmarks) do
      if item and item.tag and #item.tag ~= 0 then
        local tag_with_prefix = "[TEMP] " .. item.tag
        local display_path = path_to_desc(item.path or path)
        table.insert(all_bookmark_items,
          { tag = tag_with_prefix, path = item.path or path, key = item.key or "", is_temp = true })
        max_tag_width = math.max(max_tag_width, get_display_width(tag_with_prefix))
        max_path_width = math.max(max_path_width, get_display_width(display_path))
      end
    end
  end

  for path, item in pairs(bookmarks) do
    if item and item.tag and #item.tag ~= 0 then
      local display_path = path_to_desc(item.path or path)
      table.insert(all_bookmark_items,
        { tag = item.tag, path = item.path or path, key = item.key or "", is_temp = false })
      max_tag_width = math.max(max_tag_width, get_display_width(item.tag))
      max_path_width = math.max(max_path_width, get_display_width(display_path))
    end
  end

  for _, item in ipairs(all_bookmark_items) do
    if item.key and item.key ~= "" and
        (type(item.key) == "string" or (type(item.key) == "table" and #item.key > 0)) then
      local formatted_desc = format_bookmark_for_menu(item.tag, item.key)
      table.insert(cands_bookmarks, { desc = formatted_desc, on = item.key, path = item.path })
    end
  end

  sort_bookmarks(cands_bookmarks, "on", "desc", false)

  local cands = {}
  for _, item in ipairs(cands_static) do table.insert(cands, item) end
  for _, item in ipairs(cands_bookmarks) do table.insert(cands, item) end

  if #cands == #cands_static and #cands_bookmarks == 0 then
    ya.notify { title = "Bookmarks", content = "No bookmarks found", timeout = 1, level = "info" }
  end
  local idx = ya.which { cands = cands }
  if idx == nil then return nil end
  return cands[idx].path
end

which_find_deletable = function()
  local user_bookmarks = get_state_attr("bookmarks")
  local temp_bookmarks = get_temp_bookmarks()

  local cands_bookmarks = {}

  local all_bookmark_items = {}

  if temp_bookmarks then
    for path, item in pairs(temp_bookmarks) do
      if item and item.tag and #item.tag ~= 0 then
        local tag_with_prefix = "[TEMP] " .. item.tag
        table.insert(all_bookmark_items,
          { tag = tag_with_prefix, path = item.path or path, key = item.key or "", is_temp = true })
      end
    end
  end

  if user_bookmarks then
    for path, item in pairs(user_bookmarks) do
      if item and item.tag and #item.tag ~= 0 then
        table.insert(all_bookmark_items,
          { tag = item.tag, path = item.path or path, key = item.key or "", is_temp = false })
      end
    end
  end

  for _, item in ipairs(all_bookmark_items) do
    if item.key and item.key ~= "" and
        (type(item.key) == "string" or (type(item.key) == "table" and #item.key > 0)) then
      local formatted_desc = format_bookmark_for_menu(item.tag, item.key)
      table.insert(cands_bookmarks, { desc = formatted_desc, on = item.key, path = item.path })
    end
  end

  sort_bookmarks(cands_bookmarks, "on", "desc", false)

  if #cands_bookmarks == 0 then
    ya.notify { title = "Bookmarks", content = "No deletable bookmarks found", timeout = 1, level = "info" }
    return nil
  end

  local idx = ya.which { cands = cands_bookmarks }
  if idx == nil then return nil end
  return cands_bookmarks[idx].path
end

action_jump = function(path)
  if path == nil then return end

  local jump_notify = get_state_attr("jump_notify")
  local all_bookmarks = get_all_bookmarks()
  local temp_bookmarks = get_temp_bookmarks()

  if path == "__CREATE_TEMP__" then
    action_save(get_current_dir_path(), true)
    return
  elseif path == "__FUZZY_SEARCH__" then
    local selected_path = fzf_find()
    if selected_path then action_jump(selected_path) end
    return
  elseif path == "__HISTORY__" then
    local selected_path = fzf_history()
    if selected_path then action_jump(selected_path) end
    return
  end

  local bookmark = temp_bookmarks[path] or all_bookmarks[path]
  if not bookmark then
    ya.emit("cd", { path })
    if jump_notify then ya.notify { title = "Bookmarks", content = 'Jump to "' .. path_to_desc(path) .. '"', timeout = 1, level = "info" } end
    return
  end

  local tag = bookmark.tag
  local is_temp = temp_bookmarks[path] ~= nil

  ya.emit("cd", { path })

  if jump_notify then
    local prefix = is_temp and "[TEMP] " or ""
    ya.notify { title = "Bookmarks", content = 'Jump to "' .. prefix .. tag .. '"', timeout = 1, level = "info" }
  end
end

local function parse_keys_input(input)
  if not input or input == "" then return {} end
  local seq = {}
  for token in input:gmatch("[^,%s]+") do
    token = token:gsub("^%s*(.-)%s*$", "%1")
    if token ~= "" then
      if token:match("^<.->$") then
        table.insert(seq, token)
      else
        for _, cp in utf8.codes(token) do
          table.insert(seq, utf8.char(cp))
        end
      end
    end
  end
  return seq
end

local function format_keys_for_display(keys)
  if type(keys) == "table" then
    return table.concat(keys, ",")
  elseif type(keys) == "string" then
    return keys
  else
    return ""
  end
end

local function _seq_from_key(k)
  if type(k) == "table" then
    local out = {}
    for _, t in ipairs(k) do
      if t:match("^<.->$") then
        table.insert(out, t)
      else
        for _, cp in utf8.codes(t) do
          table.insert(out, utf8.char(cp))
        end
      end
    end
    return out
  elseif type(k) == "string" then
    return parse_keys_input(k)
  else
    return {}
  end
end

local function _seq_equal(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function _seq_is_prefix(short, long)
  if #short >= #long then return false end
  for i = 1, #short do if short[i] ~= long[i] then return false end end
  return true
end

local function _seq_to_string(seq)
  return table.concat(seq, ",")
end

local function find_path_by_key_sequence(seq)
  if not seq or #seq == 0 then return nil end

  local function matches(candidate)
    if candidate == nil or candidate == "" then return false end
    local candidate_seq = _seq_from_key(candidate)
    if #candidate_seq == 0 then return false end
    return _seq_equal(seq, candidate_seq)
  end

  for _, item in ipairs(create_special_menu_items() or {}) do
    if matches(item.on) then
      return item.path
    end
  end

  local temp = get_temp_bookmarks()
  for path, item in pairs(temp or {}) do
    if matches(item.key) then
      return path
    end
  end

  local bookmarks = get_all_bookmarks()
  for path, item in pairs(bookmarks or {}) do
    if matches(item.key) then
      return path
    end
  end

  return nil
end

local function jump_by_key_spec(spec)
  local cleaned = (spec or ""):gsub("^%s*(.-)%s*$", "%1")
  if cleaned == "" then
    ya.notify { title = "Bookmarks", content = "Missing key sequence", timeout = 1, level = "warn" }
    return false
  end

  local seq = parse_keys_input(cleaned)
  if #seq == 0 then
    ya.notify { title = "Bookmarks", content = "Missing key sequence", timeout = 1, level = "warn" }
    return false
  end

  local path = find_path_by_key_sequence(seq)
  if not path then
    ya.notify { title = "Bookmarks", content = "Bookmark not found for key: " .. _seq_to_string(seq), timeout = 1, level = "info" }
    return false
  end

  action_jump(path)
  return true
end

local generate_key = function()
  local keys = get_state_attr("keys")
  local key2rank = get_state_attr("key2rank")
  local bookmarks = get_all_bookmarks()
  local temp_bookmarks = get_temp_bookmarks()

  local mb = {}
  for _, item in pairs(bookmarks) do
    if item and item.key then
      if type(item.key) == "string" and #item.key == 1 then
        table.insert(mb, item.key)
      elseif type(item.key) == "table" then
        for _, k in ipairs(item.key) do
          if type(k) == "string" and #k == 1 then
            table.insert(mb, k)
          end
        end
      end
    end
  end
  if temp_bookmarks then
    for _, item in pairs(temp_bookmarks) do
      if item and item.key then
        if type(item.key) == "string" and #item.key == 1 then
          table.insert(mb, item.key)
        elseif type(item.key) == "table" then
          for _, k in ipairs(item.key) do
            if type(k) == "string" and #k == 1 then
              table.insert(mb, k)
            end
          end
        end
      end
    end
  end
  if #mb == 0 then return keys[1] end

  table.sort(mb, function(a, b) return (key2rank[a] or 999) < (key2rank[b] or 999) end)
  local idx = 1
  for _, key in ipairs(keys) do
    if idx > #mb or (key2rank[key] or 999) < (key2rank[mb[idx]] or 999) then return key end
    idx = idx + 1
  end
  return nil
end

action_save = function(path, is_temp)
  if path == nil or #path == 0 then return end

  local mb_path = get_state_attr("path")
  local all_bookmarks = get_all_bookmarks()
  local temp_bookmarks = get_temp_bookmarks()
  local path_obj
  if is_temp and temp_bookmarks and temp_bookmarks[path] then
    path_obj = temp_bookmarks[path]
  else
    path_obj = all_bookmarks[path] or (temp_bookmarks and temp_bookmarks[path])
  end
  local tag = path_obj and path_obj.tag or path:match(".*[\\/]([^\\/]+)[\\/]?$")

  while true do
    local title = is_temp and "Tag ⟨alias name⟩ [TEMPORARY]" or "Tag ⟨alias name⟩"
    local value, event = ya.input({ title = title, value = tag, pos = { "top-center", y = 3, w = 40 } })
    if event ~= 1 then return end
    tag = value or ''
    if #tag == 0 then
      ya.notify { title = "Bookmarks", content = "Empty tag", timeout = 1, level = "info" }
    else
      local tag_obj = nil
      for _, item in pairs(all_bookmarks) do
        if item.tag == tag then
          tag_obj = item; break
        end
      end
      if not tag_obj and temp_bookmarks then
        for _, item in pairs(temp_bookmarks) do
          if item.tag == tag then
            tag_obj = item; break
          end
        end
      end
      if tag_obj == nil or tag_obj.path == path then break end
      ya.notify { title = "Bookmarks", content = "Duplicated tag", timeout = 1, level = "info" }
    end
  end

  local key = path_obj and path_obj.key or generate_key()
  local key_display = format_keys_for_display(key)

  while true do
    local value, event = ya.input({
      title = "Keys ⟨space, comma or empty separator⟩",
      value = key_display,
      pos = { "top-center", y = 3, w = 50 }
    })
    if event ~= 1 then return end

    local input_str = value or ""
    if input_str == "" then
      key = ""
      break
    end

    local parsed_keys = parse_keys_input(input_str)
    if #parsed_keys == 0 then
      key = ""
      break
    elseif #parsed_keys == 1 then
      key = parsed_keys[1]
    else
      key = parsed_keys
    end

    local new_seq = _seq_from_key(key)
    local conflict, conflict_seq

    local function check(items)
      for _, item in pairs(items or {}) do
        if item and item.key and item.path ~= path then
          local exist = _seq_from_key(item.key)
          if #exist > 0 then
            if _seq_equal(new_seq, exist) then
              conflict, conflict_seq = "duplicate", exist; return true
            end
            if _seq_is_prefix(new_seq, exist) or _seq_is_prefix(exist, new_seq) then
              conflict, conflict_seq = "prefix", exist; return true
            end
          end
        end
      end
      return false
    end

    if check(all_bookmarks) or check(temp_bookmarks) then
      local msg = (conflict == "duplicate")
        and ("Duplicated key sequence: " .. _seq_to_string(new_seq))
        or ("Ambiguous with existing sequence: " .. _seq_to_string(conflict_seq))
      ya.notify { title = "Bookmarks", content = msg, timeout = 2, level = "info" }
      key_display = input_str
    else
      break
    end
  end

  if is_temp then
    set_temp_bookmarks(path, { tag = tag, path = path, key = key })
    ya.notify { title = "Bookmarks", content = '[TEMP] "' .. tag .. '" saved', timeout = 1, level = "info" }
  else
    set_bookmarks(path, { tag = tag, path = path, key = key })
    local user_bookmarks = get_state_attr("bookmarks")
    save_to_file(mb_path, user_bookmarks)
    ya.notify { title = "Bookmarks", content = '"' .. tag .. '" saved', timeout = 1, level = "info" }
  end
end

action_delete = function(path)
  if path == nil then return end

  local mb_path = get_state_attr("path")
  local user_bookmarks = get_state_attr("bookmarks")
  local temp_bookmarks = get_temp_bookmarks()
  local bookmark = temp_bookmarks[path] or user_bookmarks[path]

  if not bookmark then
    ya.notify { title = "Bookmarks", content = 'Cannot delete: Not a user or temp bookmark', timeout = 2, level = "warn" }
    return
  end
  local tag = bookmark.tag
  local is_temp = temp_bookmarks[path] ~= nil

  if is_temp then
    set_temp_bookmarks(path, nil)
    ya.notify { title = "Bookmarks", content = '[TEMP] "' .. tag .. '" deleted', timeout = 1, level = "info" }
  else
    set_bookmarks(path, nil)
    local updated_user_bookmarks = get_state_attr("bookmarks")
    save_to_file(mb_path, updated_user_bookmarks)
    ya.notify { title = "Bookmarks", content = '"' .. tag .. '" deleted', timeout = 1, level = "info" }
  end
end

action_delete_multi = function(paths)
  if not paths or #paths == 0 then return end

  local mb_path = get_state_attr("path")
  local user_bookmarks = get_state_attr("bookmarks")
  local temp_bookmarks = get_temp_bookmarks()

  local deleted_count = 0
  local deleted_temp_count = 0
  local deleted_names = {}
  local not_found_count = 0

  for _, path in ipairs(paths) do
    local bookmark = temp_bookmarks[path] or user_bookmarks[path]
    if bookmark then
      local tag = bookmark.tag
      local is_temp = temp_bookmarks[path] ~= nil

      if is_temp then
        set_temp_bookmarks(path, nil)
        deleted_temp_count = deleted_temp_count + 1
        table.insert(deleted_names, "[TEMP] " .. tag)
      else
        set_bookmarks(path, nil)
        deleted_count = deleted_count + 1
        table.insert(deleted_names, tag)
      end
    else
      not_found_count = not_found_count + 1
    end
  end

  if deleted_count > 0 then
    local updated_user_bookmarks = get_state_attr("bookmarks")
    save_to_file(mb_path, updated_user_bookmarks)
  end

  local total_deleted = deleted_count + deleted_temp_count
  local message_parts = {}

  if total_deleted > 0 then
    table.insert(message_parts, string.format("Deleted %d bookmark(s)", total_deleted))
    if deleted_count > 0 and deleted_temp_count > 0 then
      table.insert(message_parts, string.format("(%d permanent, %d temporary)", deleted_count, deleted_temp_count))
    elseif deleted_temp_count > 0 then
      table.insert(message_parts, "(temporary)")
    end
  end

  if not_found_count > 0 then
    table.insert(message_parts, string.format("%d not found", not_found_count))
  end

  local final_message = table.concat(message_parts, ", ")
  if total_deleted > 0 then
    ya.notify { title = "Bookmarks", content = final_message, timeout = 2, level = "info" }
  else
    ya.notify { title = "Bookmarks", content = "No bookmarks were deleted", timeout = 1, level = "warn" }
  end
end

local action_delete_all = function(temp_only)
  local mb_path = get_state_attr("path")
  local title = temp_only and "Delete all temporary bookmarks? ⟨y/n⟩" or "Delete all user bookmarks? ⟨y/n⟩"
  local value, event = ya.input({ title = title, pos = { "top-center", y = 3, w = 45 } })
  if event ~= 1 or string.lower(value or "") ~= "y" then
    ya.notify { title = "Bookmarks", content = "Cancel delete", timeout = 1, level = "info" }
    return
  end

  if temp_only then
    set_state_attr("temp_bookmarks", {})
    ya.notify { title = "Bookmarks", content = "All temporary bookmarks deleted", timeout = 1, level = "info" }
  else
    set_state_attr("bookmarks", {})
    save_to_file(mb_path, {})
    ya.notify { title = "Bookmarks", content = "All user-created bookmarks deleted", timeout = 1, level = "info" }
  end
end

return {
  setup = function(state, options)
    local default_path = (ya.target_family() == "windows" and os.getenv("APPDATA") .. "\\yazi\\config\\bookmarks") or
        (os.getenv("HOME") .. "/.config/yazi/bookmarks")
    local bookmarks_path = options.bookmarks_path or options.path
    if type(bookmarks_path) == "string" and bookmarks_path ~= '' then
        state.path = bookmarks_path
    else
        state.path = default_path
    end
    state.jump_notify = options.jump_notify == nil and false or options.jump_notify
    state.home_alias_enabled = options.home_alias_enabled == nil and true or options.home_alias_enabled
    state.path_truncate_enabled = options.path_truncate_enabled == nil and false or options.path_truncate_enabled
    state.path_max_depth = options.path_max_depth or 3
    state.fzf_path_truncate_enabled = options.fzf_path_truncate_enabled == nil and false or
        options.fzf_path_truncate_enabled
    state.fzf_path_max_depth = options.fzf_path_max_depth or 5
    state.path_truncate_long_names_enabled = options.path_truncate_long_names_enabled == nil and false or
        options.path_truncate_long_names_enabled
    state.fzf_path_truncate_long_names_enabled = options.fzf_path_truncate_long_names_enabled == nil and false or
        options.fzf_path_truncate_long_names_enabled
    state.path_max_folder_name_length = options.path_max_folder_name_length or 20
    state.fzf_path_max_folder_name_length = options.fzf_path_max_folder_name_length or 20

    state.history_size = options.history_size or 10
    state.history_fzf_path_truncate_enabled = options.history_fzf_path_truncate_enabled == nil and false or
        options.history_fzf_path_truncate_enabled
    state.history_fzf_path_max_depth = options.history_fzf_path_max_depth or 5
    state.history_fzf_path_truncate_long_names_enabled = options.history_fzf_path_truncate_long_names_enabled == nil and
        false or
        options.history_fzf_path_truncate_long_names_enabled
    state.history_fzf_path_max_folder_name_length = options.history_fzf_path_max_folder_name_length or 30

    local special_keys_options = options.special_keys or {}
    local special_keys = {}
    for name, default_key in pairs(DEFAULT_SPECIAL_KEYS) do
      local normalized = normalize_special_key(special_keys_options[name], default_key)
      if normalized ~= nil then
        special_keys[name] = normalized
      end
    end
    state.special_keys = special_keys

    ensure_directory(state.path)
    local keys = options.keys or "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    state.keys, state.key2rank = {}, {}
    for i = 1, #keys do
      local char = keys:sub(i, i)
      table.insert(state.keys, char)
      state.key2rank[char] = i
    end

    local function convert_simple_bookmarks(simple_bookmarks)
      local converted = {}
      local path_sep = package.config:sub(1, 1)
      local home_path = ya.target_family() == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")

      for _, bookmark in ipairs(simple_bookmarks or {}) do
        local path = bookmark.path
        if path:sub(1, 1) == "~" then
          path = home_path .. path:sub(2)
        end

        if ya.target_family() == "windows" then
          path = path:gsub("/", "\\")
        else
          path = path:gsub("\\", "/")
        end

        if path:sub(-1) ~= path_sep then
          path = path .. path_sep
        end

        converted[path] = {
          tag = bookmark.tag,
          path = path,
          key = bookmark.key
        }
      end

      return converted
    end

    state.config_bookmarks = {}

    local bookmarks_to_process = options.bookmarks or {}
    if #bookmarks_to_process > 0 and bookmarks_to_process[1].tag then
      state.config_bookmarks = convert_simple_bookmarks(bookmarks_to_process)
    else
      for _, item in pairs(bookmarks_to_process) do
        state.config_bookmarks[item.path] = { tag = item.tag, path = item.path, key = item.key }
      end
    end

    local user_bookmarks = {}
    local file = io.open(state.path, "r")
    if file ~= nil then
      for line in file:lines() do
        local tag, path, key_str = string.match(line, "(.-)\t(.-)\t(.*)")
        if tag and path then
          local key = deserialize_key_from_file(key_str or "")
          user_bookmarks[path] = { tag = tag, path = path, key = key }
        end
      end
      file:close()
    end
    state.bookmarks = user_bookmarks
    save_to_file(state.path, state.bookmarks)

    state.temp_bookmarks = {}
    state.directory_history = {}
    state.last_paths = {}
    state.initialized_tabs = {}

    ps.sub("cd", function(body)
      local tab = body.tab or cx.tabs.idx
      local new_path = normalize_path(tostring(cx.active.current.cwd))

      if not state.initialized_tabs[tab] then
        state.last_paths[tab] = new_path
        state.initialized_tabs[tab] = true
        return
      end

      local previous_path = state.last_paths[tab]

      if previous_path and previous_path ~= new_path then
        add_to_history(tab, previous_path)
      end

      state.last_paths[tab] = new_path
    end)
  end,

  entry = function(self, jobs)
    local args = jobs.args or {}
    local action = args[1]

    if type(action) == "string" and action:sub(1, 9):lower() == "jump_key_" then
      jump_by_key_spec(action:sub(10))
      return
    end

    if not action then return end

    if action == "save" then
      if is_hovered_directory() then
        action_save(get_hovered_path(), false)
      else
        ya.notify { title = "Bookmarks", content = "Selected item is not a directory", timeout = 2, level = "warn" }
      end
    elseif action == "save_cwd" then
      action_save(get_current_dir_path(), false)
    elseif action == "save_temp" then
      if is_hovered_directory() then
        action_save(get_hovered_path(), true)
      else
        ya.notify { title = "Bookmarks", content = "Selected item is not a directory", timeout = 2, level = "warn" }
      end
    elseif action == "save_cwd_temp" then
      action_save(get_current_dir_path(), true)
    elseif action == "delete_by_key" then
      action_delete(which_find_deletable())
    elseif action == "delete_by_fzf" then
      action_delete_multi(fzf_find_multi())
    elseif action == "delete_multi_by_fzf" then
      action_delete_multi(fzf_find_multi())
    elseif action == "delete_all" then
      action_delete_all(false)
    elseif action == "delete_all_temp" then
      action_delete_all(true)
    elseif action == "jump_by_key" then
      action_jump(which_find())
    elseif action == "jump_by_fzf" then
      action_jump(fzf_find())
    elseif action == "rename_by_key" then
      local path = which_find()
      if path then
        local temp_b = get_temp_bookmarks()
        action_save(path, temp_b[path] ~= nil)
      end
    elseif action == "rename_by_fzf" then
      local path = fzf_find_for_rename()
      if path then
        local temp_b = get_temp_bookmarks()
        action_save(path, temp_b[path] ~= nil)
      end
    end
  end,
}
