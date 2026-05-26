local runner = require('git-oily.core.runner')

local M = {}

function M.open(kind)
  kind = kind or 'commit'

  local buf = vim.api.nvim_create_buf(true, true)

  local label = 'oil://commit'
  vim.api.nvim_buf_set_name(buf, label)

  vim.api.nvim_buf_set_option(buf, 'buftype', 'acwrite')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.bo[buf].filetype = 'gitcommit'

  local lines = {}
  if kind == 'amend' then
    local result = runner.run_sync({ 'log', '--format=%B', '-n', '1' })
    if result and result.code == 0 then
      lines = vim.split(vim.trim(result.stdout), '\n', { plain = true })
    end
  end
  table.insert(lines, '')
  table.insert(lines, '# Please enter the commit message for your changes.')

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = buf,
    callback = function()
      local ok, err = M._do_commit_sync(buf, kind)
      if ok then
        vim.api.nvim_buf_set_option(buf, 'modified', false)
        vim.notify('[git-oily] Commit successful', vim.log.levels.INFO)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
          end
        end)
      else
        vim.api.nvim_buf_set_option(buf, 'modified', true)
        vim.notify('[git-oily] Commit failed: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
      end
    end,
  })

  vim.api.nvim_set_current_buf(buf)
  vim.cmd('startinsert!')
end

function M._do_commit_sync(buf, kind)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local msg_lines = {}
  for _, l in ipairs(lines) do
    if vim.startswith(l, '#') then
      break
    end
    table.insert(msg_lines, l)
  end

  local msg = table.concat(msg_lines, '\n')
  msg = vim.trim(msg)

  if msg == '' then
    return false, 'empty commit message'
  end

  local tmpfile = vim.fn.tempname()
  vim.fn.writefile(msg_lines, tmpfile)

  local args = { 'commit', '-F', tmpfile }
  if kind == 'amend' then
    table.insert(args, '--amend')
  end

  local result = runner.run_sync(args)
  vim.fn.delete(tmpfile)

  if result and result.code == 0 then
    return true, nil
  else
    local err = (result and result.stderr) or 'git command failed'
    return false, err
  end
end

return M
