local config = require("rails.config").values.test
local notify_instance = require("rails.test.notify")

local M = {}

local function run(type)
  local is_rails = vim.fn.glob(vim.fn.getcwd() .. "/bin/rails") ~= ''
  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("lazyrails-test")
  local relative_file_path = vim.fn.expand("%:~:.")
  local cursor_position = vim.api.nvim_win_get_cursor(0)[1]
  local test_name = ""
  if is_rails == false and type == "Line" then
    test_name = vim.fn.expand("<cword>")
  end

  local function get_test_path()
    if is_rails then
      if type == "Line" then
        return relative_file_path .. ":" .. cursor_position
      else
        return relative_file_path
      end
    else
      return relative_file_path
    end
  end
  local test_path = get_test_path()

  -- Clear extmark
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  -- Reset current diagnostic
  vim.diagnostic.reset(ns, bufnr)
  -- Close notification window
  notify_instance.dismiss(bufnr)

  local function get_notification_message()
    local path = vim.fn.fnamemodify(relative_file_path, ":t")

    if type == "Line" then
      return "File: " .. path .. ":" .. cursor_position
    else
      return "File: " .. path
    end
  end

  local function get_notification_title()
    if type == "Line" then
      return config.message.line
    else
      return config.message.file
    end
  end

  local notification_message = get_notification_message()
  local notification_title = get_notification_title()

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
      require("rails.test.minitest").run(test_path, test_name, bufnr, ns, terminal_bufnr, notify_record)
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

function M.run(type)
  run(type)
end

function M.clear()
  clear()
end

return M