local diff = require('git-oily.diff')
local commit = require('git-oily.commit')

local M = {}

local state = {
  enabled = false,
  group = nil,
}

function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.enable()
  if state.enabled then return end

  state.group = vim.api.nvim_create_augroup('OilyMode', { clear = true })

  local function buf_map(lhs, rhs, desc)
    vim.keymap.set('n', lhs, rhs, { buffer = true, desc = desc })
  end

  vim.api.nvim_create_autocmd('BufEnter', {
    group = state.group,
    callback = function(ctx)
      if vim.bo[ctx.buf].buftype ~= '' then return end
      if vim.b[ctx.buf].oily_mode_mapped then return end

      buf_map('gs', function()
        require('git-oily.status')._toggle_stage_by_file(vim.fn.expand('%:p'))
      end, 'Oily: stage toggle')
      buf_map('gd', function()
        diff.open(vim.fn.expand('%:p'), false)
      end, 'Oily: diff')
      buf_map('gD', function()
        diff.open(vim.fn.expand('%:p'), true)
      end, 'Oily: staged diff')
      buf_map('gc', function()
        commit.open('commit')
      end, 'Oily: commit')
      buf_map('gS', function()
        require('git-oily.status')._stage_all_from_cwd()
      end, 'Oily: stage all')
      buf_map('gu', function()
        require('git-oily.status')._unstage_all_from_cwd()
      end, 'Oily: unstage all')
      buf_map('g.', M.toggle, 'Oily: disable mode')

      vim.b[ctx.buf].oily_mode_mapped = true
    end,
  })

  state.enabled = true
  vim.notify('[git-oily] Oil Mode ON — gs/gd/gc...', vim.log.levels.INFO)
end

function M.disable()
  if not state.enabled then return end

  vim.api.nvim_del_augroup_by_id(state.group)
  state.group = nil
  state.enabled = false

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.b[buf].oily_mode_mapped then
      pcall(vim.keymap.del, 'n', 'gs', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'gd', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'gD', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'gc', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'gS', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'gu', { buffer = buf })
      pcall(vim.keymap.del, 'n', 'g.', { buffer = buf })
      vim.b[buf].oily_mode_mapped = nil
    end
  end

  vim.notify('[git-oily] Oil Mode OFF', vim.log.levels.INFO)
end

function M.is_enabled()
  return state.enabled
end

return M
