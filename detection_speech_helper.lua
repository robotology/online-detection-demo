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

objects = {"sprayer", "mug", "flower", "sodabottle"}

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

function sendSpeech(port, cmd)
   local wb = port:prepare()
   wb:clear()
   wb=cmd
   port:write()
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

    if cmd ~= nil then
        sendSpeech(port_speech_output, cmd)
    end
end

port_speech_recog:close()
port_speech_output:close()
yarp.Network_fini()
