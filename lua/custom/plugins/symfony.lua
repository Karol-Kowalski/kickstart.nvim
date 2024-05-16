--xml = require 'LuaXML'

--local actions = require 'telescope.actions'
--local action_state = require 'telescope.actions.state'

--require('telescope').setup {
--  pickers = {
--   find_files = {
--      on_input_filter_cb = function(prompt)
--       local find_colon = string.find(prompt, '::')
--        if find_colon then
--         local ret = string.sub(prompt, 1, find_colon - 1)
--          vim.schedule(function()
--            local prompt_bufnr = vim.api.nvim_get_current_buf()
--            local picker = action_state.get_current_picker(prompt_bufnr)
--            local lnum = tonumber(prompt:sub(find_colon + 1))
--            if type(lnum) == 'number' then
--              local win = picker.previewer.state.winid
--              local bufnr = picker.previewer.state.bufnr
--              local line_count = vim.api.nvim_buf_line_count(bufnr)
--              vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(lnum, line_count)), 0 })
--            end
--          end)
--          return { prompt = ret }
--        end
--      end,
--      attach_mappings = function()
--        actions.select_default:enhance {
--          post = function()
--            -- if we found something, go to line
--            local prompt = action_state.get_current_line()
--            local find_colon = string.find(prompt, '::')
--            if find_colon then
--              local lnum = tonumber(prompt:sub(find_colon + 1))
--              vim.api.nvim_win_set_cursor(0, { lnum, 0 })
--            end
--          end,
--        }
--        return true
--      end,
--    },
--  },
--}

local symfony = {}

local function get_git_root()
  local output = vim.fn.system 'git rev-parse --show-toplevel'
  local rescode = vim.v.shell_error

  if rescode == 0 then
    return vim.fn.trim(output)
  end
end

local function read_project_file(file_path)
  local f = io.open(get_git_root() .. file_path, 'r')
  if not f then
    return nil
  end
  local content = f:read '*all'
  f:close()

  return content
end

local function parse_json(json_string)
  local parser = require 'dkjson'
  return parser.decode(json_string)
end

local function current_file_extension()
  local current_file = vim.fn.expand '%:t'
  local _, _, extension = string.find(current_file, '%.([^%.]+)$')
  return extension
end

local function is_file_yml()
  local extension = current_file_extension()
  if extension == 'yml' or extension == 'yaml' then
    return true
  end
end

local function convert_from_namespace_autoload(namespace)
  local json_file = read_project_file '/composer.json'
  local decoded_content = parse_json(json_file)

  local prefix, affix
  for key, value in pairs(decoded_content.autoload['psr-4']) do
    if string.find(namespace, '^' .. key) then
      prefix = value
      _, affix = string.match(namespace, '^(' .. key .. ')([a-zA-Z\\]+)')
      return prefix .. affix
    end
  end

  return namespace
end

local function prepare_class_from_namespace(namespace)
  return string.gsub(convert_from_namespace_autoload(namespace), '\\', '/')
end

local function prepare_right_regexp(linecontent)
  if string.find(linecontent, '^class: ') then
    return '(class): *([a-zA-Z._\\]*):*([a-zA-Z_]*)'
  elseif string.find(linecontent, '^controller: ') then
    return '(controller): *([a-zA-Z._\\]*):*([a-zA-Z_]*)'
  elseif string.find(linecontent, '^parent: ') then
    return '(parent): *([a-zA-Z._\\]*)'
  elseif string.find(linecontent, '^([a-zA-Z\\._\\]*)') then
    return '^([a-zA-Z._\\]*):? *@?([a-zA-Z._\\]*)'
  else
    return nil
  end
end

local xml = require 'xml2lua'
local handler = require 'xmlhandler.tree'
local parser = xml.parser(handler)
parser:parse(read_project_file '/var/cache/dev/App_KernelDevDebugContainer.xml')

local function find_class_by_service_name(service_name)
  for _, service in pairs(handler.root.container.services.service) do
    if service_name == service._attr.id then
      if service._attr.class then
        print(service._attr.class)
        return service._attr.class
      elseif service._attr.alias then
        return find_class_by_service_name(service._attr.alias)
      end
    end
  end
end

local function generate_prompt(prefix, class, method)
  local prompt
  if prefix == 'class' or prefix == 'parent' then
    prompt = class
  elseif prefix == 'controller' then
    prompt = class .. '::' .. method
  else
    prompt = class
  end

  return prompt
end

symfony.SfJmp2controllerFromRouting = function()
  if is_file_yml() then
    local linecontent = vim.fn.trim(vim.api.nvim_get_current_line())
    linecontent = string.gsub(linecontent, '["\']', '')

    local regexp = prepare_right_regexp(linecontent)
    if not regexp then
      return
    end

    local prefix, service, method = string.match(linecontent, regexp)

    --print(prefix .. ' ' .. service)
    local class
    if prefix == 'class' then
      class = service
    --elseif prefix == 'parent' or prefix == 'controller' then
    --  class = find_class_by_service_name(service)
    elseif not service then
      class = find_class_by_service_name(prefix)
    else
      class = find_class_by_service_name(service)
    end

    if not class then
      return
    end

    class = prepare_class_from_namespace(class)

    local prompt = generate_prompt(prefix, class, method)

    local telescope = require 'telescope.builtin'
    telescope.find_files { default_text = prompt }
  end
end

vim.keymap.set('n', '<C-q>', symfony.SfJmp2controllerFromRouting, { desc = 'find method in controller' })

return symfony
