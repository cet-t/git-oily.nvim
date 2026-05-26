local runner = require('git-oily.core.runner')

local M = {}

function M.open(file, staged)
  local args = { 'diff' }
  if staged then
    table.insert(args, '--cached')
  end
  table.insert(args, '--')
  table.insert(args, file)

  runner.run(args, function(result)
    if result.code ~= 0 then
      vim.notify('[git-oily] diff failed: ' .. result.stderr, vim.log.levels.ERROR)
      return
    end
    M._show_diff(result.stdout, file, staged)
  end)
end

function M._show_diff(content, file, staged)
  local lines = vim.split(content, '\n', { plain = true })
  if #lines == 1 and lines[1] == '' then
    vim.notify('[git-oily] No changes for: ' .. file, vim.log.levels.INFO)
    return
  end

  local buf = vim.api.nvim_create_buf(true, true)

  local prefix = staged and 'staged' or 'unstaged'
  local label = ('oil://diff/%s/%s'):format(prefix, file)
  vim.api.nvim_buf_set_name(buf, label)

  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.bo[buf].filetype = 'diff'

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end, { buffer = buf, desc = 'Oily: close diff' })

  vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf, true, {
    split = 'below',
    width = vim.o.columns,
    height = math.floor(vim.o.lines * 0.4),
  }))
end

return M
