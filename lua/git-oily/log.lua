local runner = require('git-oily.core.runner')
local diff = require('git-oily.diff')

local M = {}

function M.open()
  runner.run({ 'log', '--oneline', '--graph', '--decorate', '--all' }, function(result)
    if result.code ~= 0 then
      vim.notify('[git-oily] log failed: ' .. result.stderr, vim.log.levels.ERROR)
      return
    end
    M._show_log(result.stdout)
  end)
end

function M.refresh(buf)
  runner.run({ 'log', '--oneline', '--graph', '--decorate', '--all' }, function(result)
    if result.code ~= 0 then return end
    M._update_buffer(buf, result.stdout)
  end)
end

function M._show_log(output)
  local lines = vim.split(output, '\n', { plain = true })
  local buf = vim.api.nvim_create_buf(true, true)

  local label = 'oil://log'
  vim.api.nvim_buf_set_name(buf, label)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)

  local commits = M._parse_log(lines)
  vim.b[buf].oily_log = { commits = commits }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  M._setup_keymaps(buf)

  vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf, true, {
    split = 'below',
    width = vim.o.columns,
    height = math.floor(vim.o.lines * 0.4),
  }))
end

function M._parse_log(lines)
  local commits = {}
  local hash_pattern = '^[%*|/\\ ]+([a-f0-9]+)'
  for i, line in ipairs(lines) do
    local hash = line:match(hash_pattern)
    if hash then
      table.insert(commits, { hash = hash, line = i })
    end
  end
  return commits
end

function M._get_commit(buf)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local commits = vim.b[buf].oily_log and vim.b[buf].oily_log.commits or {}
  for _, c in ipairs(commits) do
    if c.line == line then
      return c
    end
  end
  return nil
end

function M._update_buffer(buf, output)
  local lines = vim.split(output, '\n', { plain = true })
  local commits = M._parse_log(lines)
  vim.b[buf].oily_log = { commits = commits }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)
end

function M._setup_keymaps(buf)
  vim.keymap.set('n', 'dd', function()
    M._show_commit_diff(buf)
  end, { buffer = buf, desc = 'Oily: show commit diff' })

  vim.keymap.set('n', '=', function()
    M._show_commit_diff(buf)
  end, { buffer = buf, desc = 'Oily: show commit diff' })

  vim.keymap.set('n', 'r', function()
    M.refresh(buf)
  end, { buffer = buf, desc = 'Oily: refresh' })

  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end, { buffer = buf, desc = 'Oily: quit' })
end

function M._show_commit_diff(buf)
  local commit = M._get_commit(buf)
  if not commit then
    vim.notify('[git-oily] No commit on this line', vim.log.levels.INFO)
    return
  end

  runner.run({ 'diff-tree', '--no-commit-id', '-r', '-p', commit.hash }, function(result)
    if result.code ~= 0 then return end

    local lines = vim.split(result.stdout, '\n', { plain = true })
    if #lines <= 1 then
      vim.notify('[git-oily] No diff for ' .. commit.hash, vim.log.levels.INFO)
      return
    end

    local buf2 = vim.api.nvim_create_buf(true, true)
    local label = ('oil://diff/commit/%s'):format(commit.hash)
    vim.api.nvim_buf_set_name(buf2, label)
    vim.api.nvim_buf_set_option(buf2, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf2, 'modified', false)
    vim.api.nvim_buf_set_option(buf2, 'swapfile', false)
    vim.bo[buf2].filetype = 'diff'
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, lines)

    vim.keymap.set('n', 'q', function()
      if vim.api.nvim_buf_is_valid(buf2) then
        vim.api.nvim_buf_delete(buf2, { force = true })
      end
    end, { buffer = buf2, desc = 'Oily: close diff' })

    vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf2, true, {
      split = 'below',
      width = vim.o.columns,
      height = math.floor(vim.o.lines * 0.4),
    }))
  end)
end

return M
