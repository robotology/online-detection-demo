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

---------------------------------------
-- setting up demo with arguments    --
---------------------------------------

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

print ("using:", whichRobot)

---------------------------------------
-- setting up ctrl-c signal handling --
---------------------------------------

interrupting = false
signal.signal(signal.SIGINT, function(signum)
    interrupting = true
    look_at_angle(0,-25,5)
end)

signal.signal(signal.SIGTERM, function(signum)
    interrupting = true
    look_at_angle(0,-25,5)
end)

---------------------------------------
-- yarp port initializations         --
---------------------------------------
yarp.Network()

port_cmd = yarp.BufferedPortBottle()
port_detection = yarp.BufferedPortBottle()
port_gaze_direction = yarp.BufferedPortBottle()
port_gaze_rpc = yarp.RpcClient()
port_ispeak = yarp.BufferedPortBottle()
port_draw_image = yarp.BufferedPortBottle()
port_cmd_detection = yarp.BufferedPortBottle()
port_cmd_gaze = yarp.BufferedPortBottle()

if whichRobot == "icub" then
    port_gaze_tx = yarp.BufferedPortBottle()
    port_gaze_rx = yarp.BufferedPortBottle()
    port_sfm_rpc = yarp.RpcClient()
    port_are_rpc = yarp.RpcClient()
else
    port_gaze_tx = yarp.BufferedPortProperty()
    port_gaze_rx = yarp.BufferedPortProperty()
end

port_cmd:open("/manager/cmd:i")
port_gaze_direction:open("/manager/targets:i")
port_gaze_tx:open("/manager/gaze/tx")
port_gaze_rpc:open("/manager/gaze/rpc")
port_gaze_rx:open("/manager/gaze/rx")
port_ispeak:open("/manager/ispeak:o")
port_cmd_gaze:open("/manager/gaze/cmd:o")

ret = true

ret = ret and yarp.NetworkBase_connect("/yarpOpenFace/target:o", port_gaze_direction:getName())
ret = ret and yarp.NetworkBase_connect(port_ispeak:getName(), "/iSpeak")

if whichRobot == "icub" then
    print ("Going through ICUB's connection")
    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/iKinGazeCtrl/angles:i")
    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/iKinGazeCtrl/rpc")
    ret = ret and yarp.NetworkBase_connect("/iKinGazeCtrl/angles:o", port_gaze_rx:getName() )
    ret = ret and yarp.NetworkBase_connect(port_sfm_rpc:getName(),"/SFM/rpc")
    ret = ret and yarp.NetworkBase_connect(port_are_rpc:getName(),"/actionsRenderingEngine/cmd:io")
else
    print ("Going through R1's connection")
    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/cer_gaze-controller/target:i")
    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/cer_gaze-controller/rpc")
    ret = ret and yarp.NetworkBase_connect("/cer_gaze-controller/state:o", port_gaze_rx:getName() )
    --ret = ret and yarp.NetworkBase_connect(port_cmd_gaze:getName(), "/onTheFlyRec/gaze" )
end

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

azi = 0.0
ele = 0.0
ver = 5.0

index = -1

---------------------------------------
-- functions Speech Synthesis        --
---------------------------------------

function speak(port, str)
   local wb = port:prepare()
    wb:clear()
    wb:addString(str)
    port:write()
    yarp.delay(1.0)
end

---------------------------------------
-- functions Gaze Control            --
---------------------------------------
function startFace(port)
    stopGaze()
   local wb = port_cmd_gaze:prepare()
    wb:clear()
    wb:addString("track-face")
    port_cmd_gaze:write()
    yarp.delay(1.0)
end

---------------------------------------------------------------------------------------------------------------

function startGaze(port)
    stopGaze()
   local wb = port_cmd_gaze:prepare()
    wb:clear()
    wb:addString("track-blob")
    port_cmd_gaze:write()
    yarp.delay(1.0)
end

---------------------------------------------------------------------------------------------------------------
function stopGaze()
   local wb = port_cmd_gaze:prepare()
    wb:clear()
    wb:addString("stop")
    port_cmd_gaze:write()
    yarp.delay(1.0)
