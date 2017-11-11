#!/usr/local/bin/lua

-- To install posix.signal do:
-- sudo apt-get install luarocks
-- sudo luarocks install luaposix

local signal = require("posix.signal")
require("yarp")

rf = yarp.ResourceFinder()
rf:setVerbose(false)
rf:configure(arg)

whichRobot = arg[1]

if whichRobot ~= nil then
    whichRobot = whichRobot:lower()
end

f whichRobot == nil or whichRobot ~= "icub" and whichRobot ~= "r1" then
    print("Please state which robot you are using icub or r1")
    os.exit()
elseif whichRobot == "icub" then
    whichRobot = "icub"
    print("in icub")
else
    whichRobot = "r1"
    print("in r1")
end

---------------------------------------
-- yarp port initializations         --
---------------------------------------
yarp.Network()
port_image_in = yarp.BufferedPortImageRgb()
port_image_out = yarp.Port()

port_image_in:open("/detection/image:i")
port_image_out:open("/detection/image:o")

ret = true
if whichRobot == "icub" then
    ret = yarp.NetworkBase_connect("/icub/camcalib/left/out", port_image_in:getName() )
else
    ret = yarp.NetworkBase_connect("need R1 camera port", port_image_in:getName() )

ret = ret and yarp.NetworkBase_connect(port_image_out:getName(), "/outview" )

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

while not interrupting do
    img_in  = port_image_in:read()

    w = img_in:width()
    h = img_in:height()

    print("image in size ", w, h )

    img_out = img_in

    port_image_out:write(img_out)

end

port_image_in:close()
port_image_out:close()
