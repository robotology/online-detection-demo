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
    look_at_angle(0,-50,5)
end)

signal.signal(signal.SIGTERM, function(signum)
    interrupting = true
    look_at_angle(0,-50,5)
end)

---------------------------------------
-- yarp port initializations         --
---------------------------------------
yarp.Network()

port_cmd = yarp.BufferedPortBottle()
port_detection = yarp.BufferedPortBottle()
port_gaze_rpc = yarp.RpcClient()
port_ispeak = yarp.BufferedPortBottle()
port_draw_image = yarp.BufferedPortBottle()

if whichRobot == "icub" then
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
port_ispeak:open("/detection/ispeak:o")
port_draw_image:open("/detection/draw:o")

ret = true
ret = ret and yarp.NetworkBase_connect("/pyfaster:detout", port_detection:getName(), "fast_tcp" )
ret = ret and yarp.NetworkBase_connect(port_ispeak:getName(), "/iSpeak")
ret = ret and yarp.NetworkBase_connect(port_draw_image:getName(), "/detection-image/cmd:i")

if whichRobot == "icub" then
    print ("Going through ICUB's connection")
    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/iKinGazeCtrl/angles:i")
    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/iKinGazeCtrl/rpc")
    ret = ret and yarp.NetworkBase_connect("/iKinGazeCtrl/angles:o", port_gaze_rx:getName() )
else
    print ("Going through R1's connection")
    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/cer_gaze-controller/target:i")
    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/cer_gaze-controller/rpc")
    ret = ret and yarp.NetworkBase_connect("/cer_gaze-controller/state:o", port_gaze_rx:getName() )
end

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

azi = 0.0
ele = -50.0
ver = 5.0

---------------------------------------
-- functions Speech Synthesis        --
---------------------------------------

function speak(port, str)
   local wb = port:prepare()
    wb:clear()
    wb:addString(str)
    port:write()
   yarp.Time_delay(1.0)
end

---------------------------------------
-- functions Gaze Control            --
---------------------------------------

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
    print("reply is", reply:toString())
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

function sendDraw(tlx,tly,btx,bty)
    local cmd = port_draw_image:prepare()
    cmd:clear()
    cmd:addString("draw")
    cmd:addInt(tlx)
    cmd:addInt(tly)
    cmd:addInt(btx)
    cmd:addInt(bty)
    port_draw_image:write()
end

function clearDraw()
    local cmd = port_draw_image:prepare()
    cmd:clear()
    cmd:addString("clear")
    port_draw_image:write()
end


function getObjectIndex(det)
    local index = -1
    for i=0,det:size()-1,1 do
        str = det:get(i):asList():get(5):asString()

        --print ("got as object:", str)

        if isSpeech and state ~= "look-around" then
            --remove anything that is not aplha...
            str = str:gsub("[^a-z.]","")
        end

        if object == str then
            index = i
        end
    end
    return index
end


function getClosestObject(det)
    
    index = getObjectIndex(det)

    print("getClosestObject for index is ", index, object)
    local objtx = 0
    local objty = 0
    if index >= 0 then
        objtx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
        objty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2
    end
    
    local mindist = 10000000
    local minindex =-1
    for i=0,det:size()-1,1 do
        if i ~= index then
            local thistx = (det:get(i):asList():get(0):asInt() + det:get(i):asList():get(2):asInt()) / 2
            local thisty = (det:get(i):asList():get(1):asInt() + det:get(i):asList():get(3):asInt()) / 2      
            
            local distancex = math.abs(objtx-thistx)
            local distancey = math.abs(objty-thisty)
            
            local distance = (distancex*distancex) + (distancey*distancey) 
            
            print ("got as distance ", distance, det:get(i):asList():get(5):asString())
            
            if distance < mindist then
                mindist = distance
                minindex = i
            end                         
        end
    end
    local returnStr
    if minindex < 0 then
        returnStr = "none"
    else
        returnStr = det:get(minindex):asList():get(5):asString()
    end
    return returnStr
end


function getObjectsAround(det)

    index = getObjectIndex(det)
    local objectList = yarp.Bottle()
    print("getClosestObject for index is ", index, object)

    if index < 0 then
        objectList:addString("none")
    end
    local objtx = 0
    local objty = 0
    
    if index >= 0 then
        objtx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
        objty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2
    end
    for i=0,det:size()-1,1 do
        if i ~= index then
            local thistx = (det:get(i):asList():get(0):asInt() + det:get(i):asList():get(2):asInt()) / 2
            local thisty = (det:get(i):asList():get(1):asInt() + det:get(i):asList():get(3):asInt()) / 2      
            
            local distancex = math.abs(objtx-thistx)
            local distancey = math.abs(objty-thisty)
            
            local distance = (distancex*distancex) + (distancey*distancey) 
            
            print ("got as distance ", distance, det:get(i):asList():get(5):asString())
            
            if distance < 4000 then
                objectList:addString(det:get(i):asList():get(5):asString())
            end                         
        end
    end
    return objectList
end

--might not be useful anymore. Fixed a recent bug on the gaze controller
if whichRobot == "icub" then
    bind_roll()
    yarp.Time_delay(0.2)
    set_tneck(1.2)
    yarp.Time_delay(0.2)
end

look_at_angle(azi, ele, ver)

speak(port_ispeak, "Roger")

shouldLook = false
shouldDraw = false
drawString = "robot"
isSpeech = false

