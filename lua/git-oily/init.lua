local runner = require('git-oily.core.runner')
local status = require('git-oily.status')
local diff = require('git-oily.diff')
local commit = require('git-oily.commit')
local log = require('git-oily.log')
local stash = require('git-oily.stash')
local mode = require('git-oily.mode')

local M = {}

local defaults = {
  keymaps = {
    status = {
      toggle = '-',
      diff = 'dd',
      diff_split = '=',
      stage_all = 'S',
      unstage_all = 'u',
      commit = 'cc',
      amend = 'ca',
      refresh = 'r',
      quit = 'q',
    },
    log = {
      diff = 'dd',
      refresh = 'r',
      quit = 'q',
    },
    stash = {
      diff = 'dd',
      apply = 'a',
      pop = 'p',
      drop = 'd',
      refresh = 'r',
      quit = 'q',
    },
  },
  signs = {
    staged = '+',
    unstaged = '-',
    untracked = '?',
  },
}

M.config = {}

function M.setup(opts)
  M.config = vim.tbl_deep_extend('keep', opts or {}, defaults)

  vim.api.nvim_create_user_command('Oily', function(ctx)
    local args = ctx.fargs
    if #args == 0 or args[1] == 'status' then
      status.open()
    elseif args[1] == 'toggle' then
      mode.toggle()
    elseif args[1] == 'log' then
      log.open()
    elseif args[1] == 'stash' then
      stash.open()
    else
      vim.notify('[git-oily] Unknown command: Oily ' .. table.concat(args, ' '), vim.log.levels.WARN)
    end
  end, {
    nargs = '?',
    complete = function(lead, _)
      local cmds = { 'status', 'toggle', 'log', 'stash' }
      return vim.iter(cmds):filter(function(c) return vim.startswith(c, lead) end):totable()
    end,
  })

  vim.api.nvim_create_user_command('OilyToggle', function()
    mode.toggle()
  end, {})
end

return M
