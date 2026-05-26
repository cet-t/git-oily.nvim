local runner = require('git-oily.core.runner')
local diff = require('git-oily.diff')
local commit = require('git-oily.commit')

local M = {}

local function get_tree_node()
  local tree_api = require('nvim-tree.api')
  local node = tree_api.tree.get_node_under_cursor()
  if not node or not node.absolute_path then return nil end
  return node
end

function M.on_attach(bufnr, keymaps)
  keymaps = keymaps or {}

  local km = {
    diff_horizontal = keymaps.diff_horizontal or { 'gh', desc = 'Oily: diff (horizontal)' },
    diff_vertical   = keymaps.diff_vertical   or { 'gv', desc = 'Oily: diff (vertical)' },
    toggle_stage    = keymaps.toggle_stage    or { 'gs', desc = 'Oily: toggle stage' },
    stage_all       = keymaps.stage_all       or { 'gS', desc = 'Oily: stage all' },
    unstage_all     = keymaps.unstage_all     or { 'gu', desc = 'Oily: unstage all' },
    commit          = keymaps.commit          or { 'gc', desc = 'Oily: commit' },
  }

  vim.keymap.set('n', km.diff_horizontal[1], function()
    local node = get_tree_node()
    if node then diff.open(node.absolute_path, false) end
  end, { buffer = bufnr, desc = km.diff_horizontal.desc })

  vim.keymap.set('n', km.diff_vertical[1], function()
    local node = get_tree_node()
    if node then
      diff.open(node.absolute_path, false)
    end
  end, { buffer = bufnr, desc = km.diff_vertical.desc })

  vim.keymap.set('n', km.toggle_stage[1], function()
    local node = get_tree_node()
    if not node then return end

    local args = node.fs_item and node.fs_item.fs_stat and node.fs_item.fs_stat.type == 'directory'
      and { 'add', node.absolute_path }
      or { 'add', node.absolute_path }
    runner.run(args, function(r)
      if r.code == 0 then
        require('nvim-tree.api').tree.reload()
      else
        vim.notify('[git-oily] stage failed: ' .. r.stderr, vim.log.levels.ERROR)
      end
    end)
  end, { buffer = bufnr, desc = km.toggle_stage.desc })

  vim.keymap.set('n', km.stage_all[1], function()
    runner.run({ 'add', '-A' }, function(r)
      if r.code == 0 then
        require('nvim-tree.api').tree.reload()
      end
    end)
  end, { buffer = bufnr, desc = km.stage_all.desc })

  vim.keymap.set('n', km.unstage_all[1], function()
    runner.run({ 'reset', 'HEAD' }, function(r)
      if r.code == 0 then
        require('nvim-tree.api').tree.reload()
      end
    end)
  end, { buffer = bufnr, desc = km.unstage_all.desc })

  vim.keymap.set('n', km.commit[1], function()
    commit.open('commit')
  end, { buffer = bufnr, desc = km.commit.desc })
end

return M
