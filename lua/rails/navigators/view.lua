local M = {}

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local conf = require("telescope.config").values

local function open_picker(results, title)
  local opts = {}
  pickers.new(opts, {
    prompt_title = title,
    finder = finders.new_table { results = results },
    previewer = previewers.vim_buffer_cat.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

local function notify_not_found(msg)
  local ok, nvim_notify = pcall(require, "notify")
  if ok then
    nvim_notify(msg, vim.log.levels.ERROR, { title = "View file not found", timeout = 2500 })
  else
    vim.notify(msg)
  end
end

local function find_inertia_pages(root_path, controller_file)
  local lines = vim.fn.readfile(controller_file)
  local pages = {}
  for _, line in ipairs(lines) do
    local component = line:match([[render%s+inertia:%s*["']([^"']+)["']]])
    if component then
      for _, ext in ipairs({ ".jsx", ".tsx" }) do
        local candidate = "app/frontend/pages/" .. component .. ext
        if vim.fn.filereadable(root_path .. "/" .. candidate) == 1 then
          table.insert(pages, candidate)
        end
      end
    end
  end
  return pages
end

function M.visit()
  local root_path = vim.fn.getcwd()
  local current_relative_file_path = vim.fn.expand("%:~:.")

  if string.match(current_relative_file_path, "app/models") then
    local model_name = vim.fn.fnamemodify(current_relative_file_path, ":t:r")
    local view_directory = root_path .. "/app/views/" .. model_name .. "s" .. "/**/*.html.erb"

    local views = vim.split(vim.fn.glob(view_directory), "\n")
    local parsed_views = {}
    for _, view in pairs(views) do
      if view ~= "" then
        table.insert(parsed_views, vim.fn.fnamemodify(view, ":~:."))
      end
    end

    if #parsed_views > 0 then
      open_picker(parsed_views, "Views")
    else
      notify_not_found("No view for model: " .. model_name)
    end

  elseif string.match(current_relative_file_path, "app/controllers") then
    local controller_name = vim.fn.fnamemodify(current_relative_file_path, ":t:r")
    local start, _ = string.find(controller_name, "_controller")
    controller_name = string.sub(controller_name, 1, start - 1)

    -- Traditional erb views
    local view_directory = root_path .. "/app/views/" .. controller_name .. "/**/*.html.erb"
    local views = vim.split(vim.fn.glob(view_directory), "\n")
    local candidates = {}
    for _, view in pairs(views) do
      if view ~= "" then
        table.insert(candidates, vim.fn.fnamemodify(view, ":~:."))
      end
    end

    -- Inertia pages (grep render inertia: "..." in the controller file)
    local abs_controller = root_path .. "/" .. current_relative_file_path
    for _, page in ipairs(find_inertia_pages(root_path, abs_controller)) do
      table.insert(candidates, page)
    end

    if #candidates > 1 then
      open_picker(candidates, "Views")
    elseif #candidates == 1 then
      vim.cmd.edit(candidates[1])
    else
      notify_not_found("No views for controller: " .. controller_name)
    end
  end
end

return M
