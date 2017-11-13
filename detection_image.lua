#!/usr/local/bin/lua

-- Copyright: (C) 2017 iCub Facility - Istituto Italiano di Tecnologia (IIT)

-- Authors: Vadim Tikhanoff <vadim.tikhanoff@iit.it>
--          Elisa Maiettini <elisa.maiettini@iit.it>

-- Copy Policy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

-- Dependencies

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

if whichRobot == nil or whichRobot ~= "icub" and whichRobot ~= "r1" then
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
port_cmd = yarp.BufferedPortBottle()

port_image_in:open("/detection-image/image:i")
port_image_out:open("/detection-image/image:o")
port_cmd:open("/detection-image/cmd:i")

ret = true
if whichRobot == "icub" then
    ret = yarp.NetworkBase_connect("/icub/camcalib/left/out", port_image_in:getName() )
else
    ret = yarp.NetworkBase_connect("need R1 camera port", port_image_in:getName() )
end

ret = ret and yarp.NetworkBase_connect(port_image_out:getName(), "/viewout" )

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

shouldDraw = false

while not interrupting do
    img_in  = port_image_in:read()
    img_out = img_in

    cmd = port_cmd:read(false)

    if cmd ~= nil then
        local cmd_rx = cmd:get(0):asString()
        print ("command received", cmd_rx)
        if cmd_rx == "draw" then
            topLeftx = cmd:get(1):asInt()
            topLefty = cmd:get(2):asInt()
            bottomRightx = cmd:get(3):asInt()
            bottomRighty = cmd:get(4):asInt()

            print ("command received", topLeftx, topLefty, bottomRightx, bottomRighty)

            shouldDraw = true
        end
        if cmd_rx == "clear" then
            shouldDraw = false
        end
    end

    if shouldDraw then
        for i=topLeftx, bottomRightx do
            img_out:pixel(i, topLefty-1).g = 255
            img_out:pixel(i, topLefty).g = 255
            img_out:pixel(i, topLefty+1).g = 255
        end

        for i=topLefty, bottomRighty do
            img_out:pixel(bottomRightx-1, i).g = 255
            img_out:pixel(bottomRightx, i).g = 255
            img_out:pixel(bottomRightx+1, i).g = 255
        end

        for i=topLefty, bottomRighty do
            img_out:pixel(topLeftx-1, i).g = 255
            img_out:pixel(topLeftx, i).g = 255
            img_out:pixel(topLeftx+1, i).g = 255
        end

        for i=topLeftx, bottomRightx do
            img_out:pixel(i, bottomRighty-1).g = 255
            img_out:pixel(i, bottomRighty).g = 255
            img_out:pixel(i, bottomRighty+1).g = 255
        end
    end

    port_image_out:write(img_out)

end

port_image_in:close()
port_image_out:close()
