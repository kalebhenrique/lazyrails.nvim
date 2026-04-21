local config = require("rails.config").values.lint

local M = {}

M.instances = {}

function M.notify(message, kind, notify_record, opts)
  local nvim_notify_ok, nvim_notify = pcall(require, "notify")
  opts = opts or {}

  if nvim_notify_ok then
    opts.timeout = config.notification.timeout

    if opts.bufnr and not M.instances[opts.bufnr] then
      M.instances[opts.bufnr] = nvim_notify.instance({})
    end

    if config.notification.timeout == false and notify_record ~= nil then
      opts.replace = notify_record
    end

    if opts.bufnr and M.instances[opts.bufnr] then
      return M.instances[opts.bufnr](message, kind, opts)
    end

    return nvim_notify(message, kind, opts)
  end

  local prefix
  if kind == "warn" then
    prefix = "Running Lint "
  else
    prefix = "Result: "
  end

  if kind == "warn" then
    return vim.notify(prefix .. message, vim.log.levels.WARN)
  end
  if type(kind) == "number" then
    return vim.notify(prefix .. message, kind)
  end

  return vim.notify(prefix .. message)
end

function M.dismiss(bufnr)
  if M.instances[bufnr] then
    M.instances[bufnr].dismiss()
  end
end

return M
