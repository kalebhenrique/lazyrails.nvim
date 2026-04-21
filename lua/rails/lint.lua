local config = require("rails.config").values.lint
local notify_instance = require("rails.lint.notify")

local M = {}
local ns = vim.api.nvim_create_namespace("lazyrails-lint")
local inline_clear_group = vim.api.nvim_create_augroup("lazyrails-lint-inline-clear", { clear = false })
local buffer_states = {}

local function state_for(bufnr)
  if not buffer_states[bufnr] then
    buffer_states[bufnr] = {
      token = 0,
      job_id = nil,
      inline_autocmd_registered = false,
    }
  end

  return buffer_states[bufnr]
end

local function stop_job(state)
  if state.job_id and state.job_id > 0 then
    pcall(vim.fn.jobstop, state.job_id)
    state.job_id = nil
  end
end

local function is_active_token(bufnr, token)
  local state = buffer_states[bufnr]
  return state ~= nil and state.token == token
end

local function clear_line_annotations(bufnr, line)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local extmarks = vim.api.nvim_buf_get_extmarks(bufnr, ns, { line, 0 }, { line + 1, 0 }, {})
  for _, extmark in ipairs(extmarks) do
    vim.api.nvim_buf_del_extmark(bufnr, ns, extmark[1])
  end

  local diagnostics = vim.diagnostic.get(bufnr, { namespace = ns })
  if #diagnostics == 0 then
    return
  end

  local filtered = {}
  local removed = false

  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.lnum == line then
      removed = true
    else
      table.insert(filtered, diagnostic)
    end
  end

  if removed then
    vim.diagnostic.set(ns, bufnr, filtered, {})
  end
end

local function ensure_inline_clear_autocmd(bufnr)
  local state = state_for(bufnr)
  if state.inline_autocmd_registered then
    return
  end
  state.inline_autocmd_registered = true

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = inline_clear_group,
    buffer = bufnr,
    callback = function()
      local line = vim.api.nvim_win_get_cursor(0)[1] - 1
      clear_line_annotations(bufnr, line)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = inline_clear_group,
    buffer = bufnr,
    once = true,
    callback = function()
      buffer_states[bufnr] = nil
    end,
  })
end

local function run()
  local bufnr = vim.api.nvim_get_current_buf()
  local lint_path = vim.fn.expand("%:p")
  local display_name = vim.fn.expand("%:t")
  local state = state_for(bufnr)

  state.token = state.token + 1
  local run_token = state.token
  stop_job(state)
  ensure_inline_clear_autocmd(bufnr)

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
  local runtime = {
    is_stale = function()
      return not is_active_token(bufnr, run_token)
    end,
    on_exit = function()
      local active_state = buffer_states[bufnr]
      if active_state and active_state.token == run_token then
        active_state.job_id = nil
      end
    end,
  }
  local job_id

  vim.api.nvim_buf_call(terminal_bufnr, function()
    if lint_path:match("%.rb$") then
      job_id = require("rails.lint.rubocop").run(lint_path, bufnr, ns, terminal_bufnr, notify_record, runtime)
    elseif lint_path:match("%.html%.erb$") then
      job_id = require("rails.lint.herb").run(lint_path, bufnr, ns, terminal_bufnr, notify_record, runtime)
    else
      notify_instance.notify(
        "Lint is supported only for .rb and .html.erb files.",
        vim.log.levels.WARN,
        notify_record,
        { bufnr = bufnr, title = "Lint: unsupported file" }
      )
      vim.api.nvim_buf_delete(terminal_bufnr, {})
      runtime.on_exit()
    end
  end)

  if type(job_id) == "number" and job_id > 0 then
    state.job_id = job_id
  else
    state.job_id = nil
  end
end

local function clear()
  local bufnr = vim.api.nvim_get_current_buf()
  local state = state_for(bufnr)

  state.token = state.token + 1
  stop_job(state)

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.diagnostic.reset(ns, bufnr)
  notify_instance.dismiss(bufnr)
end

function M.run()
  run()
end

function M.clear()
  clear()
end

return M
