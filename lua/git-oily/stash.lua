local runner = require('git-oily.core.runner')

local M = {}

function M.open()
  runner.run({ 'stash', 'list' }, function(result)
    if result.code ~= 0 then
      vim.notify('[git-oily] stash list failed: ' .. result.stderr, vim.log.levels.ERROR)
      return
    end
    M._show_list(result.stdout)
  end)
end

function M.refresh(buf)
  runner.run({ 'stash', 'list' }, function(result)
    if result.code ~= 0 then return end
    M._update_buffer(buf, result.stdout)
  end)
end

function M._show_list(output)
  local lines = vim.split(output, '\n', { plain = true })
  local buf = vim.api.nvim_create_buf(true, true)

  local label = 'oil://stash'
  vim.api.nvim_buf_set_name(buf, label)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)

  local stash_entries = {}
  for i, line in ipairs(lines) do
    if line ~= '' then
      local ref = line:match('^(stash@{%d+})')
      if ref then
        table.insert(stash_entries, { ref = ref, line = i })
      end
    end
  end
  vim.b[buf].oily_stash = { entries = stash_entries }

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  M._setup_keymaps(buf)

  vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf, true, {
    split = 'below',
    width = vim.o.columns,
    height = math.floor(vim.o.lines * 0.3),
  }))
end

function M._update_buffer(buf, output)
  local lines = vim.split(output, '\n', { plain = true })
  local stash_entries = {}
  for i, line in ipairs(lines) do
    if line ~= '' then
      local ref = line:match('^(stash@{%d+})')
      if ref then
        table.insert(stash_entries, { ref = ref, line = i })
      end
    end
  end
  vim.b[buf].oily_stash = { entries = stash_entries }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)
end

function M._get_entry(buf)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local entries = vim.b[buf].oily_stash and vim.b[buf].oily_stash.entries or {}
  for _, e in ipairs(entries) do
    if e.line == line then
      return e
    end
  end
  return nil
end

function M._setup_keymaps(buf)
  vim.keymap.set('n', 'dd', function()
    M._show_diff(buf)
  end, { buffer = buf, desc = 'Oily: show stash diff' })

  vim.keymap.set('n', '=', function()
    M._show_diff(buf)
  end, { buffer = buf, desc = 'Oily: show stash diff' })

  vim.keymap.set('n', 'a', function()
    M._apply(buf, false)
  end, { buffer = buf, desc = 'Oily: apply stash' })

  vim.keymap.set('n', 'p', function()
    M._apply(buf, true)
  end, { buffer = buf, desc = 'Oily: pop stash' })

  vim.keymap.set('n', 'd', function()
    M._drop(buf)
  end, { buffer = buf, desc = 'Oily: drop stash' })

  vim.keymap.set('n', 'r', function()
    M.refresh(buf)
  end, { buffer = buf, desc = 'Oily: refresh' })

  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end, { buffer = buf, desc = 'Oily: quit' })
end

function M._show_diff(buf)
  local entry = M._get_entry(buf)
  if not entry then
    vim.notify('[git-oily] No stash on this line', vim.log.levels.INFO)
    return
  end

  runner.run({ 'stash', 'show', '-p', entry.ref }, function(result)
    if result.code ~= 0 then return end

    local lines = vim.split(result.stdout, '\n', { plain = true })
    local buf2 = vim.api.nvim_create_buf(true, true)
    local label = ('oil://stash/%s'):format(entry.ref:gsub('[@{}]', '_'))
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
    end, { buffer = buf2, desc = 'Oily: close' })

    vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf2, true, {
      split = 'below',
      width = vim.o.columns,
      height = math.floor(vim.o.lines * 0.4),
    }))
  end)
end

function M._apply(buf, pop)
  local entry = M._get_entry(buf)
  if not entry then return end

  local args = pop and { 'stash', 'pop' } or { 'stash', 'apply' }
  table.insert(args, entry.ref)

  runner.run(args, function(result)
    if result.code == 0 then
      vim.notify('[git-oily] ' .. (pop and 'Popped' or 'Applied') .. ' ' .. entry.ref, vim.log.levels.INFO)
      M.refresh(buf)
    else
      vim.notify('[git-oily] stash failed: ' .. result.stderr, vim.log.levels.ERROR)
    end
  end)
end

function M._drop(buf)
  local entry = M._get_entry(buf)
  if not entry then return end

  runner.run({ 'stash', 'drop', entry.ref }, function(result)
    if result.code == 0 then
      vim.notify('[git-oily] Dropped ' .. entry.ref, vim.log.levels.INFO)
      M.refresh(buf)
    else
      vim.notify('[git-oily] stash drop failed: ' .. result.stderr, vim.log.levels.ERROR)
    end
  end)
end

return M
