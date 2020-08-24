#!/usr/bin/env python

import yarp
import sys

# Initialise YARP
yarp.Network.init()

class ExplorationModule (yarp.RFModule):
    def configure(self, rf):

        self.module_name = 'exploration'

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        self.right_arm_in = yarp.BufferedPortBottle()
        self.right_arm_in.open('/' + self.module_name + '/right_arm:i')
        print('{:s} opened'.format('/' + self.module_name + '/right_arm:i'))
        print(yarp.NetworkBase.connect('/cer/right_arm/state:o', '/' + self.module_name + '/right_arm:i'))

        self.right_arm_out = yarp.Port()
        self.right_arm_out.open('/' + self.module_name + '/right_arm:o')
        print('{:s} opened'.format('/' + self.module_name + '/right_arm:o'))
        print(yarp.NetworkBase.connect('/' + self.module_name + '/right_arm:o', '/ctpservice/right_arm/rpc'))

        #self.right_arm_target = [-21.742, 20.0391, -9.93166, 35.0684, 0.977786, 0.0298225, -0.0565045, 0.163115]

        self.right_arm_state = [None] *8

        return True

    def start_right_arm(self):
        #to_send = self.right_arm_out.prepare()
        #to_send.clear()
        to_send = yarp.Bottle()

        #to_send.addString('ctpn time 4.0 off 0 pos (-21.742 20.0391 -9.93166 35.0684 0.977786 0.0298225 -0.0565045 0.163115)')

        to_send.addString('ctpn')
        to_send.addString('time')
        to_send.addDouble(4.0)
        to_send.addString('off')
        to_send.addInt(0)
        to_send.addString('pos')
        t = to_send.addList()
        t.addDouble(-21.742)
        t.addDouble(20.0391)
        t.addDouble(-9.93166)
        t.addDouble(35.0684)
        t.addDouble(0.977786)
        t.addDouble(0.0298225)
        t.addDouble(-0.0565045)
        t.addDouble(0.163115)
        self.right_arm_out.write(to_send)

    def respond(self, command, reply):
        if command.get(0).asString() == 'start':
            print('Starting exploration')
            self.state = 'exploration'
            self.start_right_arm()
            reply.addString('Exploration started')
        elif command.get(0).asString() == 'pause':
            print('Pausing exploration')
            self.state = 'exploration'
            reply.addString('Exploration paused')
            #self.start_right_arm()
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))
        return True

    def cleanup(self):
        self.right_arm_in.close()
        self.right_arm_out.close()
        print('Cleanup function')

    def interruptModule(self):
        print('Interrupt function')
        self.right_arm_in.interrupt()
        self.right_arm_out.interrupt()
        return True

    def getPeriod(self):
        return 0.001

    def updateModule(self):
        #print('Reading right arm position')

        right_arm_bottle = yarp.Bottle()
        right_arm_bottle.clear()
        right_arm_bottle = self.right_arm_in.read()

        if right_arm_bottle.size() == 8:
             for i in range(0, right_arm_bottle.size()):
                 self.right_arm_state[i] = right_arm_bottle.get(i).asDouble()
             #print(self.right_arm_state)
        return True

if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("ExplorationModule")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../app/config/ws_module_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    em = ExplorationModule()
    em.runModule(rf)
