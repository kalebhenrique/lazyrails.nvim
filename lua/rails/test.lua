local config = require("rails.config").values.test
local notify_instance = require("rails.test.notify")

local M = {}

local function run()
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("lazyrails-test")
  local relative_file_path = vim.fn.expand("%:~:.")
  local test_path = relative_file_path

  -- Clear extmark
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  -- Reset current diagnostic
  vim.diagnostic.reset(ns, bufnr)
  -- Close notification window
  notify_instance.dismiss(bufnr)

  local notification_message = "File: " .. vim.fn.fnamemodify(relative_file_path, ":t")
  local notification_title = config.message.file

  local notify_record = notify_instance.notify(
    notification_message,
    "warn",
    nil,
    { bufnr = bufnr, title = notification_title }
  )

  local terminal_bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_call(terminal_bufnr, function()
    if string.find(test_path, "_spec.rb") then
      require("rails.test.rspec").run(test_path, bufnr, ns, terminal_bufnr, notify_record)
    else
      require("rails.test.minitest").run(test_path, bufnr, ns, terminal_bufnr, notify_record)
    end
  end)
end

local function clear()
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("lazyrails-test")
  -- Clear extmark
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  -- Hide current diagnostic
  vim.diagnostic.hide(ns, bufnr)
  -- Close notification window
  notify_instance.dismiss(bufnr)
end

function M.run()
  run()
end

function M.clear()
  clear()
end

return M