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
ALmodality = arg[2]
secondDetection = arg[3]

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

if ALmodality ~= nil then
    ALmodality = ALmodality:lower()
end

if ALmodality ~= nil and ALmodality == "al" then
    isAL = true
    print("Active Learning modality")
else
    isAL = false
    print("Supervised modality")
end

if secondDetection ~= nil then
    secondDetection = secondDetection:lower()
end

if secondDetection ~= nil and secondDetection == "showsup" then
    isShow = true
    print("Second detection ON")
else
    isShow = false
    print("Second detection OFF")
end

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
port_gaze_rpc = yarp.RpcClient()
port_ispeak = yarp.BufferedPortBottle()
port_draw_image = yarp.BufferedPortBottle()
port_cmd_detection = yarp.BufferedPortBottle()
port_cmd_gaze = yarp.BufferedPortBottle()
port_google = yarp.RpcClient()
port_gaze_direction = yarp.BufferedPortBottle()

port_augmented_rpc = yarp.RpcClient()


if whichRobot == "icub" then
    port_gaze_tx = yarp.BufferedPortBottle()
    port_gaze_rx = yarp.BufferedPortBottle()
    port_sfm_rpc = yarp.RpcClient()
    port_are_rpc = yarp.RpcClient()
else
    port_gaze_tx = yarp.BufferedPortProperty()
    port_gaze_rx = yarp.BufferedPortProperty()
end
if isAL then
    port_cmd_exploration = yarp.BufferedPortBottle()
    port_cmd_annotation = yarp.BufferedPortBottle()
    port_cmd_karma = yarp.BufferedPortBottle()

end
if isShow then
    port_cmd_detection_show = yarp.BufferedPortBottle()
end

port_cmd:open("/manager/cmd:i")
port_detection:open("/manager/targets:i")
port_gaze_direction:open("/manager/gaze/targets:i")
port_gaze_tx:open("/manager/gaze/tx")
port_gaze_rpc:open("/manager/gaze/rpc")
port_gaze_rx:open("/manager/gaze/rx")
port_ispeak:open("/manager/ispeak:o")
port_draw_image:open("/manager/draw:o")
port_cmd_detection:open("/manager/detection/cmd:o")
port_cmd_gaze:open("/manager/gaze/cmd:o")
port_google:open("/manager/googlePort:o")

port_augmented_rpc:open("/manager/augmented:o")

if whichRobot == "icub" then
    port_sfm_rpc:open("/detection/sfm/rpc")
    port_are_rpc:open("/detection/are/rpc")
end
if isAL then
    port_cmd_exploration:open("/manager/exploration/cmd:o")
    port_cmd_annotation:open("/manager/blobAnnotation/cmd:o")
    port_cmd_karma:open("/manager/karma/cmd:o")
end
if isShow then
    port_cmd_detection_show:open("/manager/detection/showSup/cmd:o")
end

ret = true
--ret = ret and yarp.NetworkBase_connect("/detection/detrs:o", port_detection:getName(), "fast_tcp" )
ret = ret and yarp.NetworkBase_connect(port_ispeak:getName(), "/iSpeak")
--ret = ret and yarp.NetworkBase_connect(port_augmented_rpc:getName(), "/yarp-augmented/rpc")
--ret = ret and yarp.NetworkBase_connect(port_draw_image:getName(), "/detection-image/cmd:i")
ret = ret and yarp.NetworkBase_connect(port_cmd_detection:getName(), "/detection/command:i")
--ret = ret and yarp.NetworkBase_connect("/dispBlobber/roi/left:o", "/onTheFlyRec/gaze/blob" )


--ret = ret and yarp.NetworkBase_connect("/manager/googlePort:o", "/yarp-google-speech/rpc" )
--ret = ret and yarp.NetworkBase_connect("/yarp-google-speech/result:o", "/start-ask/speech:i")
--ret = ret and yarp.NetworkBase_connect("/start-ask/start:o", "/iSpeak")

if whichRobot == "icub" then
    print ("Going through ICUB's connection")
