local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

require('telescope').setup {
  pickers = {
    find_files = {
      on_input_filter_cb = function(prompt)
        local find_colon = string.find(prompt, '::')
        if find_colon then
          local ret = string.sub(prompt, 1, find_colon - 1)
          vim.schedule(function()
            local prompt_bufnr = vim.api.nvim_get_current_buf()
            local picker = action_state.get_current_picker(prompt_bufnr)
            local lnum = tonumber(prompt:sub(find_colon + 1))
            if type(lnum) == 'number' then
              local win = picker.previewer.state.winid
              local bufnr = picker.previewer.state.bufnr
              local line_count = vim.api.nvim_buf_line_count(bufnr)
              vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(lnum, line_count)), 0 })
            end
          end)
          return { prompt = ret }
        end
      end,
      attach_mappings = function()
        actions.select_default:enhance {
          post = function()
            -- if we found something, go to line
            local prompt = action_state.get_current_line()
            local find_colon = string.find(prompt, '::')
            if find_colon then
              local lnum = tonumber(prompt:sub(find_colon + 1))
              vim.api.nvim_win_set_cursor(0, { lnum, 0 })
            end
          end,
        }
        return true
      end,
    },
  },
}

local symfony = {}

local function get_git_root()
  local output = vim.fn.system 'git rev-parse --show-toplevel'
  local rescode = vim.v.shell_error

  if rescode == 0 then
    return vim.fn.trim(output)
  end
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
  local f = io.open(get_git_root() .. '/composer.json', 'rb')
  if not f then
    return namespace
  end
  local json_file = f:read '*all'
  f:close()

  local decoded_content = parse_json(json_file)

  local prefix, affix
  for key, value in pairs(decoded_content.autoload['psr-4']) do
    if string.find(namespace, '^' .. key) then
      prefix = value
      _, affix = string.match(namespace, '^(' .. key .. ')([a-zA-Z\\]+)')
      break
    end
  end

  print(prefix)

  return prefix .. affix
end

symfony.SfJmp2controllerFromRouting = function()
  if is_file_yml() then
    local linecontent = vim.api.nvim_get_current_line()

    local match1, match2, _, match3 = string.match(linecontent, '(class|controller):%s*([a-zA-z\\]+)(:{1,2})?([a-zA-z_]+)')

    match2 = convert_from_namespace_autoload(match2)
    local class = string.gsub(match2, '\\', '/')

    local telescope = require 'telescope.builtin'

    local prompt
    if match1 == 'class' then
      prompt = class
    elseif match1 == 'controller' then
      prompt = class .. '::' .. match3
    end

    telescope.find_files { default_text = prompt }
  end
end

vim.keymap.set('n', '<C-q>', function()
  symfony.SfJmp2controllerFromRouting()
end, { desc = 'find method in controller' })

return symfony
