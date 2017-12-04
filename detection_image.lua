#!/usr/bin/lua

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

shouldDraw = false

topLeftx = {}
topLefty = {}
bottomRightx = {}
bottomRighty = {}

function drawGreen(tlx,tly,brx,bry)
    for i=tlx, brx do
            img_out:pixel(i, tly-1).r = 0
            img_out:pixel(i, tly).r = 0
            img_out:pixel(i, tly+1).r = 0
            img_out:pixel(i, tly-1).g = 255
            img_out:pixel(i, tly).g = 255
            img_out:pixel(i, tly+1).g = 255
            img_out:pixel(i, tly-1).b = 0
            img_out:pixel(i, tly).b = 0
            img_out:pixel(i, tly+1).b = 0
        end

        for i=tly, bry do
            img_out:pixel(brx-1, i).r = 0
            img_out:pixel(brx, i).r = 0
            img_out:pixel(brx+1, i).r = 0
            img_out:pixel(brx-1, i).g = 255
            img_out:pixel(brx, i).g = 255
            img_out:pixel(brx+1, i).g = 255
            img_out:pixel(brx-1, i).b = 0
            img_out:pixel(brx, i).b = 0
            img_out:pixel(brx+1, i).b = 0
        end

        for i=tly, bry do
            img_out:pixel(tlx-1, i).r = 0
            img_out:pixel(tlx, i).r = 0
            img_out:pixel(tlx+1, i).r = 0
            img_out:pixel(tlx-1, i).g = 255
            img_out:pixel(tlx, i).g = 255
            img_out:pixel(tlx+1, i).g = 255
            img_out:pixel(tlx-1, i).b = 0
            img_out:pixel(tlx, i).b = 0
            img_out:pixel(tlx+1, i).b = 0
        end

        for i=tlx, brx do
            img_out:pixel(i, bry-1).r = 0
            img_out:pixel(i, bry).r = 0
            img_out:pixel(i, bry+1).r = 0
            img_out:pixel(i, bry-1).g = 255
            img_out:pixel(i, bry).g = 255
            img_out:pixel(i, bry+1).g = 255
            img_out:pixel(i, bry-1).b = 0
            img_out:pixel(i, bry).b = 0
            img_out:pixel(i, bry+1).b = 0
        end
end

function drawRed(tlx,tly,brx,bry)
    for i=tlx, brx do
            img_out:pixel(i, tly-1).r = 255
            img_out:pixel(i, tly).r = 255
            img_out:pixel(i, tly+1).r = 255
            img_out:pixel(i, tly-1).g = 0
            img_out:pixel(i, tly).g = 0
            img_out:pixel(i, tly+1).g = 0
            img_out:pixel(i, tly-1).b = 0
            img_out:pixel(i, tly).b = 0
            img_out:pixel(i, tly+1).b = 0
        end

        for i=tly, bry do
            img_out:pixel(brx-1, i).r = 255
            img_out:pixel(brx, i).r = 255
            img_out:pixel(brx+1, i).r = 255
            img_out:pixel(brx-1, i).g = 0
            img_out:pixel(brx, i).g = 0
            img_out:pixel(brx+1, i).g = 0
            img_out:pixel(brx-1, i).b = 0
            img_out:pixel(brx, i).b = 0
            img_out:pixel(brx+1, i).b = 0
        end

        for i=tly, bry do
            img_out:pixel(tlx-1, i).r = 255
            img_out:pixel(tlx, i).r = 255
            img_out:pixel(tlx+1, i).r = 255
            img_out:pixel(tlx-1, i).g = 0
            img_out:pixel(tlx, i).g = 0
            img_out:pixel(tlx+1, i).g = 0
            img_out:pixel(tlx-1, i).b = 0
            img_out:pixel(tlx, i).b = 0
            img_out:pixel(tlx+1, i).b = 0
        end

        for i=tlx, brx do
            img_out:pixel(i, bry-1).r = 255
            img_out:pixel(i, bry).r = 255
            img_out:pixel(i, bry+1).r = 255
            img_out:pixel(i, bry-1).g = 0
            img_out:pixel(i, bry).g = 0
            img_out:pixel(i, bry+1).g = 0
            img_out:pixel(i, bry-1).b = 0
            img_out:pixel(i, bry).b = 0
            img_out:pixel(i, bry+1).b = 0
        end
end

while not interrupting do
    
    img_in  = port_image_in:read()
    img_out = img_in

    cmd = port_cmd:read(false)

    if cmd ~= nil then
        print ("size is", cmd:size())
        local cmd_rx = cmd:get(0):asString()
        --print ("command received", cmd_rx)

        print("COMMAND ", cmd:toString())
        topLeftx = {}
        topLefty = {}
        bottomRightx = {}
        bottomRighty = {}

        if cmd_rx == "draw" then
            
            for i=1,cmd:size()-1,1 do
                topLeftx[i-1] = cmd:get(i):asList():get(0):asInt()
                topLefty[i-1] = cmd:get(i):asList():get(1):asInt()
                bottomRightx[i-1] = cmd:get(i):asList():get(2):asInt()
                bottomRighty[i-1] = cmd:get(i):asList():get(3):asInt()
           
                print (topLeftx[i-1], topLefty[i-1], bottomRightx[i-1], bottomRighty[i-1])
                if bottomRighty[i-1] > 238 then
                    bottomRighty[i-1] = 235
                end

                if bottomRightx[i-1] > 318 then
                    bottomRightx[i-1] = 315
                end

                if topLeftx[i-1] < 3 then
                    topLeftx[i-1] = 5
                end

                if topLefty[i-1] < 3 then
                    topLefty[i-1] = 5
                end

                --print ("command received", topLeftx, topLefty, bottomRightx, bottomRighty)

                shouldDraw = true
            end
        end
        if cmd_rx == "clear" then
            shouldDraw = false
        end
    end

    if shouldDraw then
        --print (topLeftx[0], topLefty[0], bottomRightx[0], bottomRighty[0])  
        
        drawGreen(topLeftx[0],topLefty[0],bottomRightx[0],bottomRighty[0])        
        
        
        for i=1,table.getn(topLeftx),1 do     
            --print (topLeftx[i], topLefty[i], bottomRightx[i], bottomRighty[i])      
            drawRed(topLeftx[i],topLefty[i],bottomRightx[i],bottomRighty[i])
        end
    end

    port_image_out:write(img_out)

end

port_image_in:close()
port_image_out:close()