--    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/iKinGazeCtrl/angles:i")
--    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/iKinGazeCtrl/rpc")
--    ret = ret and yarp.NetworkBase_connect("/iKinGazeCtrl/angles:o", port_gaze_rx:getName() )
--    ret = ret and yarp.NetworkBase_connect(port_sfm_rpc:getName(),"/SFM/rpc")
--    ret = ret and yarp.NetworkBase_connect(port_are_rpc:getName(),"/actionsRenderingEngine/cmd:io")
--    ret = ret and yarp.NetworkBase_connect(port_cmd_gaze:getName(), "/blob-tracker/command:i" )
else
    print ("Going through R1's connection")
    ret = ret and yarp.NetworkBase_connect(port_gaze_tx:getName(), "/cer_gaze-controller/target:i")
    ret = ret and yarp.NetworkBase_connect(port_gaze_rpc:getName(), "/cer_gaze-controller/rpc")
    ret = ret and yarp.NetworkBase_connect("/cer_gaze-controller/state:o", port_gaze_rx:getName() )
    ret = ret and yarp.NetworkBase_connect(port_cmd_gaze:getName(), "/onTheFlyRec/gaze" )
--    ret = ret and yarp.NetworkBase_connect("/yarpOpenFace/target:o", port_gaze_direction:getName()) GAZE_REMOVED
end
if isAL then
    ret = ret and yarp.NetworkBase_connect("/AnnotationsPropagator/exploration/command:o", port_cmd:getName())
    ret = ret and yarp.NetworkBase_connect(port_cmd_exploration:getName(), '/exploration/command:i')
    ret = ret and yarp.NetworkBase_connect(port_cmd_annotation:getName(), '/blobAnnotation/rpc:i')
    ret = ret and yarp.NetworkBase_connect(port_cmd_karma:getName(), '/karmaMotor/rpc')

end
if isShow then
    ret = ret and yarp.NetworkBase_connect(port_cmd_detection_show:getName(), "/detection/showSup/command:i")
end

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

--yarp.NetworkBase_disconnect("/faceLandmarks/target:o", "/onTheFlyRec/gaze/face")

azi = 0.0
ele = 0.0
ver = 5.0

if whichRobot == "icub" then
    ele = 0.0
else
    ele = 0.0
end

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

function google_start()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("start")
    print("command is ",cmd:toString())
    port_google:write(cmd,reply)
    print("reply is ",reply:toString())
end

function google_stop()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("stop")
    print("command is ",cmd:toString())
    port_google:write(cmd,reply)
    print("reply is ",reply:toString())
end

---------------------------------------
-- functions Point Control           --
---------------------------------------
function ARE_home()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("home")
    cmd:addString("arms")
    print("command is ",cmd:toString())
    port_are_rpc:write(cmd,reply)
    print("reply is ",reply:toString())
end

function get_3D_point(px,py)
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("Root")
    cmd:addDouble(px)
    cmd:addDouble(py)
    print("command is ",cmd:toString())
    port_sfm_rpc:write(cmd,reply)
    print("reply is ",reply:toString())
    return reply
end

function point_3D_point(x,y,z)
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    cmd:clear()
    cmd:addString("point")


    if x < -0.60 then
        x = -0.60
    end
    if x > -0.30 then
        x = -0.30
    end

    if y < -0.30 then
        y = -0.30
    end
    if y > 0.30 then
        y = 0.30
    end

    if z < -0.07 then
        z = -0.07
    end
    if z > 0.0 then
        z = 0.0
    end

    local val = cmd:addList()
    val:addDouble(x+ 0.05)

    if y < 0.0 then
        val:addDouble(y + 0.02)
    else
        val:addDouble(y - 0.02)
    end

    val:addDouble(z)

    if y < 0.0 then
        cmd:addString("left")
    else
        cmd:addString("right")
    end

    print("command is ",cmd:toString())

    if whichRobot == "icub" then
        port_are_rpc:write(cmd,reply)
    end
    print("reply is ",reply:toString())
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

---------------------------------------------------------------------------------------------------------------

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

---------------------------------------
-- functions Drawing                 --
---------------------------------------

