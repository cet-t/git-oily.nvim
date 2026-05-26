local runner = require('git-oily.core.runner')
local diff = require('git-oily.diff')
local commit = require('git-oily.commit')

local M = {}

function M.open()
  runner.run({ 'status', '--porcelain' }, function(result)
    if result.code ~= 0 then
      vim.notify('[git-oily] status failed: ' .. result.stderr, vim.log.levels.ERROR)
      return
    end
    M._show_status(result.stdout)
  end)
end

function M.refresh(buf)
  runner.run({ 'status', '--porcelain' }, function(result)
    if result.code ~= 0 then
      return
    end
    M._update_buffer(buf, result.stdout)
  end)
end

function M._parse_status(output)
  local entries = {}
  local staged = {}
  local unstaged = {}
  local untracked = {}

  for _, line in ipairs(vim.split(output, '\n', { plain = true })) do
    if line ~= '' then
      local entry = M._parse_line(line)
      if entry then
        table.insert(entries, entry)
        if entry.type == 'staged' then
          table.insert(staged, entry)
        elseif entry.type == 'unstaged' then
          table.insert(unstaged, entry)
        elseif entry.type == 'untracked' then
          table.insert(untracked, entry)
        end
      end
    end
  end

  return { entries = entries, staged = staged, unstaged = unstaged, untracked = untracked }
end

function M._parse_line(line)
  local x, y, file = line:match('^(.)(.) (.+)$')
  if not x then
    return nil
  end

  if file:sub(1, 1) == '"' then
    file = file:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
  end

  if x == '?' and y == '?' then
    return { file = file, x = x, y = y, type = 'untracked', staged = false, unstaged = false }
  end

  local is_staged = x ~= ' ' and x ~= '!'
  local is_unstaged = y ~= ' ' and y ~= '!'

  local entry_type = 'clean'
  if is_staged and is_unstaged then
    entry_type = 'staged'
  elseif is_staged then
    entry_type = 'staged'
  elseif is_unstaged then
    entry_type = 'unstaged'
  end

  return { file = file, x = x, y = y, type = entry_type, staged = is_staged, unstaged = is_unstaged }
end

local function status_char(entry)
  if entry.type == 'untracked' then
    return '?'
  end
  if entry.type == 'staged' then
    if entry.x == 'M' then return '+' end
    if entry.x == 'A' then return '+' end
    if entry.x == 'D' then return '-' end
    if entry.x == 'R' then return '>' end
    return '+'
  end
  if entry.type == 'unstaged' then
    if entry.y == 'M' then return '~' end
    if entry.y == 'D' then return '-' end
    return '~'
  end
  return ' '
end

function M._show_status(output)
  local data = M._parse_status(output)
  local buf = vim.api.nvim_create_buf(true, true)

  local label = 'oil://status'
  vim.api.nvim_buf_set_name(buf, label)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)

  vim.b[buf].oily_status = { data = data, file_map = {} }

  M._render_buffer(buf, data)
  M._setup_keymaps(buf)

  vim.api.nvim_set_current_win(vim.api.nvim_open_win(buf, true, {
    split = 'below',
    width = vim.o.columns,
    height = math.floor(vim.o.lines * 0.35),
  }))
end

function M._render_buffer(buf, data)
  local lines = {}

  local function add_section(title, color)
    table.insert(lines, '')
    table.insert(lines, '# ' .. title)
    table.insert(lines, '')
  end

  add_section('Staged')
  for _, entry in ipairs(data.staged) do
    table.insert(lines, ('%s %s'):format(status_char(entry), entry.file))
  end

  add_section('Unstaged')
  for _, entry in ipairs(data.unstaged) do
    table.insert(lines, ('%s %s'):format(status_char(entry), entry.file))
  end

  add_section('Untracked')
  for _, entry in ipairs(data.untracked) do
    table.insert(lines, ('%s %s'):format(status_char(entry), entry.file))
  end

  if #lines == 3 then
    lines = { '', '# Working tree clean' }
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modified', false)

  local file_map = {}
  local line_num = 4

  for _, entry in ipairs(data.staged) do
    file_map[line_num] = entry
    line_num = line_num + 1
  end
  line_num = line_num + 3
  for _, entry in ipairs(data.unstaged) do
    file_map[line_num] = entry
    line_num = line_num + 1
  end
  line_num = line_num + 3
  for _, entry in ipairs(data.untracked) do
    file_map[line_num] = entry
    line_num = line_num + 1
  end

  vim.b[buf].oily_status.file_map = file_map
