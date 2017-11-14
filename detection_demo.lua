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
interaction = arg[2]

---------------------------------------
-- setting up demo with arguments    --
---------------------------------------

if whichRobot ~= nil then
    whichRobot = whichRobot:lower()
end

if interaction ~= nil then
    interaction = interaction:lower()
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

if interaction == nil or interaction ~= "speech" and interaction ~= "cmd" then
    print("Please state which type of interaction would you like to use")
    os.exit()
elseif interaction == "speech" then
    interaction = "speech"
else
    interaction = "cmd"
end

print ("using:", whichRobot)
print ("using:", interaction)

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
port_speech_recog = yarp.Port()
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
port_speech_recog:open("/detection/speech:o")
port_draw_image:open("/detection/draw:o")

ret = false
ret = yarp.NetworkBase_connect("/pyfaster:detout", port_detection:getName() )
ret = ret and yarp.NetworkBase_connect(port_ispeak:getName(), "/iSpeak")
ret = ret and yarp.NetworkBase_connect(port_speech_recog:getName(), "/speechRecognizer/rpc")
ret = ret and yarp.NetworkBase_connect(port_draw_image:getName(), "/detection-image/cmd:i")
yarp.NetworkBase_connect( "/pyfaster:detimgout","/detectionDump")
yarp.NetworkBase_connect( "/detection-image/image:o","/detectionLook")

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
-- functions Speech Recognition      --
---------------------------------------

objects = {"Sprayer", "Book", "Cup", "Soapdispenser", "Sodabottle"}

-- defining speech grammar in order to expand the speech recognition
grammar = "Return to home position | Look around | Look at the #Object | Where is the #Object | See you soon"

function SM_RGM_Expand(port, vocab, word)
    local wb = yarp.Bottle()
    local reply = yarp.Bottle()
    wb:clear()
    wb:addString("RGM")
    wb:addString("vocabulory")
    wb:addString("add")
    wb:addString(vocab)
    wb:addString(word)
    port:write(wb)
    return "OK" --reply:get(1):asString()
end

function SM_Reco_Grammar(port, gram)
    local wb = yarp.Bottle()
    local reply = yarp.Bottle()
    wb:clear()
    wb:addString("recog")
    wb:addString("grammarSimple")
    wb:addString(gram)
    port:write(wb,reply)
    return reply
end

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

--might not be useful anymore. Fixed a recent bug on the gaze controller
if whichRobot == "icub" then
    bind_roll()
    yarp.Time_delay(0.2)
    set_tneck(1.2)
    yarp.Time_delay(0.2)
end

look_at_angle(azi, ele, ver)

if interaction == "speech" then
    print ("expanding speech recognizer grammar")
    ret = true
    for key, word in pairs(objects) do
        ret = ret and (SM_RGM_Expand(port_speech_recog, "#Object", word) == "OK")
    end
    if ret == false then
        print("errors expanding the vocabulary")
    end
end

speak(port_ispeak, "Ready")

print ("done, ready to receive command via ", interaction)

shouldLook = false
---------------------------------------
-- While loop for various modalities --
---------------------------------------

while state ~= "quit" and not interrupting do

    local cmd = yarp.Bottle()
    if interaction == "speech" then
        local result = SM_Reco_Grammar(port_speech_recog, grammar)
        print("received REPLY: ", result:toString() )
        local speechcmd =  result:get(1):asString()

        if speechcmd == "Return" then
            cmd:addString("home")
        elseif speechcmd == "See" then
            cmd:addString("quit")
        elseif speechcmd == "Look" and result:get(3):asString() == "around" then
            cmd:addString("look-around")
        elseif speechcmd == "Look" and result:get(3):asString() == "at" then
            cmd:addString("look")
            local object = result:get(7):asString()
            cmd:addString(object)
        else
            print ("cannot recognize the command")
        end
    else
        cmd = port_cmd:read(false)
    end

    if cmd ~= nil then
        local cmd_rx = cmd:get(0):asString()
        print ("command is ", cmd_rx)

        if cmd_rx == "look-around" or cmd_rx == "look" or
            cmd_rx == "home" or cmd_rx == "quit" then

            state = cmd_rx

            if state == "look" then
                clearDraw()
                object = cmd:get(1):asString()
                print ("object chosen is", object)

                local det = port_detection:read(true)
                if det ~= nil then
                    local index
                    local found = false
                    for i=0,det:size()-1,1 do
                        str = det:get(i):asList():get(5):asString()

                        print ("got as object:", str)

                        if interaction == "speech" then
                            --remove anything that is not aplha...
                            str = str:gsub("[^a-z.]","")
                        end

                        if object == str then
                            found = true
                            index = i
                        end
                    end

                    if found then
                        local tx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
                        local ty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2

                        print( "the size is", det:size() )
                        print( "the chosen one is", index )
                        print( "the string is", str )
                        print( "tx is", tx )
                        print( "ty is", ty )

                        --sendDraw(det:get(index):asList():get(0):asInt(), det:get(index):asList():get(1):asInt(),
                        --         det:get(index):asList():get(2):asInt(), det:get(index):asList():get(3):asInt() )

                        look_at_pixel("left",tx,ty)

                        speak(port_ispeak, "OK")
                    else
                        print("could not find what you are looking for")
                    end
                end

            elseif state == "home" then
                clearDraw()
                look_at_angle(azi, ele, ver)
                speak(port_ispeak, "OK, I will go home")

            elseif state == "look-around" then
                speak(port_ispeak, "OK, I will now look around")
                shouldLook = true
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
            local found = false
            for i=0,det:size()-1,1 do
                str = det:get(i):asList():get(5):asString()

                print ("got as object:", str)

                if interaction == "speech" then
                    --remove anything that is not aplha...
                    str = str:gsub("[^a-z.]","")
                end

                if object == str then
                    found = true
                    index = i
                end
            end

            if found then

                sendDraw(det:get(index):asList():get(0):asInt(), det:get(index):asList():get(1):asInt(),
                         det:get(index):asList():get(2):asInt(), det:get(index):asList():get(3):asInt() )
            end
        end
        yarp.Time_delay(0.1)

    elseif state == "look-around" then
        local det = port_detection:read(false)
        clearDraw()
        if det ~= nil then
            --math.randomseed( os.time() )
            local num = 0

            if det:size() > 0 then
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

            if shouldLook then
                look_at_pixel("left",tx,ty)
                t1 = os.time()
                shouldLook = false
            end

            sendDraw(det:get(num):asList():get(0):asInt(), det:get(num):asList():get(1):asInt(),
                     det:get(num):asList():get(2):asInt(), det:get(num):asList():get(3):asInt() )

            t2 = os.difftime(os.time(), t1)

            if t2 > 4 then
                shouldLook = true
            end
        end

    elseif state == "look" then
        yarp.Time_delay(0.1)
    end
end

clearDraw()
speak(port_ispeak, "Bye bye")

port_cmd:close()
port_detection:close()
port_gaze_tx:close()
port_gaze_rx:close()
port_gaze_rpc:close()
port_speech_recog:close()
port_ispeak:close()
clearDraw()
port_draw_image:close()

yarp.Network_fini()