function sendDraw(bot)
    local cmd = port_draw_image:prepare()
    cmd:clear()
    cmd:addString("draw")
    for i=0, bot:size()-1,1 do
        local val = cmd:addList()
        val:addInt(bot:get(i):asList():get(0):asInt())
        val:addInt(bot:get(i):asList():get(1):asInt())
        val:addInt(bot:get(i):asList():get(2):asInt())
        val:addInt(bot:get(i):asList():get(3):asInt())
    end

    port_draw_image:write()
end

---------------------------------------------------------------------------------------------------------------

function clearDraw()
    local cmd = port_draw_image:prepare()
    cmd:clear()
    cmd:addString("clear")
    port_draw_image:write()
end

---------------------------------------------------------------------------------------------------------------

function getObjectBB(det, objName)

    local objectList = yarp.Bottle()

    for i=0,det:size()-1,1 do
        str = det:get(i):asList():get(5):asString()

        if str == objName then

            objectList:addInt(det:get(i):asList():get(0):asInt())
            objectList:addInt(det:get(i):asList():get(1):asInt())
            objectList:addInt(det:get(i):asList():get(2):asInt())
            objectList:addInt(det:get(i):asList():get(3):asInt())
        end

    end
    return objectList
end

---------------------------------------------------------------------------------------------------------------

function getObjectIndex(det)
    local indexes = {}
    local count = 0
    for i=0,det:size()-1,1 do
        str = det:get(i):asList():get(5):asString()

        --print ("got as object:", str)

        if isSpeech and state ~= "look-around" then
            --remove anything that is not aplha...
            str = str:gsub("[^a-z.]","")
        end

        --print ("got as object:", str, object)
        if object == str then
            indexes[count] = i
            count = count + 1
        end

    end
    return indexes
end

---------------------------------------------------------------------------------------------------------------

function getCenterObject(det)
    local centerindex =-1
    print("in getCenterObject with size", det:size())
    for i=0,det:size()-1,1 do
        local thistx = (det:get(i):asList():get(0):asInt() + det:get(i):asList():get(2):asInt()) / 2
        local thisty = (det:get(i):asList():get(1):asInt() + det:get(i):asList():get(3):asInt()) / 2

        local distancex = math.abs(160-thistx)
        local distancey = math.abs(120-thisty)

        print("Found object X and object Y ", thistx, thisty)
        print("Found distance X and distance Y ", distancex, distancey)

        if distancex < 60 and distancey < 70 then
            print("Found index i")
            centerindex = i
        end
    end
    return centerindex
end
---------------------------------------------------------------------------------------------------------------

function getClosestObject(det)

    selectObject(det)

    print("getClosestObject for index is ", index, object)
    local objtx = 0
    local objty = 0
    if index >= 0 then
        objtx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
        objty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2
    end

    local mindist = 10000000
    local minindex =-1
    if index >= 0 then
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
    end
    local returnStr
    if minindex < 0 then
        returnStr = "none"
    else
        returnStr = det:get(minindex):asList():get(5):asString()
    end
    if index < 0 then
        returnStr = "notFound"
    end
    return returnStr
end

---------------------------------------------------------------------------------------------------------------

function selectObject(det)
    local indexes

    indexes = getObjectIndex(det)

    print("size of indexes ", table.getn(indexes))

    if indexes[0] ~= nil and table.getn(indexes) >= 0 then

        if table.getn(indexes) > 0 then
            speak(port_ispeak, "I have found " .. table.getn(indexes)+1 .. object .. "s" )
            index = indexes[ math.random(0, table.getn(indexes))]
            speak(port_ispeak, "I randomly chose " .. det:get(index):asList():get(5):asString())
            object = det:get(index):asList():get(5):asString()
            isSpeech = false
        else
            index = indexes[0]
        end
    else
        print("could not find what you are looking for")
        --speak(port_ispeak, "I can't seem to find this object")
        index = -1
    end
end

---------------------------------------------------------------------------------------------------------------

function getObjectsAround(det)

    selectObject(det)

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

            if distance < 6500 then
                objectList:addString(det:get(i):asList():get(5):asString())
            end
        end
    end
    return objectList
end

---------------------------------------------------------------------------------------------------------------