end

function M._update_buffer(buf, output)
  local data = M._parse_status(output)
  vim.b[buf].oily_status = { data = data, file_map = {} }
  M._render_buffer(buf, data)
end

function M._get_entry(buf)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local file_map = vim.b[buf].oily_status and vim.b[buf].oily_status.file_map or {}
  return file_map[line]
end

function M._setup_keymaps(buf)
  vim.keymap.set('n', '-', function()
    M._toggle_stage(buf)
  end, { buffer = buf, desc = 'Oily: toggle stage' })

  vim.keymap.set('n', 'dd', function()
    M._show_diff(buf)
  end, { buffer = buf, desc = 'Oily: diff' })

  vim.keymap.set('n', '=', function()
    M._show_diff(buf)
  end, { buffer = buf, desc = 'Oily: diff' })

  vim.keymap.set('n', 'S', function()
    M._stage_all(buf)
  end, { buffer = buf, desc = 'Oily: stage all' })

  vim.keymap.set('n', 'u', function()
    M._unstage_all(buf)
  end, { buffer = buf, desc = 'Oily: unstage all' })

  vim.keymap.set('n', 'cc', function()
    commit.open('commit')
  end, { buffer = buf, desc = 'Oily: commit' })

  vim.keymap.set('n', 'ca', function()
    commit.open('amend')
  end, { buffer = buf, desc = 'Oily: amend' })

  vim.keymap.set('n', 'r', function()
    M.refresh(buf)
  end, { buffer = buf, desc = 'Oily: refresh' })

  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end, { buffer = buf, desc = 'Oily: quit' })
end

function M._toggle_stage(buf)
  local entry = M._get_entry(buf)
  if not entry or entry.type == 'untracked' then
    if entry then
      runner.run({ 'add', entry.file }, function(r)
        if r.code == 0 then M.refresh(buf) end
      end)
    end
    return
  end

  if entry.staged then
    runner.run({ 'reset', 'HEAD', '--', entry.file }, function(r)
      if r.code == 0 then M.refresh(buf) end
    end)
  else
    runner.run({ 'add', entry.file }, function(r)
      if r.code == 0 then M.refresh(buf) end
    end)
  end
end

function M._show_diff(buf)
  local entry = M._get_entry(buf)
  if not entry then return end
  diff.open(entry.file, entry.type == 'staged' and not entry.unstaged)
end

function M._stage_all(buf)
  runner.run({ 'add', '-A' }, function(r)
    if r.code == 0 then M.refresh(buf) end
  end)
end

function M._unstage_all(buf)
  runner.run({ 'reset', 'HEAD' }, function(r)
    if r.code == 0 then M.refresh(buf) end
  end)
end

function M._toggle_stage_by_file(filepath)
  local relpath = runner.to_relpath(filepath)

  runner.run({ 'status', '--porcelain', '--', relpath }, function(result)
    if result.code ~= 0 then return end

    local entry = M._parse_line(vim.trim(result.stdout))
    if not entry then
      runner.run({ 'add', relpath }, function(r)
        if r.code == 0 then
          vim.notify('[git-oily] Staged: ' .. relpath, vim.log.levels.INFO)
        end
      end)
      return
    end

    if entry.staged then
      runner.run({ 'reset', 'HEAD', '--', relpath }, function(r)
        if r.code == 0 then
          vim.notify('[git-oily] Unstaged: ' .. relpath, vim.log.levels.INFO)
        end
      end)
    else
      runner.run({ 'add', relpath }, function(r)
        if r.code == 0 then
          vim.notify('[git-oily] Staged: ' .. relpath, vim.log.levels.INFO)
        end
      end)
    end
  end)
end

function M._stage_all_from_cwd()
  runner.run({ 'add', '-A' }, function(r)
    if r.code == 0 then
      vim.notify('[git-oily] Staged all changes', vim.log.levels.INFO)
    end
  end)
end

function M._unstage_all_from_cwd()
  runner.run({ 'reset', 'HEAD' }, function(r)
    if r.code == 0 then
      vim.notify('[git-oily] Unstaged all changes', vim.log.levels.INFO)
    end
  end)
end

return M
