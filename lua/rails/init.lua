local lazyrails = {}

function lazyrails.setup(opts)
  opts = opts or {}

  require("rails.config").set_defaults(opts)
end

return lazyrails