function startAugmentation()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    yarp.NetworkBase_connect("/yarpOpenPose/propag:o", "/data/original" )
    yarp.NetworkBase_connect("/yarp-augmented/image:o", "/data/augmented" )
    yarp.NetworkBase_connect("/yarp-augmented/target:o", "/data/blobs" )
    cmd:clear()
    cmd:addString("startAugmentation")

    port_augmented_rpc:write(cmd,reply)

end

---------------------------------------------------------------------------------------------------------------

function stopAugmentation()
    local cmd = yarp.Bottle()
    local reply = yarp.Bottle()
    yarp.NetworkBase_disconnect("/yarpOpenPose/propag:o", "/data/original" )
    yarp.NetworkBase_disconnect("/yarp-augmented/image:o", "/data/augmented" )
    yarp.NetworkBase_disconnect("/yarp-augmented/target:o", "/data/blobs" )
    cmd:clear()
    cmd:addString("stopAugmentation")

    port_augmented_rpc:write(cmd,reply)
end

---------------------------------------------------------------------------------------------------------------

function sendTrain(objName)
    local cmd = port_cmd_detection:prepare()
    cmd:clear()
    cmd:addString("train")
    cmd:addString(objName)

    port_cmd_detection:write()

    if isShow then
        local cmd_show = port_cmd_detection_show:prepare()
        cmd_show:clear()
        cmd_show:addString("train")
        cmd_show:addString(objName)

        port_cmd_detection_show:write()
    end
end

---------------------------------------------------------------------------------------------------------------

function sendRefine(action)
    local cmd = port_cmd_detection:prepare()
    cmd:clear()
    cmd:addString(action)
    cmd:addString("refinement")

    port_cmd_detection:write()
end

---------------------------------------------------------------------------------------------------------------

function sendExplore(action)
    local cmd = port_cmd_exploration:prepare()
    cmd:clear()
    cmd:addString(action)
    cmd:addString("exploration")

    port_cmd_exploration:write()
end

---------------------------------------------------------------------------------------------------------------

function sendInteract(action)
    local cmd = port_cmd_exploration:prepare()
    cmd:clear()
    cmd:addString(action)
    cmd:addString("interaction")

    port_cmd_exploration:write()
end

---------------------------------------------------------------------------------------------------------------

function sendAnnotationCommand(action, object)
    local cmd = port_cmd_annotation:prepare()
    cmd:clear()
    cmd:addString(action)
    if object ~= nil and action == "doneSelection" then
        cmd:addString(object)
    end

    port_cmd_annotation:write()
end

---------------------------------------------------------------------------------------------------------------

function sendForget(objName)
    local cmd = port_cmd_detection:prepare()
    cmd:clear()
    cmd:addString("forget")
    cmd:addString(objName)
    print ("COMMAND", cmd:toString() )
    port_cmd_detection:write()

    if isShow then
        local cmd_show = port_cmd_detection_show:prepare()
        cmd_show:clear()
        cmd_show:addString("forget")
        cmd_show:addString(objName)

        port_cmd_detection_show:write()
    end
end

---------------------------------------------------------------------------------------------------------------

function startup_interaction()
    -- Send load dataset to first matlab
    local cmd_first_det = port_cmd_detection:prepare()
    cmd_first_det:clear()
    cmd_first_det:addString('load')
    cmd_first_det:addString('dataset')
    cmd_first_det:addString('cts_dataset.mat')
    port_cmd_detection:write()


    -- Send load dataset to second matlab
    local cmd_sec_det = port_cmd_detection_show:prepare()
    cmd_sec_det:clear()
    cmd_sec_det:addString('load')
    cmd_sec_det:addString('dataset')
    cmd_sec_det:addString('cts_dataset.mat')
    port_cmd_detection_show:write()

    -- Send remove tool to karma
    local cmd_karma = port_cmd_karma:prepare()
    cmd_karma:clear()
    cmd_karma:addString('tool')
    cmd_karma:addString('remove')
    port_cmd_karma:write()

    -- Send remove attach to karma
    local cmd_karma = port_cmd_karma:prepare()
    cmd_karma:clear()
    cmd_karma:addString('tool')
    cmd_karma:addString('attach')
    cmd_karma:addString('left')
    cmd_karma:addDouble(0.10)
    cmd_karma:addDouble(-0.16)
    cmd_karma:addDouble(0.2)
    port_cmd_karma:write()
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

