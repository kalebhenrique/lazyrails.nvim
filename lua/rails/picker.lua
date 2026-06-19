local M = {}

function M.pick(items, title, mode)
  local Snacks = require("snacks")
  local formatted_items = {}
  for _, item in ipairs(items) do
    table.insert(formatted_items, {
      text = item,
      file = item
    })
  end

  local picker_opts = {
    title = title,
    items = formatted_items,
    format = "file",
  }

  if mode == "vsplit" then
    picker_opts.actions = {
      confirm = function(picker, item)
        picker:close()
        if item and item.file then
          vim.cmd.vsplit(item.file)
        end
      end
    }
  end

  Snacks.picker.pick(picker_opts)
end

return M
