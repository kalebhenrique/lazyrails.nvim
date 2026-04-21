local config = require("rails.config").values.lint
local notify_instance = require("rails.lint.notify")

local M = {}

local function diagnostic_severity(severity)
  local map = {
    fatal = vim.diagnostic.severity.ERROR,
    error = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARN,
    convention = vim.diagnostic.severity.INFO,
    refactor = vim.diagnostic.severity.HINT,
    info = vim.diagnostic.severity.INFO,
  }

  return map[severity] or vim.diagnostic.severity.ERROR
end

local function extract_json(raw, start_pattern)
  local start = raw:find(start_pattern or "{", 1, false)
  if not start then
    start = raw:find("{", 1, true)
  end
  if not start then
    return nil
  end

  local depth = 0
  for i = start, #raw do
    local char = raw:sub(i, i)
    if char == "{" then
      depth = depth + 1
    elseif char == "}" then
      depth = depth - 1
      if depth == 0 then
        return raw:sub(start, i)
      end
    end
  end

  return nil
end

local function close_terminal(terminal_bufnr)
  if vim.api.nvim_buf_is_valid(terminal_bufnr) then
    vim.api.nvim_buf_delete(terminal_bufnr, {})
  end
end

local function finalize(terminal_bufnr, runtime)
  if runtime and runtime.on_exit then
    runtime.on_exit()
  end
  close_terminal(terminal_bufnr)
end

function M.run(lint_path, bufnr, ns, terminal_bufnr, notify_record, runtime)
  local stdout = {}
  local stderr = {}

  return vim.fn.termopen({ "bundle", "exec", "rubocop", "--format", "json", "--force-exclusion", lint_path }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,
    on_exit = function(_, code)
      if runtime and runtime.is_stale and runtime.is_stale() then
        finalize(terminal_bufnr, runtime)
        return
      end

      local raw = table.concat(stdout, "\n")
      local decoded

      local json_str = extract_json(raw, '{"metadata"')
      if json_str then
        local ok, result = pcall(vim.json.decode, json_str)
        if ok then
          decoded = result
        end
      end

      if not decoded then
        local stderr_text = table.concat(stderr, "\n")
        local message = "RuboCop failed to return JSON output."
        if stderr_text ~= "" then
          message = message .. "\n" .. stderr_text
        elseif raw ~= "" then
          message = message .. "\n" .. raw:sub(1, 500)
        elseif code ~= 0 then
          message = message .. "\nExit code: " .. tostring(code)
        end

        notify_instance.notify(
          message,
          vim.log.levels.ERROR,
          notify_record,
          { bufnr = bufnr, title = "RuboCop: execution failed" }
        )
        finalize(terminal_bufnr, runtime)
        return
      end

      local diagnostics = {}
      local offense_count = 0

      for _, file in ipairs(decoded.files or {}) do
        for _, offense in ipairs(file.offenses or {}) do
          local location = offense.location or {}
          local line = tonumber(location.start_line or location.line)
          local col = tonumber(location.start_column or location.column or 1) - 1
          if not line then
            line = 1
          end
          if col < 0 then
            col = 0
          end

          offense_count = offense_count + 1

          local text = { config.fail_icon, "DiagnosticError" }
          vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
            virt_text = { text },
          })

          local cop_name = offense.cop_name and ("[" .. offense.cop_name .. "] ") or ""
          table.insert(diagnostics, {
            bufnr = bufnr,
            lnum = line - 1,
            col = col,
            severity = diagnostic_severity(offense.severity),
            source = "rubocop",
            message = cop_name .. (offense.message or "Unknown RuboCop offense"),
            user_data = {},
          })
        end
      end

      if offense_count == 0 then
        local text = { config.pass_icon, "DiagnosticOk" }
        vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
          virt_text = { text },
        })
      end

      vim.diagnostic.set(ns, bufnr, diagnostics, {})

      local summary = decoded.summary or {}
      local total = tonumber(summary.offense_count) or offense_count
      local message
      local kind

      if total > 0 then
        kind = vim.log.levels.ERROR
        message = "Offenses: " .. tostring(total)
      else
        kind = vim.log.levels.INFO
        message = "No offenses found."
      end

      notify_instance.notify(
        message,
        kind,
        notify_record,
        { bufnr = bufnr, title = "Result: " .. vim.fn.fnamemodify(lint_path, ":t") }
      )

      finalize(terminal_bufnr, runtime)
    end,
  })
end

return M