if whichRobot == "icub" and isShow and isAL then
    startup_interaction()
end

shouldLook = false
shouldDraw = false
drawNearObjs = false
drawCloseObj = false
drawString = "robot"
isSpeech = false

isInteracting = false
isAugmenting = false

lookedObject = ""

multipleName = yarp.Bottle()
multipleDraw = yarp.Bottle()
refinement_action = ""
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
             cmd_rx == "closest-to" or cmd_rx == "where-is" or
              cmd_rx == "train" or cmd_rx == "forget" or
               cmd_rx == "hello" or cmd_rx == "listen" or 
                cmd_rx == "track" or cmd_rx == "what-is" or
                 cmd_rx == "interact" or cmd_rx == "explore" or 
                  cmd_rx == "annotation" then

            clearDraw()
            multipleDraw:clear()
            multipleName:clear()

            -- Check feasibility of the command
            is_unfeasible_command = cmd_rx == "home" or cmd_rx == "quit" or cmd_rx == "closest-to" or cmd_rx == "where-is" or cmd_rx == "train" or cmd_rx == "forget" or cmd_rx == "hello" or cmd_rx == "listen" or cmd_rx == "track" or cmd_rx == "what-is"
            if state == "refine_interact" and is_unfeasible_command then
                print("Command " .. cmd_rx .. " received while interacting. Doing nothing")
            else
                state = cmd_rx
            end


           -- if cmd_rx ~= "track" then
            --    yarp.NetworkBase_disconnect("/faceLandmarks/target:o", "/onTheFlyRec/gaze/face")
           -- end

            

            if state == "listen" then
                google_start()
                speak(port_ispeak, "yes?")
                
                yarp.delay(3.5)

                google_stop()

            elseif state == "what-is" then

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
                    
                    time_t1 = os.time()

                    look_at_cartesian(tx, ty, tz)
                end


            elseif state == "track" then
                startFace()
                --yarp.NetworkBase_connect("/faceLandmarks/target:o", "/onTheFlyRec/gaze/face")
            elseif state == "hello" then
                if isInteracting == false then
                    look_at_angle(0, 0, 0)
                    yarp.delay(1.5)
                end
                startFace()
                speak(port_ispeak, "How can I help you")
                isInteracting = true

            elseif state == "train" then
                if isInteracting == false then
                    look_at_angle(0, 0, 0)
                    yarp.delay(1.5)
                end

                startGaze()
                object = cmd:get(1):asString()
                sendTrain(object)

                print( "********************************************************************************cmd:size()", cmd:size() )
                print( "********************************************************************************cmd", cmd:get(0):asString(), cmd:get(1):asString(), cmd:get(2):asString(), cmd:get(3):asString() )
                if cmd:size() > 3 then
                    startAugmentation()
                    isAugmenting = true
                    print( "actvated augmented")
                end
                print( "will speak")
                speak(port_ispeak, "Let me have a look at the " .. object)
                print( "training")
                yarp.delay(1.5)

            elseif state == "explore" then
                if isAL then
                    action = cmd:get(1):asString()

                    if action == 'start' then
                        speak(port_ispeak, "ok, I will start exploration ")
                        sendExplore(action)
                        yarp.delay(1.8)
                        sendRefine(action)
                        state = "refine_explore"
                        refinement_action = "exploration"
                    elseif action == 'stop' and refinement_action == "exploration" then
                        speak(port_ispeak, "ok, I will stop exploration ")
                        sendRefine(action)
                        sendExplore(action)
                        state = "home"
                        refinement_action = ""
                    elseif action == 'pause' and refinement_action == "exploration" then
                        print("Pausing exploration")
                        speak(port_ispeak, "I am not sure about what I see, can you help me?")
                        sendExplore(action)
                        state = "refine_explore"
                    elseif action == 'resume' and refinement_action == "exploration" then
                        print("Resuming exploration")
                        speak(port_ispeak, "ok, thank you!")
                        sendExplore(action)
                        state = "refine_explore"
                    else
                        print("Command received does not meet requirements to be accomplished")
                    end
                else
                    print("cannot start refinement, please restart the demo with al option")
                end

            elseif state == "interact" then
                if isAL then
                    action = cmd:get(1):asString()
                    if action == 'start' then
                        speak(port_ispeak, "Ok, I will start exploration ")
