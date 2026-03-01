-- Navigation dispatcher for lazyrails.nvim
-- Provides go_to_model / go_to_controller / go_to_view / go_to_test helpers
-- based on the current file context.
local M = {}

--- Navigate to the associated model file.
--- Opens a Telescope picker when multiple matches are found.
--- @param mode "normal"|"vsplit"
function M.go_to_model(mode)
  require("rails.navigators.model").visit(mode)
end

--- Navigate to the associated controller file.
--- Opens a Telescope picker when multiple matches are found.
--- @param mode "normal"|"vsplit"
function M.go_to_controller(mode)
  require("rails.navigators.controller").visit(mode)
end

--- Navigate to the associated view directory (Telescope picker).
function M.go_to_view()
  require("rails.navigators.view").visit()
end

--- Navigate to the associated test / spec file.
--- Handles both minitest (test/) and RSpec (spec/) projects.
--- @param mode "normal"|"vsplit"
function M.go_to_test(mode)
  require("rails.navigators.test").visit(mode)
end

return M
