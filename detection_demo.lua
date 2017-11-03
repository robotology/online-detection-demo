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
    print("Please state which robot you are uding icub or r1")
    os.exit()
elseif whichRobot == "icub" then
    whichRobot = "icub"
else
    whichRobot = "r1";
end

print ("using:", whichRobot)

interrupting = false
signal.signal(signal.SIGINT, function(signum)
    interrupting = true
    look_at_angle(0,-30,5)
end)

signal.signal(signal.SIGTERM, function(signum)
    interrupting = true
    look_at_angle(0,-30,5)
end)

yarp.Network()

port_cmd = yarp.BufferedPortBottle()
port_detection = yarp.BufferedPortBottle()
port_gaze_rpc = yarp.RpcClient()

if whichRobot == icub then
    port_gaze_tx = yarp.BufferedPortBottle()
    port_gaze_rx = yarp.BufferedPortBottle()
else
    port_gaze_tx = yarp.BufferedPortProperty()
    port_gaze_rx = yarp.BufferedPortProperty()
end

port_cmd:open("/detection/cmd:i")
port_detection:open("/detection/targets:i")
port_gaze_tx:open("/detection/gaze/tx")
port_gaze_rpc:open("/detection/gaze/rpc")
port_gaze_rx:open("/detection/gaze/rx")


yarp.NetworkBase_connect("/pyfaster:detout", port_detection:getName() )

if whichRobot == icub then
    yarp.NetworkBase_connect(port_gaze_tx:getName(), "/iKinGazeCtrl/angles:i")
    yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/iKinGazeCtrl/rpc")
    yarp.NetworkBase_connect("/iKinGazeCtrl/angles:o", port_gaze_rx:getName() )
else
    yarp.NetworkBase_connect(port_gaze_tx:getName(), "/cer_gaze-controller/target:i")
    yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/cer_gaze-controller/rpc")
    yarp.NetworkBase_connect("/cer_gaze-controller/state:o", port_gaze_rx:getName() )
end

while not interrupting and port_detection:getInputCount() == 0 do
    print("checking yarp connection...")
    yarp.Time_delay(1.0)
end

azi = 0.0
ele = -30.0
ver = 5.0

function bind_roll()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("bind")
    cmd:addString("roll")
    cmd:addDouble(0.0)
    cmd:addDouble(0.0)
    port_gaze_rpc:write(cmd,reply)
    print("binding roll")
    print("reply is", reply:get(0):asString())
end

function set_tneck(value)
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("set")
    cmd:addString("Tneck")
    cmd:addDouble(value)
    port_gaze_rpc:write(cmd,reply)
    print("setting tneck at:", value)
    print("reply is", reply:get(0):asString())
end

function look_at_angle(azi,ele,ver)
    local tx = port_gaze_tx:prepare()
    tx:clear()
    if whichRobot == "icub" then
		tx:addString("abs")
        tx:addDouble(azi)
        tx:addDouble(ele)
        tx:addDouble(ver)
    else
		tx:put("control-frame","gaze")
        tx:put("target-type","angular")
        local location = yarp.Bottle()
        local val = location:addList()
        val:addDouble(azi)
        val:addDouble(ele)
        tx:put("target-location",location:get(0))
    end
		port_gaze_tx:write()

    print("look_at_angle:", tx:toString())
end

function look_at_pixel(mode,px,py)

    if whichRobot == "icub" then
        local cmd = yarp.Bottle()
        local reply = yarp.Bottle()
        local val = yarp.Bottle()

        cmd:clear()
        cmd:addString("look")
        cmd:addString("mono")

        val = cmd:addList()
        val:addString(mode)
        val:addDouble(px)
        val:addDouble(py)
        val:addDouble(ver)

        port_gaze_rpc:write(cmd,reply)

        print("look_at_pixel:", cmd:toString())
        print("reply is", reply:get(0):asString())
        
    else
		local tx = port_gaze_tx:prepare()
        tx:clear()
        tx:put("control-frame","depth")
        tx:put("target-type","image")
        tx:put("image","depth")

        local location = yarp.Bottle()
        local val = location:addList()
        val:addDouble(px)
        val:addDouble(py)
        tx:put("target-location",location:get(0))
        port_gaze_tx:write()
        print("look_at_pixel:", mode, tx:toString())
    end
end

t0 = yarp.Time_now()

if whichRobot == "icub" then
    bind_roll()
    yarp.Time_delay(1.0)
    set_tneck(1.2)
    yarp.Time_delay(1.0)
end

print("before")

look_at_angle(azi, ele, ver)

print("after")

while state ~= "quit" and not interrupting do

    local cmd = port_cmd:read(false)
    if cmd ~= nil then
        local cmd_rx = cmd:get(0):asString()

        if cmd_rx == "look-around" or cmd_rx == "look" or
            cmd_rx == "home" or cmd_rx == "quit" then

            state = cmd_rx

            if state == "look" then
                local object = cmd:get(1):asString()
                print ("object chosen is", object)

                local det = port_detection:read(true)
                if det ~= nil then
                    local index
                    local found = false
                    for i=0,det:size()-1,1
                        do
                        print ("got as object:", det:get(i):asList():get(5):asString())
                        if object == det:get(i):asList():get(5):asString() then
                            found = true
                            index = i
                        end
                    end

                    if found then
                        local tx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
                        local ty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2

                        print( "the size is", det:size() )
                        print( "the chosen one is", index )
                        print( "the string is", det:get(index):asList():toString() )
                        print( "tx is", tx )
                        print( "ty is", ty )

                        look_at_pixel("left",tx,ty)
                    else
                        print("could not find what you are looking for")
                    end
                end

            elseif state == "home" then
                look_at_angle(azi, ele, ver)
            end

        else
            print("warning: unrecognized command")
        end

    end

    if state == "home" then
        yarp.Time_delay(0.1)

    elseif state == "look-around" then
        local det = port_detection:read(false)
        if det ~= nil then
            math.randomseed( os.time() )
            local num

            if det:size() > 1 then
                num = math.random(0, det:size()-1)
            else
                num = 0
            end

            local det_list = det:get(num):asList()

            local tx = (det:get(num):asList():get(0):asInt() + det:get(num):asList():get(2):asInt()) / 2
            local ty = (det:get(num):asList():get(1):asInt() + det:get(num):asList():get(3):asInt()) / 2

            print( "the size is", det:size() )
            print( "the chosen one is", num )
            print( "the string is", det_list:toString() )
            print( "tx is", tx )
            print( "ty is", ty )

            look_at_pixel("left",tx,ty)

            yarp.Time_delay(4.0)
        end

    elseif state == "look" then
        yarp.Time_delay(0.1)

    end
end

port_cmd:close()
port_detection:close()
port_gaze_tx:close()
port_gaze_rx:close()
port_gaze_rpc:close()

yarp.Network_fini()
