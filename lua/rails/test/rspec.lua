local config = require("rails.config").values.test
local notify_instance = require("rails.test.notify")

local M = {}

function M.run(test_path, bufnr, ns, terminal_bufnr, notify_record)
  M.summary = nil

  vim.fn.termopen({ "bundle", "exec", "rspec", test_path, "--format", "j" }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if not data then return end

      -- Join all output and extract the JSON object starting with {"version"
      local full = table.concat(data, "")
      local start = full:find('{"version"')
      if not start then return end

      -- Walk forward counting braces to find the matching closing brace
      local depth = 0
      local json_str
      for i = start, #full do
        local c = full:sub(i, i)
        if c == "{" then
          depth = depth + 1
        elseif c == "}" then
          depth = depth - 1
          if depth == 0 then
            json_str = full:sub(start, i)
            break
          end
        end
      end

      if not json_str then return end

      local ok, result = pcall(vim.json.decode, json_str)
      if not ok or not result then return end

      M.summary = result.summary
      local failed = {}

      for _, decoded in ipairs(result.examples or {}) do
        if string.find(decoded.file_path, vim.fn.fnamemodify(test_path, ":t:r")) ~= nil then
          if decoded.status == "passed" or decoded.status == "pending" then
            local text = { config.pass_icon, "DiagnosticOk" }
            vim.api.nvim_buf_set_extmark(bufnr, ns, tonumber(decoded.line_number) - 1, 0, {
              virt_text = { text }
            })
          else
            local function filter_backtrace(backtrace)
              local new_table = {}
              local index = 1
              for _, v in ipairs(backtrace) do
                if string.find(v, '_spec.rb:') then
                  new_table[index] = v
                  break
                end
              end

              return new_table
            end

            local fail_backtrace = filter_backtrace(decoded.exception.backtrace)[1]
            local example_line = string.match(fail_backtrace, ":([^:]+)")

            local text = { config.fail_icon, "DiagnosticError" }
            vim.api.nvim_buf_set_extmark(bufnr, ns, tonumber(example_line) - 1, 0, {
              virt_text = { text }
            })
            -- Convert the table to a string with the specified order
            local message = decoded.exception.class .. "\n" .. decoded.exception.message .. "\n"

            local maxBacktrace = math.min(10, #decoded.exception.backtrace)
            for i = 1, maxBacktrace do
              message = message .. decoded.exception.backtrace[i] .. "\n"
            end

            table.insert(failed, {
              bufnr = bufnr,
              lnum = tonumber(example_line) - 1,
              col = 0,
              severity = vim.diagnostic.severity.ERROR,
              source = "rspec",
              message = message,
              user_data = {},
            })
          end
        end
      end

      vim.diagnostic.set(ns, bufnr, failed, {})
    end,
    on_exit = function()
      if not M.summary then
        pcall(notify_instance.notify,
          "RSpec finished but no JSON output was found.\nCheck that 'rspec' is in your Gemfile and 'bundle exec rspec' works.",
          vim.log.levels.ERROR,
          notify_record,
          { bufnr = bufnr, title = "RSpec: no output" }
        )
        vim.api.nvim_buf_delete(terminal_bufnr, {})
        return
      end

      local message = "Examples: " .. M.summary.example_count .. ", Failures: " .. M.summary.failure_count

      local kind
      if M.summary.example_count == 0 then
        kind = vim.log.levels.WARN
        message = message .. "\n⚠ No examples found — check path:\n" .. test_path
      elseif M.summary.failure_count and M.summary.failure_count > 0 then
        kind = vim.log.levels.ERROR
      else
        kind = vim.log.levels.INFO
      end

      pcall(notify_instance.notify,
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