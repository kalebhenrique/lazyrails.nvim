-- Navigate from an app file to its associated test or spec file.
-- Supports both minitest (test/) and RSpec (spec/) projects.
local M = {}

local function open_file(path, mode)
  if mode == "vsplit" then
    vim.cmd.vsplit(path)
  else
    vim.cmd.edit(path)
  end
end

local function show_picker(title, results, mode)
  local pickers   = require "telescope.pickers"
  local finders   = require "telescope.finders"
  local previewers = require "telescope.previewers"
  local conf      = require("telescope.config").values
  local opts = {}
  pickers.new(opts, {
    prompt_title = title,
    finder = finders.new_table { results = results },
    previewer = previewers.vim_buffer_cat.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local actions = require "telescope.actions"
      local action_state = require "telescope.actions.state"
      -- override the default select action to respect vsplit mode
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          open_file(selection[1], mode)
        end
      end)
      return true
    end,
  }):find()
end

local function notify_not_found(name)
  local ok, nvim_notify = pcall(require, "notify")
  if ok then
    nvim_notify("No test file for: " .. name, vim.log.levels.WARN,
      { title = "Test file not found", timeout = 2500 })
  else
    vim.notify("Test file not found: " .. name)
  end
end

--- Collect candidates from minitest (test/) and rspec (spec/) for a given
--- subdirectory and base name pattern.
--- @param subdir string  e.g. "models" or "controllers"
--- @param pattern string e.g. "*users_controller*"
--- @return string[]
local function find_tests(subdir, pattern)
  local results = {}
  local minitest = vim.split(
    vim.fn.system({ "find", "test/" .. subdir, "-name", pattern .. "_test.rb" }), "\n")
  local rspec = vim.split(
    vim.fn.system({ "find", "spec/" .. subdir, "-name", pattern .. "_spec.rb" }), "\n")
  for _, f in ipairs(minitest) do
    if f ~= "" then table.insert(results, f) end
  end
  for _, f in ipairs(rspec) do
    if f ~= "" then table.insert(results, f) end
  end
  return results
end

function M.visit(mode)
  local current = vim.fn.expand("%:~:.")

  local subdir, base_name, picker_title

  if string.match(current, "app/models") then
    base_name    = vim.fn.fnamemodify(current, ":t:r")
    subdir       = "models"
    picker_title = "Model Tests"
  elseif string.match(current, "app/controllers") then
    base_name    = vim.fn.fnamemodify(current, ":t:r")
    subdir       = "controllers"
    picker_title = "Controller Tests"
  else
    vim.notify("lazyrails: go_to_test not supported for this file type", vim.log.levels.WARN)
    return
  end

  local candidates = find_tests(subdir, base_name)

  if #candidates > 1 then
    show_picker(picker_title, candidates, mode)
  elseif #candidates == 1 then
    open_file(candidates[1], mode)
  else
    notify_not_found(base_name)
  end
end

return M