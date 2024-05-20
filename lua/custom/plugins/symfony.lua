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

local parser = require 'dkjson'
local xml = require 'xml2lua'
local handler = require 'xmlhandler.tree'
local xml_parser = xml.parser(handler)

local namespaces = {
  psr4_cache = {},
  get_class_path_from_autoloader = function(self) end,
  get_class_path_from_namespace = function(self, namespace)
    if next(self.psr4_cache) == nil then
      self:load()
    end

    local prefix, affix
    for key, value in pairs(self.psr4_cache) do
      if string.find(namespace, '^' .. key) then
        prefix = value
        _, affix = string.match(namespace, '^(' .. key .. ')([a-zA-Z\\]+)')

        return string.gsub(prefix .. affix, '\\', '/')
      end
    end
  end,
  load = function(self)
    local main_composer_file_path = self.setup.project_composer_path .. '/composer.json'

    local main_composer_data = self.loader:load_json_file(main_composer_file_path)
    if not main_composer_data then
      --print 'Error laoding main composer.json'
      return
    end

    local main_namespaces = self.extract_psr4_namespaces(main_composer_data.autload)
    for namespace, path in pairs(main_namespaces) do
      self.psr4_cache[namespace] = path
    end

    for vendor, _ in pairs(main_composer_data.require or {}) do
      local package_path = '/' .. self.setup.vendor_path .. '/' .. vendor .. '/composer.json'
      local package_data = self.loader:load_json_file(package_path)
      if package_data then
        local package_namespaces = self.extract_psr4_namespaces(package_data.autoload)
        for namespace, path in pairs(package_namespaces) do
          self.psr4_cache[namespace] = self.setup.vendor_path .. '/' .. vendor .. '/' .. path
        end
      else
        --print('Error loading package composer.json for:', vendor)
      end
    end
  end,
  extract_psr4_namespaces = function(autoload)
    local psr4 = autoload and autoload['psr-4']
    if not psr4 then
      return {}
    end
    return psr4
  end,
  get_packages = function() end,
  loader = {},
  with_loader = function(self, loader)
    self.loader = loader
  end,
  setup = {
    vendor_path = 'vendor',
    project_composer_path = '',
  },
}

local File_loader = {}
File_loader.__index = File_loader

function File_loader.new()
  local self = setmetatable({}, File_loader)

  self.file_path = ''

  return self
end

function File_loader.get_git_root()
  local output = vim.fn.system 'git rev-parse --show-toplevel'
  local rescode = vim.v.shell_error

  if rescode == 0 then
    return vim.fn.trim(output)
  end
end
function File_loader:read_project_file(path)
  local f = io.open(self.get_git_root() .. path, 'r')
  if not f then
    return
  end
  local content = f:read '*all'
  f:close()

  return content
end
function File_loader.load_json_file(self, path)
  local json_string = self:read_project_file(path)
  if json_string then
    return parser.decode(json_string)
  end
end

xml_parser:parse(File_loader:read_project_file '/var/cache/dev/App_KernelDevDebugContainer.xml')

local Extension_checker = {}
Extension_checker.__index = Extension_checker

function Extension_checker.new()
  local self = setmetatable({}, Extension_checker)

  return self
end

function Extension_checker.current_file_extension()
  local current_file = vim.fn.expand '%:t'
  local _, _, extension = string.find(current_file, '%.([^%.]+)$')
  return extension
end

function Extension_checker:is_extension_supported(extensions)
  local extension = self.current_file_extension()

  for _, ext in pairs(extensions) do
    if extension == ext then
      return true
    end
  end
end

local Regexp_generator = {}
function Regexp_generator.new()
  local self = setmetatable({}, Extension_checker)

  return self
end
function Regexp_generator:generate(content)
  local clear_content = self.purify_content(content)
  local prefix = string.match(clear_content, '^([a-z]*):')

  print(clear_content)
  if self.reg[prefix] then
    return self.reg[prefix]
  end
  return self.reg['service']
end

function Regexp_generator.purify_content(content)
  return string.gsub(content, '["\']', '')
end

Regexp_generator.reg = {
  ['controller'] = '(controller): *([0-9a-zA-Z._\\]*):*([0-9a-zA-Z_]*)',
  ['class'] = '(class): *([0-9a-zA-Z._\\]*):*([0-9a-zA-Z_]*)',
  ['parent'] = '(parent): *([0-9a-zA-Z._\\]*)',
  ['alias'] = '(alias): *([0-9a-zA-Z._\\]*)',
  ['entity'] = '(entity): *([0-9a-zA-Z._\\]*)',
  ['service'] = '^([0-9a-zA-Z._\\]*): *@([0-9a-zA-Z._\\]*)',
}

local Class_finder = {}
Class_finder.__index = Class_finder

function Class_finder.new()
  local self = setmetatable({}, Class_finder)

  self.file_path = ''

  return self
end

function Class_finder:find_by_service_name(service_name)
  for _, service in pairs(handler.root.container.services.service) do
    if service_name == service._attr.id then
      print(service_name)
      if service._attr.class then
        return service._attr.class
      elseif service._attr.alias then
        return self:find_class_by_service_name(service._attr.alias)
      end
    end
  end
end

local Prompt_generator = {}
Prompt_generator.__index = Prompt_generator

function Prompt_generator.new()
  local self = setmetatable({}, Prompt_generator)

  return self
end

function Prompt_generator.generate_from_string(prefix, class, method)
  local prompt
  if prefix == 'class' or prefix == 'parent' or prefix == 'alias' or prefix == 'entity' or prefix == 'parent' then
    prompt = class
  elseif prefix == 'controller' then
    prompt = class .. '::' .. method
  else
    prompt = class
  end

  return prompt
end

local Symfony = {}
Symfony.__index = Symfony

function Symfony.new()
  local self = setmetatable({}, Symfony)

  return self
end

Symfony.setup = { supported_extensions = { 'yml', 'yaml' } }

function Symfony:SfJmp2controllerFromRouting()
  if Extension_checker:is_extension_supported(self.setup.supported_extensions) then
    local linecontent = vim.fn.trim(vim.api.nvim_get_current_line())

    local regexp = Regexp_generator:generate(linecontent)
    --print(regexp)
    if not regexp then
      return
    end

    local prefix, service, method = string.match(Regexp_generator.purify_content(linecontent), regexp)

    local class
    if prefix == 'class' or prefix == 'entity' then
      class = service
    elseif not service then
      class = Class_finder:find_by_service_name(prefix)
    else
      class = Class_finder:find_by_service_name(service)
    end

    print(class)
    if not class then
      return
    end

    namespaces:with_loader(File_loader)
    class = namespaces:get_class_path_from_namespace(class)

    local telescope = require 'telescope.builtin'
    telescope.find_files {
      find_command = { 'rg', '--files', '--hidden', '--no-ignore', '-u' },
      default_text = Prompt_generator.generate_from_string(prefix, class, method),
    }
  end
end

vim.keymap.set('n', '<C-q>', function()
  Symfony:SfJmp2controllerFromRouting()
end, { desc = '[F]ind service from yml' })

return Symfony.new()