end

---------------------------------------------------------------------------------------------------------------

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

---------------------------------------------------------------------------------------------------------------

function look_at_cartesian(x,y,z)
    local tx = port_gaze_tx:prepare()
    
    tx:put("control-frame","gaze")
    tx:put("target-type","cartesian")
    local location = yarp.Bottle()
    local val = location:addList()
    val:addDouble(x)
    val:addDouble(y)
    val:addDouble(z)
    tx:put("target-location",location:get(0))
    
    port_gaze_tx:write()

    print("look_at_cartesian:", tx:toString())
end

---------------------------------------------------------------------------------------------------------------

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

--might not be useful anymore. Fixed a recent bug on the gaze controller
if whichRobot == "icub" then
    bind_roll()
    yarp.delay(0.2)
    set_tneck(1.2)
    yarp.delay(0.2)
    ARE_home()
end

look_at_angle(azi, ele, ver)

speak(port_ispeak, "Roger")

---------------------------------------
-- While loop for various modalities --
---------------------------------------

while state ~= "quit" and not interrupting do

    local cmd = yarp.Bottle()
    cmd = port_cmd:read(false)

    if cmd ~= nil then
        local cmd_rx = cmd:get(0):asString()

        local size = cmd:size();
        print (" ")
        print ("***********************command is *********************** ", cmd_rx)
        print ("size is ", size)


        if cmd_rx == "look" or
            cmd_rx == "home" or 
             cmd_rx == "quit" then

            state = cmd_rx

            if state == "look" then
                local gazeDir = port_gaze_direction:read(false)

                if gazeDir ~= nil then
                    print("looping det ", gazeDir:size())
                    local tx = gazeDir:get(0):asList():get(0):asDouble()
                    local ty = gazeDir:get(0):asList():get(1):asDouble()
                    local tz = gazeDir:get(0):asList():get(2):asDouble()
                    print( "tx is", tx )
                    print( "ty is", ty )
                    print( "tz is", tz )

                    speak(port_ispeak, "looking at your gaze")
                    look_at_cartesian(tx, ty, tz)
                end

            elseif state == "home" then
                stopGaze()
                yarp.delay(0.5)
                look_at_angle(azi, ele, ver)
                speak(port_ispeak, "OK")
            end
        else
            print("warning: unrecognized command")
        end

    end
end

if whichRobot == "icub" then
    look_at_angle(0, -0, 5)
else
    look_at_angle(0, 0, 5)
end

speak(port_ispeak, "Bye bye")


--strainght 1.2 -0.04 -0.05
--left  1.2 0.15 0.1
--right  1.2 -0.15 0.1

yarp.NetworkBase_disconnect("/detection/dets:o", port_detection:getName())
yarp.NetworkBase_disconnect("/detection/speech:o", port_cmd:getName())
yarp.NetworkBase_disconnect(port_ispeak:getName(), "/iSpeak")
yarp.NetworkBase_disconnect(port_gaze_tx:getName(), "/cer_gaze-controller/target:i")
yarp.NetworkBase_disconnect(port_gaze_rpc:getName(), "/cer_gaze-controller/rpc")
yarp.NetworkBase_disconnect("/cer_gaze-controller/state:o", port_gaze_rx:getName() )
yarp.NetworkBase_disconnect(port_cmd_gaze:getName(), "/onTheFlyRec/gaze" )
yarp.NetworkBase_disconnect(port_draw_image:getName(), "/detection-image/cmd:i" )
yarp.NetworkBase_disconnect(port_cmd_detection:getName(), "/detection/command:i" )

port_cmd:close()
port_detection:close()
port_gaze_tx:close()
port_gaze_rx:close()
port_gaze_rpc:close()
port_ispeak:close()
if whichRobot == "icub" then
    port_are_rpc:close()
    port_sfm_rpc:close()
end
port_ispeak:close()
port_cmd_detection:close()

port_draw_image:close()
port_cmd_gaze:close()

yarp.Network_fini()
