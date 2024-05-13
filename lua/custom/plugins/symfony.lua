local actions = require 'telescope.actions'
local action_state = require 'telescope.action.state'

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
            local find_colon = string.find(prompt, ':')
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

function SfJmp2controllerFromRouting()
  local tele_status_ok, _ = pcall(require, 'telescope')
  if not tele_status_ok then
    return
  end
  if vim.bo.filetype == 'yml' or 'yaml' then
    local linecontent = vim.api.nvim_get_current_line()

    local match = string.match(linecontent, '(controller: )([a-zA-z\\]+)::([a-zA-z_]+)')
    local class = string.gsub(match[1], '\\', '/')

    local actions = require 'telescope.actions'
    local action_state = require 'telescope.action.state'
    local telescope = require 'telescope.builtin'

    telescope.current_buffer_fuzzy_find { default_text = class .. '::' .. match[2] }
  end
end

vim.keymap.set('n', '<C><CR>', ':lua SfJmp2controllerFromRouting', { desc = 'find method in controller' })