lookedObject = ""
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

        local interaction = cmd:get(size-1):asString()
        
        if interaction == "speech" then
            isSpeech = true
            print("using interaction speech")
        else
            isSpeech = false
            print("using interaction command")
        end

        if cmd_rx == "look-around" or cmd_rx == "look" or
            cmd_rx == "home" or cmd_rx == "quit" or 
             cmd_rx == "closest-to" or cmd_rx == "where-is" then

            state = cmd_rx

            if state == "look" then
                clearDraw()
                object = cmd:get(1):asString()
                object = object:lower()
                print ("object chosen is", object)

                local det = port_detection:read(true)
                if det ~= nil then
                    local index
      
                    index = getObjectIndex(det)
                    
                    if index >= 0 then
                        local tx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
                        local ty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2

                        local listNames = ""
                            
                        for i=0,det:size()-1,1 do
                            listNames = listNames .. " " .. det:get(i):asList():get(5):asString()
                        end
                        print( "the size is", det:size(), listNames )

                        print( "the chosen index is", index )
                        --print( "the string is", str )
                        print( "tx is", tx )
                        print( "ty is", ty )

                        look_at_pixel("left",tx,ty)

                        speak(port_ispeak, "OK, looking at the ", object)

                    else
                        print("could not find what you are looking for")
                        speak(port_ispeak, "I can't seem to find this object")
                    end
                end

            elseif state == "home" then
                clearDraw()
                look_at_angle(azi, ele, ver)
                speak(port_ispeak, "OK, I will go home")

            elseif state == "look-around" then
                speak(port_ispeak, "OK, I will now look around")
                shouldLook = true
            elseif state == "closest-to" then
                object = cmd:get(1):asString()
                object = object:lower()
                local det = port_detection:read(true)

                if det ~= nil then
                    local name = getClosestObject(det)
                    local tosay                    
                    if name == "none" then
                        tosay = "There is nothing close to the " .. object
                    else
                        tosay = "The closest object is the " .. name 
                    end
                    state = "look"
                    speak(port_ispeak, tosay)
                end
            elseif state == "where-is" then
                object = cmd:get(1):asString()
                object = object:lower()
                local det = port_detection:read(true)

                if det ~= nil then
                    local list = yarp.Bottle()
                    list = getObjectsAround(det)
                    
                    print("size of near objects is ", list:size() )
                    
                    if list:get(0):asString() == "none" then 
                        local tosay = "I cannot see the " .. object
                        speak(port_ispeak, tosay)
                    elseif list:size() < 1 and list:get(0):asString() ~= "none" then
                        local tosay = "Here is the  " .. object
                        speak(port_ispeak, tosay)
                        state = "look"
                    else
                        local tosay = "The " .. object .. " is next to the "
                        for i=0,list:size()-1,1 do
                            if i > 0 then
                                tosay = tosay .. " and the "
                            end
                            tosay = tosay .. list:get(i):asString()
                        end
                        print(tosay)
                        speak(port_ispeak, tosay)
                        state = "look"
                    end
                end
            end
        else
            print("warning: unrecognized command")
        end

    end

    if state == "home" then
        yarp.Time_delay(0.1)

    elseif state == "look" then

        local det = port_detection:read(true)
        if det ~= nil then
            local index
            
            index = getObjectIndex(det)

            if index >= 0 then
                sendDraw(det:get(index):asList():get(0):asInt(), det:get(index):asList():get(1):asInt(),
                         det:get(index):asList():get(2):asInt(), det:get(index):asList():get(3):asInt() )
            end
        end
        yarp.Time_delay(0.1)

    elseif state == "look-around" then
        local det = port_detection:read(false)

        if det ~= nil then
            --math.randomseed( os.time() )
            local num = 0

            if det:size() > 0 then
                num = math.random(0, det:size()-1)
            else
                num = 0
            end

            while det:get(num):asList():get(5):asString() == lookedObject do
                num = math.random(0, det:size()-1)
            end            

            local det_list = det:get(num):asList()

            if not shouldDraw then
                object = det:get(num):asList():get(5):asString()
                lookedObject = object
            end 

            local tx = (det:get(num):asList():get(0):asInt() + det:get(num):asList():get(2):asInt()) / 2
            local ty = (det:get(num):asList():get(1):asInt() + det:get(num):asList():get(3):asInt()) / 2

            t2 = os.difftime(os.time(), t1)

            if t2 > 4 then
                shouldLook = true
                object = det:get(num):asList():get(5):asString()
                lookedObject = object
            end

            if shouldLook then
                print( "the size is", det:size() )
                print( "the chosen one is", num )
                print( "the string is", object )
                print( "tx is", tx )
                print( "ty is", ty )
                print("should now move the head...")
                look_at_pixel("left",tx,ty)
                t1 = os.time()
                drawString = object
                shouldLook = false
                shouldDraw = true
            end

            if shouldDraw then

                local index
                
                index = getObjectIndex(det)

                if index >= 0 then
                    sendDraw(det:get(index):asList():get(0):asInt(), det:get(index):asList():get(1):asInt(),
                        det:get(index):asList():get(2):asInt(), det:get(index):asList():get(3):asInt() )
                end
            end
            yarp.Time_delay(0.1)
        end

    elseif state == "look" then
        yarp.Time_delay(0.1)
    end
end

clearDraw()
look_at_angle(0,-50,5)
speak(port_ispeak, "Bye bye")

port_cmd:close()
port_detection:close()
port_gaze_tx:close()
port_gaze_rx:close()
port_gaze_rpc:close()
port_ispeak:close()
clearDraw()
port_draw_image:close()

yarp.Network_fini()