--                         speak(port_ispeak, "I am not sure about what I see, can you help me?")
                        print("start interaction")
                        sendInteract("torso")
                        yarp.delay(1.8)
                        sendRefine(action)
                        state = "refine_interact"
                        refinement_action = "interaction_torso"
                    elseif action == 'stop' then
                        if refinement_action == "interaction_stick" then
                            print("Stop interaction_stick")
                            speak(port_ispeak, "ok, I have explored the table. Now I will refine my model. Just wait a few seconds and I will be ready ")
                            sendRefine(action)
                            sendInteract(action)
                            state = "home"
                            refinement_action = ""
                        elseif refinement_action == "interaction_torso" then
                            print("Stop interaction_torso, starting interaction_stick")
                            sendInteract("stick")
                            refinement_action = "interaction_stick"
                            state = "refine_interact"
                        end
                    elseif action == 'fail' and refinement_action == "interaction_stick" then
                        print("Failed interaction_stick")
                        speak(port_ispeak, "The interaction failed. Can you move the objects please? In the meanwhile, I will refine my model. Just wait a few seconds")
                        sendRefine('stop')
                        sendInteract('stop')
                        state = "home"
                        refinement_action = ""
--                    elseif action == 'pause' then
--                        print("Pausing interaction")
--                        speak(port_ispeak, "I am not sure about what I see, can you help me?")
--                        sendInteract(action)
--                        state = "refine"
--                    elseif action == 'resume' then
--                        print("Resuming interaction")
--                        speak(port_ispeak, "ok, thank you!")
--                        sendInteract(action)
--                        state = "refine"
                    else
