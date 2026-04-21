local config = require("rails.config").values.lint
local notify_instance = require("rails.lint.notify")

local M = {}

local function run()
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("lazyrails-lint")
  local lint_path = vim.fn.expand("%:p")
  local display_name = vim.fn.expand("%:t")

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.diagnostic.reset(ns, bufnr)
  notify_instance.dismiss(bufnr)

  local notify_record = notify_instance.notify(
    "File: " .. display_name,
    "warn",
    nil,
    { bufnr = bufnr, title = config.message.file }
  )

  local terminal_bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_call(terminal_bufnr, function()
    if lint_path:match("%.rb$") then
      require("rails.lint.rubocop").run(lint_path, bufnr, ns, terminal_bufnr, notify_record)
    elseif lint_path:match("%.html%.erb$") then
      require("rails.lint.herb").run(lint_path, bufnr, ns, terminal_bufnr, notify_record)
    else
      notify_instance.notify(
        "Lint is supported only for .rb and .html.erb files.",
        vim.log.levels.WARN,
        notify_record,
        { bufnr = bufnr, title = "Lint: unsupported file" }
      )
      vim.api.nvim_buf_delete(terminal_bufnr, {})
    end
  end)
end

local function clear()
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("lazyrails-lint")

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.diagnostic.hide(ns, bufnr)
  notify_instance.dismiss(bufnr)
end

function M.run()
  run()
end

function M.clear()
  clear()
end

return M
