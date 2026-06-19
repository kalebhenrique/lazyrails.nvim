local M = {}

function M.find()
  local root_path = vim.fn.getcwd()
  local controllers = vim.split(vim.fn.glob(root_path .. "/app/controllers/**/*rb"), "\n")
  local parsed_controllers = {}
  for _, value in ipairs(controllers) do
    -- take only the filename without extension
    if value ~= "" then
      local parsed_filename = vim.fn.fnamemodify(value, ":~:.")
      table.insert(parsed_controllers, parsed_filename)
    end
  end

  if #parsed_controllers > 0 then
    local picker = require("rails.picker")
    picker.pick(parsed_controllers, "Controllers")
  end
end

return M