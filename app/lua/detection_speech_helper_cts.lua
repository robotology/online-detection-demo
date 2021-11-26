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

---------------------------------------
-- setting up ctrl-c signal handling --
---------------------------------------

interrupting = false
signal.signal(signal.SIGINT, function(signum)
    interrupting = true
end)

signal.signal(signal.SIGTERM, function(signum)
    interrupting = true
end)

---------------------------------------
-- yarp port initializations         --
---------------------------------------
yarp.Network()

port_speech_recog = yarp.Port()
port_speech_output = yarp.Port()

port_speech_recog:open("/detection/recognition:o")
port_speech_output:open("/detection/speech:o")

ret = true
ret = ret and yarp.NetworkBase_connect(port_speech_recog:getName(), "/speechRecognizer/rpc")

if ret == false then
    print("\n\nERROR WITH CONNECTIONS, PLEASE CHECK\n\n")
    os.exit()
end

---------------------------------------
-- functions Speech Recognition      --
---------------------------------------

objects = {"sprayer", "mug", "flower", "bottle", "book", "wallet", "toy", "badge", "phone", "soda", "master", "mustard",}

-- defining speech grammar in order to expand the speech recognition
grammar="Look around | Look at the #Object | Where is the #Object | See you soon | What is close to the #Object | Have a look at this #Object | Forget the #Object | Forget all objects | Explore the table and interact | Stop exploration | Stop interaction | Add one object | Let me select one object | Delete it | Annotation completed | It is a #Object"

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

function sendSpeech(port, cmd)
   --local wb = port:prepare()
   local wb = yarp.Bottle()
   wb:clear()
   wb=cmd
   port:write(wb)
end

print ("expanding speech recognizer grammar")
ret = true
for key, word in pairs(objects) do
    ret = ret and (SM_RGM_Expand(port_speech_recog, "#Object", word) == "OK")
end
if ret == false then
    print("errors expanding the vocabulary")
end

print ("ready to receive command ")

---------------------------------------
-- While loop for various modalities --
---------------------------------------

while state ~= "quit" and not interrupting do

    local result = SM_Reco_Grammar(port_speech_recog, grammar)
    print("received REPLY: ", result:toString() )

    local risotto = result:size()

    local speechcmd =  result:get(1):asString()

    local instruction = yarp.Bottle()

    if speechcmd == "See" then
        instruction:addString("quit")
    elseif speechcmd == "Look" and result:get(3):asString() == "around" then
        instruction:addString("look-around")
    elseif speechcmd == "Look" and result:get(3):asString() == "at" then
        local object = result:get(7):asString()
        if object == "table" then
            instruction:addString("home")
        else
            instruction:addString("look")
            instruction:addString(object)
        end
    elseif speechcmd == "What" then
        if result:get(5):asString() == "close" then
            instruction:addString("closest-to")
            local object = result:get(11):asString()
            instruction:addString(object)
        elseif result:get(5):asString() == "this" then
            instruction:addString("what-is")
        end
    elseif speechcmd == "Where" then
        instruction:addString("where-is")
        local object = result:get(7):asString()
        instruction:addString(object)
    elseif speechcmd == "Have" then
        instruction:addString("train")
        local object = result:get(11):asString()
        instruction:addString(object)
        end
    elseif speechcmd == "Explore" then
        instruction:addString("interact")
        instruction:addString("start")
    elseif speechcmd == "Stop" then
        instruction:addString(result:get(3):asString())
        instruction:addString("stop")
    elseif speechcmd == "Let" then
        instruction:addString("annotation")
        instruction:addString("select")
    elseif speechcmd == "It" then
        instruction:addString("annotation")
        instruction:addString("done")
        local object = result:get(7):asString()
        instruction:addString(object)
    elseif speechcmd == "Add" then
        instruction:addString("annotation")
        instruction:addString("add")
    elseif speechcmd == "Delete" then
        instruction:addString("annotation")
        instruction:addString("delete")
    elseif speechcmd == "Annotation" then
        instruction:addString("annotation")
        instruction:addString("finish")
    elseif speechcmd == "Forget" then
        instruction:addString("forget")
        local object = ""
        if result:get(3):asString() == "all" then
            object = "all"
        else
            object = result:get(5):asString()
        end
        instruction:addString(object)
    else
        print ("cannot recognize the command")
    end

    if instruction:size() ~= 0 then
        instruction:addString("speech")
        sendSpeech(port_speech_output, instruction)
        if speechcmd == "Listen" then
            yarp.delay(3.5)
        end
    end
end

port_speech_recog:close()
port_speech_output:close()
yarp.Network_fini()
