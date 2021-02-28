-- Constants

local USER_PERE_DIR = os.getenv("HOME") .. "/.pere"
local BACKGROUNDS_FILE = USER_PERE_DIR .. "/backgrounds"
local CURRENT_BACKGROUND_FILE = USER_PERE_DIR .. "/current_background"

-- Helper functions

local function get_backgrounds()
  local backgrounds = {}

  for background in io.lines(BACKGROUNDS_FILE) do
    backgrounds[background] = true
  end

  return backgrounds
end

local function remove_dots(path)
  assert(not path:find('\\/'))
  assert(path:sub(1, 1) == '/')

  local components = {}
  while true do
    local component, new_path = path:match('^/([^/]*)(/.*)$')
    if not component then
      if path ~= "" then
        table.insert(components, path:sub(2))
      end
      break
    elseif component == '..' then
      table.remove(components)
    elseif component ~= '.' and component ~= '' then
      table.insert(components, component)
    end
    path = new_path
  end

  return '/' .. table.concat(components, '/')
end

local function absolute_path(relative_path)
  local absolute_path = relative_path

  if relative_path:sub(1, 1) ~= '/' then
    absolute_path = os.getenv("PWD") .. "/" .. relative_path
  end

  absolute_path = remove_dots(absolute_path)
  return absolute_path
end

local function write_backgrounds(backgrounds, mode)
  local backgrounds_file = io.open(BACKGROUNDS_FILE, mode)
  for background in pairs(backgrounds) do
    backgrounds_file:write(background, "\n")
  end
  backgrounds_file:close()
end

local function get_num_backgrounds()
  local num_backgrounds = 0
  if not os.execute('test -r ' .. BACKGROUNDS_FILE) then
    return 0
  end

  for _ in io.lines(BACKGROUNDS_FILE) do
    num_backgrounds = num_backgrounds + 1
  end
  return num_backgrounds
end

local function format_backgrounds(...)
  local result = {}
  for _,v in ipairs({...}) do
    result[absolute_path(v)] = true
  end
  return result
end

local function set_to_list(set)
  local result = {}
  for v in pairs(set) do
    table.insert(result, v)
  end
  return result
end

local function check_user_pere_dir()
  local dir_exists = os.execute('test -d ' .. USER_PERE_DIR)
  if not dir_exists then
    os.execute('mkdir ' .. USER_PERE_DIR)
  end
end

local function args_list_wrapper(fn)
  return function(...)
    return fn(format_backgrounds(...))
  end
end

-- Methods

local function set_background(background)
  assert(not background:find("'"))
  os.execute("feh --bg-max '" .. background .. "'")
  local current_background_file = io.open(CURRENT_BACKGROUND_FILE, "w")
  current_background_file:write(background, '\n')
  current_background_file:close()
end

local function add_backgrounds(new_backgrounds)
  local backgrounds = get_backgrounds()
  for new_background in pairs(new_backgrounds) do
    if backgrounds[new_background] then
      new_backgrounds[new_background] = nil
    end
  end

  if next(new_backgrounds) ~= nil then
    write_backgrounds(new_backgrounds, "a")
  end
end

local function remove_backgrounds(backgrounds_to_delete)
  local backgrounds = get_backgrounds()
  local dirty = false

  for background_to_delete in pairs(backgrounds_to_delete) do
    if not dirty and backgrounds[background_to_delete] then
      dirty = true
    end
    backgrounds[background_to_delete] = nil
  end

  if dirty then
    write_backgrounds(backgrounds, "w")
  end
end

local function list_backgrounds()
  local backgrounds = get_backgrounds()
  backgrounds = set_to_list(backgrounds)
  table.sort(backgrounds)
  io.write(table.concat(backgrounds, '\n'), '\n')
end


local function print_current_background()
  local current_background_file = io.open(CURRENT_BACKGROUND_FILE)
  if not current_background_file then
    io.stderr:write([[ERROR: current background file not initialized;
                    This operation won't make sense until you use pere to set
                    the background]], '\n')
    os.exit(1)
  end

  local current_background = current_background_file:read()
  current_background_file:close()

  io.write(current_background, '\n')
end

local function query_backgrounds(backgrounds_to_query)
  local backgrounds_to_add = {}
  for background in pairs(backgrounds_to_query) do
    set_background(background)
    io.stdout:write("Add to backgrounds? (y/n) ")
    local answer = io.read()
    if answer == "y" then
      backgrounds_to_add[background] = true
    end
  end

  if next(backgrounds_to_add) ~= nil then
    add_backgrounds(backgrounds_to_add)
  end
end

local function set_random_background()
  local num_backgrounds = get_num_backgrounds()
  if num_backgrounds == 0 then
    io.stderr:write("ERROR: no backgrounds\n")
    os.exit(1)
  end

  math.randomseed(os.time())
  local chosen_num = math.random(0, num_backgrounds-1)

  local backgrounds_file = io.open(BACKGROUNDS_FILE, mode)
  for _ = 0,chosen_num-1 do
    backgrounds_file:read()
  end

  local chosen_background = backgrounds_file:read()
  set_background(chosen_background)
end

-- Main

local function main()
  check_user_pere_dir()
  methods = {add = args_list_wrapper(add_backgrounds),
             remove = args_list_wrapper(remove_backgrounds),
             list = list_backgrounds,
             current = print_current_background,
             check = args_list_wrapper(query_backgrounds),
             random = set_random_background,
             set = set_background,
            }

  if #arg == 0 then
    io.stderr:write([[usage:
                      pere add BACKGROUND_FILES
                      pere remove BACKGROUND_FILES
                      pere list
                      pere current
                      pere check BACKGROUND_FILES
                      pere random
                      pere set BACKGROUND_FILE]], '\n')
    os.exit(1)
  end

  local method_name = arg[1]
  table.remove(arg, 1)
  methods[method_name](table.unpack(arg))
end

main()
