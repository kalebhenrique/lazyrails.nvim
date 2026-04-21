local config = require("rails.config").values.lint
local notify_instance = require("rails.lint.notify")

local M = {}

local function diagnostic_severity(severity)
  local map = {
    error = vim.diagnostic.severity.ERROR,
    warning = vim.diagnostic.severity.WARN,
    info = vim.diagnostic.severity.INFO,
    hint = vim.diagnostic.severity.HINT,
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
  if vim.fn.executable("npx") ~= 1 then
    notify_instance.notify(
      "npx is not available. Install Node.js to run Herb linter.",
      vim.log.levels.WARN,
      notify_record,
      { bufnr = bufnr, title = "Herb: unavailable" }
    )
    finalize(terminal_bufnr, runtime)
    return
  end

  local stdout = {}
  local stderr = {}

  return vim.fn.termopen({ "npx", "--no-install", "@herb-tools/linter", lint_path, "--json" }, {
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
      local stderr_text = table.concat(stderr, "\n")

      local decoded
      local json_str = extract_json(raw, '{"offenses"')
      if json_str then
        local ok, result = pcall(vim.json.decode, json_str)
        if ok then
          decoded = result
        end
      end

      if not decoded then
        local missing_package = stderr_text:match("could not determine executable to run")
          or stderr_text:match("not found")
          or stderr_text:match("ENOENT")
          or stderr_text:match("npm ERR")

        if missing_package then
          notify_instance.notify(
            "Herb linter is not installed in this project. Add @herb-tools/linter to run lint for .html.erb files.",
            vim.log.levels.WARN,
            notify_record,
            { bufnr = bufnr, title = "Herb: unavailable" }
          )
          finalize(terminal_bufnr, runtime)
          return
        end

        local message = "Herb linter failed to return JSON output."
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
          { bufnr = bufnr, title = "Herb: execution failed" }
        )
        finalize(terminal_bufnr, runtime)
        return
      end

      local diagnostics = {}
      local offenses = decoded.offenses or {}

      for _, offense in ipairs(offenses) do
        local location = offense.location or {}
        local start_location = location.start or {}
        local line = tonumber(start_location.line or 1)
        local col = tonumber(start_location.column or 1) - 1
        if col < 0 then
          col = 0
        end

        local text = { config.fail_icon, "DiagnosticError" }
        vim.api.nvim_buf_set_extmark(bufnr, ns, line - 1, 0, {
          virt_text = { text },
        })

        local code_label = offense.code and ("[" .. offense.code .. "] ") or ""
        table.insert(diagnostics, {
          bufnr = bufnr,
          lnum = line - 1,
          col = col,
          severity = diagnostic_severity(offense.severity),
          source = "herb",
          message = code_label .. (offense.message or "Unknown Herb offense"),
          user_data = {},
        })
      end

      if #offenses == 0 then
        local text = { config.pass_icon, "DiagnosticOk" }
        vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
          virt_text = { text },
        })
      end

      vim.diagnostic.set(ns, bufnr, diagnostics, {})

      local summary = decoded.summary or {}
      local total = tonumber(summary.totalOffenses) or #offenses

      local kind
      local message

      if total > 0 then
        kind = vim.log.levels.ERROR
        message = "Offenses: " .. tostring(total)
      else
        kind = vim.log.levels.INFO
        message = "No offenses found."
      end

      if decoded.completed == false and decoded.message then
        kind = vim.log.levels.WARN
        message = decoded.message
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