--                        speak(port_ispeak, "interact: unknown action " .. action)
                        print("interact else with:" .. action .. refinement_action)
                    end
                else
                    print("cannot start refinement, please restart the demo with al option")
                end

            elseif state == "annotation" then
                if isAL then
                    object = nil
                    action = cmd:get(1):asString()

                    if action == 'select' then
                        sendAnnotationCommand('selectDetection', object)
                        speak(port_ispeak, "ok, select it on the tablet")
                    elseif action == 'done' then
                        if cmd:get(2):isString() then
                            object = cmd:get(2):asString()
                            sendAnnotationCommand('doneSelection', object)
                        else
                            speak(port_ispeak, "empty object name")
                        end
                        speak(port_ispeak, "ok, done")
                    elseif action == 'add' then
                        sendAnnotationCommand('addDetection', object)
                        speak(port_ispeak, "where should I put it?")
                    elseif action == 'delete' then
                        sendAnnotationCommand('deleteSelection', object)
                        speak(port_ispeak, "ok, deleted")
                    elseif action == 'finish' then
                        sendAnnotationCommand('finishAnnotation', object)
                    else
                        speak(port_ispeak, "annotation: unknown action " .. action)
                    end
                else
                    print("cannot start refinement, please restart the demo with al option")
                end

            elseif state == "forget" then
                local object = cmd:get(1):asString()
                if  object == "all" then
                    print ("forgetting all objects")
                    object="all"
                    speak(port_ispeak, "Ok, I forgot all the objects")
                else
                    print ("forgetting single object", object)
                    speak(port_ispeak, "Ok, I forgot the " .. object)
                end
                sendForget(object)

            elseif state == "look" then
                clearDraw()
                object = cmd:get(1):asString()
                object = object:lower()
                print ("object chosen is", object)
                drawNearObjs = false
                drawCloseObj = false

                local det = port_detection:read(false)

                if det ~= nil then
                    print("looping det ", det:size())
                    print("det not nil")

                    selectObject(det)

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

                        speak(port_ispeak, "looking at the " .. object)
                     end
                else
                    print("det nil")
                    speak(port_ispeak, "I do not see any objects")
                end

            elseif state == "home" then
                clearDraw()
                stopGaze()
                yarp.delay(0.5)
                look_at_angle(azi, ele, ver)
                speak(port_ispeak, "OK")

            elseif state == "look-around" then
                speak(port_ispeak, "OK, I will look around")
                shouldLook = true
            elseif state == "closest-to" then
                object = cmd:get(1):asString()
                object = object:lower()
                local det = port_detection:read(false)

                if det ~= nil then
                    local name = getClosestObject(det)
                    local tosay
                    if name == "none" then
                        tosay = "There is nothing close to the " .. object
                    elseif name == "notFound" then
                        tosay = "I can't seem to find the " .. object
                    else
                        tosay = "The closest object is the " .. name
                    end
                    --multipleName:clear()
                    --multipleName:addString(name)
                    drawCloseObj = true
                    drawNearObjs = false

                    state = "look"
                    speak(port_ispeak, tosay)
                else
                    print("det nil")
                    speak(port_ispeak, "I do not see any objects")
                end
            elseif state == "where-is" then
                yarp.delay(1.0)
                object = cmd:get(1):asString()
                object = object:lower()
                local det = port_detection:read(false)

                if det ~= nil then

                    --first look at the object
                    selectObject(det)

                    local tx
                    local ty
                    if index >= 0 then

                        tx = (det:get(index):asList():get(0):asInt() + det:get(index):asList():get(2):asInt()) / 2
                        ty = (det:get(index):asList():get(1):asInt() + det:get(index):asList():get(3):asInt()) / 2

                        print( "tx is", tx )
                        print( "ty is", ty )
                        if whichRobot == "icub" then
                            local point3D = get_3D_point(tx, ty)
                            local cartx = point3D:get(0):asDouble()
                            local carty = point3D:get(1):asDouble()
                            local cartz = point3D:get(2):asDouble()

                            print("the 3D point is ", cartx, carty, cartz )
                        end
                        look_at_pixel("left",tx,ty)

                        --delay one second to let the head move ok...
                        yarp.delay(1.0)

                        local list = yarp.Bottle()
                        list = getObjectsAround(det)
                        --multipleName:clear()
                        drawNearObjs = true
                        drawCloseObj = false
                        print("size of near objects is ", list:size() )

                        if list:get(0):asString() == "none" then
                            local tosay = "I cannot see the " .. object
                            speak(port_ispeak, tosay)
                            state = "look"
                        elseif list:size() < 1 and list:get(0):asString() ~= "none" then
                            local tosay = "Here is the  " .. object
                            speak(port_ispeak, tosay)
                            if whichRobot == "icub" then
                                point_3D_point(cartx, carty, cartz)
                            end
                            state = "look"
                        else
                            local tosay = "The " .. object .. " is next to the "
                            for i=0,list:size()-1,1 do
                                if i > 0 then
                                    tosay = tosay .. " and the "
                                end
                                tosay = tosay .. list:get(i):asString()
                                --multipleName:addString(list:get(i):asString())
                            end
                            print(tosay)
                            speak(port_ispeak, tosay)
                            if whichRobot == "icub" then
                                point_3D_point(cartx, carty, cartz)
                            end
                            state = "look"
                        end

                    end
                else
                    print("det nil")
                    speak(port_ispeak, "I do not see any objects")
                end
            end
        else
            print("warning: unrecognized command")
        end

    end

    if state == "train" then
        local det = port_detection:read(true)

        if det:get(0):asList():size() > 0 then
            print("detection ", det:toString())
            if det:get(0):asList():get(0):asString() == "train" then
                print("FOUND  TRAINING ")
            else
                state = "home"
                local tosay = "Excellent, now I know the " .. object
                speak(port_ispeak, tosay)
                stopGaze()
                yarp.delay(0.5)
                look_at_angle(0, 0, 0)

                --startFace()
                speak(port_ispeak, "How can I help you")
                isInteracting = true
                
                if isAugmenting then
                    stopAugmentation()
                    isAugmenting = false
                end
            end
        end
    elseif state == "refine_interact" then
        yarp.delay(0.1)
    elseif state == "annotation" then
        state = "refine_interact"
    elseif state == "refine_explore" then
        yarp.delay(0.1)
    elseif state == "forget" then
        yarp.delay(0.1)
    elseif state == "home" then
            yarp.delay(0.1)

    elseif state == "look" then

        local det = port_detection:read(false)
        if det ~= nil then
            local indexes = getObjectIndex(det)

            index = indexes[0]
            multipleDraw:clear()

            if drawCloseObj then
                local name = getClosestObject(det)
                multipleName:clear()
                multipleName:addString(name)
            end

            if drawNearObjs then

                local list = getObjectsAround(det)
                multipleName:clear()

                for i=0,list:size()-1,1 do
                    multipleName:addString(list:get(i):asString())
                end
            end

            for i=0,multipleName:size()-1,1 do
                local elements = multipleDraw:addList()
                local bbs = getObjectBB(det, multipleName:get(i):asString())
                for i=0,bbs:size()-1,1 do
                    elements:addInt(bbs:get(i):asInt())
                end
            end


            if index ~=nil and index >= 0 then
                local bot = yarp.Bottle()
                local val = bot:addList()
                val:addInt(det:get(index):asList():get(0):asInt())
                val:addInt(det:get(index):asList():get(1):asInt())
                val:addInt(det:get(index):asList():get(2):asInt())
                val:addInt(det:get(index):asList():get(3):asInt())

                for i=0,multipleDraw:size()-1,1 do
                    local val = bot:addList()
                    val:addInt(multipleDraw:get(i):asList():get(0):asInt())
                    val:addInt(multipleDraw:get(i):asList():get(1):asInt())
                    val:addInt(multipleDraw:get(i):asList():get(2):asInt())
                    val:addInt(multipleDraw:get(i):asList():get(3):asInt())
                end

                --print(bot:toString())

                sendDraw(bot)
            end

            clearDraw()
        end
        yarp.delay(0.1)

    elseif state == "what-is" then
        
        time_t2 = os.difftime(os.time(), time_t1)

        local det = port_detection:read(false)
        local found = false
        if det ~= nil then
            local index = getCenterObject(det)
            if index > -1 then
                local object = det:get(index):asList():get(5):asString()
                speak(port_ispeak, "I think this is a " .. object)
                found = true
            end
        end

        if time_t2 > 4 or found then
            clearDraw()
            stopGaze()
            yarp.delay(0.5)
            look_at_angle(azi, ele, ver)
            --speak(port_ispeak, "OK")
            state = "look"
        end

    elseif state == "look-around" then
        local det = port_detection:read(false)

        if det ~= nil then

            --print( "dets", det:toString())
            --print("dets size", det:size())
            --print( "size elements dets", det:get(0):asList():size())

            math.randomseed( os.time() )
            math.random(); math.random(); math.random()

            if det:get(0):asList():size() ~= 0 then
               local num = 0


                if det:size() > 0 then
                    num = math.random(0, det:size()-1)
                else
                    num = 0
                end


                if det:size() > 1 then
                    while det:get(num):asList():get(5):asString() == lookedObject do
                        num = math.random(0, det:size()-1)
                    end
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

                    local indexes = getObjectIndex(det)
                    index = indexes[0]

                    if index ~=nil and index >= 0 then
                        local bot = yarp.Bottle()
                        local val = bot:addList()
                        val:addInt(det:get(index):asList():get(0):asInt())
                        val:addInt(det:get(index):asList():get(1):asInt())
                        val:addInt(det:get(index):asList():get(2):asInt())
                        val:addInt(det:get(index):asList():get(3):asInt())

                        sendDraw(bot)
                    end
                end
                yarp.delay(0.1)
            end
        end

    elseif state == "look" then
        yarp.delay(0.1)
    end
end

clearDraw()

if whichRobot == "icub" then
    look_at_angle(0, 0, 5)
else
    look_at_angle(0, 0, 5)
end

stopGaze()
speak(port_ispeak, "Bye bye")

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
clearDraw()
port_draw_image:close()
port_cmd_gaze:close()
port_google:close()

yarp.Network_fini()
