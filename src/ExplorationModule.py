#!/usr/bin/env python

import yarp
import sys
import time

# Initialise YARP
yarp.Network.init()

class ExplorationModule (yarp.RFModule):
    def configure(self, rf):

        self.module_name = 'exploration'
        self.state = 'exploration'

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

        self.right_arm_target = [-21.742, 20.0391, -9.93166, 35.0684, 0.977786, 0.0298225, -0.0565045, 0.163115]
        self.right_arm_second_target = [45.7581683549032, 19.8633297444574, -10.0195557118059, 35.0684449913208, 0.0878908395772451, 0.0298284026456716, -0.0376695839922819, 0.195737309062505]

        self.right_arm_third_target = [67.203533211751, 19.8633297444574, -9.93166487222869, 34.9805541517435, -0.335083825888247, 0.0298402369665474, -0.0565044665613339, -0.163114618112221]

        self.right_arm_state = [None] *8

        return True

    def move_to(self, position):
        to_send = yarp.Bottle()
        to_send.clear()

        to_send.addString('ctpn')
        to_send.addString('time')
        to_send.addDouble(4.0)
        to_send.addString('off')
        to_send.addInt(0)
        to_send.addString('pos')
        t = to_send.addList()
        for i in range(0, len(position)):
            t.addDouble(position[i])
        return to_send

    def send_command(self, to_send):
        self.right_arm_out.write(to_send)

    def respond(self, command, reply):
        if command.get(0).asString() == 'start':
            print('Starting exploration')
            self.state = 'exploration'
            to_send = self.move_to(self.right_arm_target)
            self.send_command(to_send)
            reply.addString('Exploration started')
        elif command.get(0).asString() == 'pause':
            print('Pausing exploration')
            self.state = 'pause'
            print(self.right_arm_state)
            time.sleep(0.08)
            to_send2 = self.move_to(self.right_arm_state)
            self.send_command(to_send2)
            reply.addString('Exploration paused')
        elif command.get(0).asString() == 'resume':
            print('Resuming exploration')
            self.state = 'exploration'
            to_send = self.move_to(self.right_arm_target)
            self.send_command(to_send)
            reply.addString('Exploration resumed')
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
        if self.state == 'exploration':
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
