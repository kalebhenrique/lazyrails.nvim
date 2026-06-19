local M = {}

function M.find()
  local root_path = vim.fn.getcwd()
  local models = vim.split(vim.fn.glob(root_path .. "/app/models/**/*rb"), "\n")
  local parsed_models = {}
  for _, value in ipairs(models) do
    -- take only the filename without extension
    if value ~= "" then
      local parsed_filename = vim.fn.fnamemodify(value, ":~:.")
      table.insert(parsed_models, parsed_filename)
    end
  end

  if #parsed_models > 0 then
    local picker = require("rails.picker")
    picker.pick(parsed_models, "Models")
  end
end

return M