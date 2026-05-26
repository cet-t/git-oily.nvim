local M = {}

function M.get_root()
  local result = vim.system({ 'git', 'rev-parse', '--show-toplevel' }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end
  return vim.trim(result.stdout):gsub('/', '\\')
end

function M.to_relpath(abs_path)
  local root = M.get_root()
  if not root then return abs_path end
  local normalized = abs_path:gsub('/', '\\')
  if vim.startswith(normalized, root) then
    local rel = normalized:sub(#root + 2)
    return rel
  end
  return normalized
end

function M.run(args, opts, callback)
  if type(opts) == 'function' then
    callback = opts
    opts = {}
  end
  opts = opts or {}

  local root = M.get_root()
  if not root then
    vim.notify('[git-oily] Not in a git repository', vim.log.levels.ERROR)
    if callback then
      callback({ code = -1, stdout = '', stderr = 'Not in a git repository' })
    end
    return
  end

  local cmd = vim.list_extend({ 'git' }, args)
  local sys_opts = vim.tbl_deep_extend('force', { cwd = root, text = true }, opts)
  vim.system(cmd, sys_opts, callback)
end

function M.run_sync(args)
  local root = M.get_root()
  if not root then
    vim.notify('[git-oily] Not in a git repository', vim.log.levels.ERROR)
    return nil, { code = -1, stderr = 'Not in a git repository' }
  end

  return vim.system({ 'git', unpack(args) }, { cwd = root, text = true }):wait()
end

return M
