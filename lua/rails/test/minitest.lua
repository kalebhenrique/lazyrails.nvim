local config = require("rails.config").values.test
local coverage = require("rails.test.coverage")
local notify_instance = require("rails.test.notify")

local M = {}

local function is_rails()
  local root_path = vim.fn.getcwd()

  if vim.fn.glob(root_path .. "/bin/rails") == '' then
    return false
  else
    return true
  end
end

local function get_coverage_percentage(test_path)
  local root_path = vim.fn.getcwd()
  local function get_replace_path()
    if is_rails() then
      return "/app"
    else
      return "/lib"
    end
  end

  local original_file_path = string.gsub(test_path, "test", get_replace_path, 1)

  original_file_path = root_path .. string.gsub(original_file_path, "_test", "")

  local _, finish = string.find(original_file_path, ".rb")

  if finish ~= nil then
    original_file_path = string.sub(original_file_path, 1, finish)
  end

  return coverage.percentage(original_file_path)
end

function M.run(test_path, test_name, bufnr, ns, terminal_bufnr, notify_record)
  M.statistics = nil

  local command = { "bundle", "exec", "ruby", "-Itest", "-rminitest/json_reporter_plugin", test_path, "--json" }

  if is_rails() == false then
    if test_name ~= "" then
      command = { "bundle", "exec", "ruby", "-Ilib:test", "-rminitest/json_reporter_plugin", test_path, "--name", test_name, "--json" }
    else
      command = { "bundle", "exec", "ruby", "-Ilib:test", "-rminitest/json_reporter_plugin", test_path, "--json" }
    end
  end

  vim.fn.termopen(command, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local failed = {}
      local function filter_response(response)
        for _, v in ipairs(response) do
          if string.find(v, '{"examples":') then
            return v
          elseif string.find(v, "{\"examples\"") then
            return v
          end
        end
      end

      local filtered_result = filter_response(data)

      if not filtered_result then
        -- Dump raw output so the user can see what the test runner actually returned
        local raw = table.concat(data, "\n")
        vim.notify(
          "lazyrails: could not find JSON in test output.\n\nMake sure test_helper.rb has:\n  require \"minitest/json_reporter\"\n\nRaw output (first 500 chars):\n" .. raw:sub(1, 500),
          vim.log.levels.WARN
        )
        return
      end

      local function get_start_index(result)
        local start, _ = string.find(result, '{"examples":')

        return start
      end

      local function get_finish_index(result)
        local _, finish = string.find(result, "}}")

        return finish
      end

      local start_index = get_start_index(filtered_result)
      local finish_index = get_finish_index(filtered_result)
      local result = vim.json.decode(string.sub(filtered_result, start_index, finish_index))

      M.statistics = result.statistics

      for _, line in ipairs(result.examples) do
        local decoded = vim.json.decode(line)
        if decoded.status == "PASS" then
          local text = { config.pass_icon, "DiagnosticOk" }
          vim.api.nvim_buf_set_extmark(bufnr, ns, tonumber(decoded.line) - 1, 0, {
            virt_text = { text }
          })
        else
          local text = { config.fail_icon, "DiagnosticError" }
          vim.api.nvim_buf_set_extmark(bufnr, ns, tonumber(decoded.line) - 1, 0, {
            virt_text = { text }
          })
          table.insert(failed, {
            bufnr = bufnr,
            lnum = tonumber(decoded.line) - 1,
            col = 0,
            severity = vim.diagnostic.severity.ERROR,
            source = "minitest",
            message = decoded.failures,
            user_data = {},
          })
        end
      end

      vim.diagnostic.set(ns, bufnr, failed, {})
    end,
    on_stderr = function(_, data)
      if data[1] ~= "" then
        print("Error DATA: ")
        print(vim.inspect(data))
      end
    end,
    on_exit = function()
      if not M.statistics then
        notify_instance.notify(
          "No JSON output received – check that minitest-json-reporter is installed and the test ran correctly.",
          vim.log.levels.WARN,
          notify_record,
          { bufnr = bufnr, title = "Result: " .. vim.fn.fnamemodify(test_path, ":t") }
        )
        vim.api.nvim_buf_delete(terminal_bufnr, {})
        return
      end

      local coverage_ok, coverage_percentage = pcall(get_coverage_percentage, test_path)

      -- Set the statistics window
      local message = "Assertions: " .. (M.statistics.assertions or "?") .. ", Failures: " .. (M.statistics.failures or "?")

      if coverage_ok and coverage_percentage ~= nil then
        local formatted_coverage = string.format("%.2f%%", coverage_percentage)
        message = message .. ", Coverage: " .. formatted_coverage
      end

      local kind

      if M.statistics.failures and M.statistics.failures > 0 then
        kind = vim.log.levels.ERROR
      else
        kind = vim.log.levels.INFO
      end

      notify_instance.notify(
        message,
        kind,
        notify_record,
        {
          bufnr = bufnr,
          title = "Result: " .. vim.fn.fnamemodify(test_path, ":t")
        }
      )

      -- delete the terminal buffer
      vim.api.nvim_buf_delete(terminal_bufnr, {})
    end,
  })
end

return M