-- this is a catch-all for platforms without a collect-tests implementation
error('collect-tests is not implemented on this platform: ' .. require("eonz").platform.os.name)

local console = require("eonz.console")
