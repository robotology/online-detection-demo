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
        # self.parts = ['right_arm', 'left_arm', 'torso', 'head']
        self.parts = ['right_arm']
        self.parts_state = {'right_arm': [None] *8}

        self.current_step = 1
        self.out_ports = {}
        self.in_ports = {}

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        for i in range(0, len(self.parts)):
            self.in_port = yarp.BufferedPortBottle()
            self.in_port.open('/' + self.module_name + '/' + self.parts[i] + ':i')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':i'))
            print(yarp.NetworkBase.connect('/cer/' + self.parts[i] + '/state:o', '/' + self.module_name + '/' + self.parts[i] + ':i'))
            self.in_ports['right_arm'] = self.in_port

            self.out_port = yarp.Port()
            self.out_port.open('/' + self.module_name + '/' + self.parts[i] + ':o')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':o'))
            print(yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o', '/ctpservice/' + self.parts[i] + '/rpc'))
            self.out_ports[self.parts[i]] = self.out_port

        target = {'position': [-21.742, 20.0391, -9.93166, 35.0684, 0.977786, 0.0298225, -0.0565045, 0.163115], 'time': 4.0}
        step1 = {'right_arm': target}
        self.steps = {'1': step1}

        return True

    def move_to(self, position, secs):
        to_send = yarp.Bottle()
        to_send.clear()

        to_send.addString('ctpn')
        to_send.addString('time')
        to_send.addDouble(secs)
        to_send.addString('off')
        to_send.addInt(0)
        to_send.addString('pos')
        t = to_send.addList()
        for i in range(0, len(position)):
            t.addDouble(position[i])
        return to_send

    def send_commands(self, commands):
        for part in commands:
            self.out_ports[part].write(commands[part])

    def respond(self, command, reply):
        if command.get(0).asString() == 'start':
            print('Starting exploration')
            self.state = 'start'           
            reply.addString('Exploration started')
        elif command.get(0).asString() == 'pause':
            print('Pausing exploration')
            self.state = 'pause'            
            reply.addString('Exploration paused')
        elif command.get(0).asString() == 'resume':
            print('Resuming exploration')
            self.state = 'start'
            reply.addString('Exploration resumed')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))
        return True

    def cleanup(self):
        print('Cleanup function')
        for part in self.out_ports:
            self.out_ports[part].close()
        for part in self.in_ports:
            self.in_ports[part].close()

        self.cmd_port.close()

    def interruptModule(self):
        print('Interrupt function')
        for part in self.out_ports:
            self.out_ports[part].interrupt()
        for part in self.in_ports:
            self.in_ports[part].interrupt()

        self.cmd_port.interrupt()
        return True

    def getPeriod(self):
        return 0.001

    def updateModule(self):
        if self.state == 'exploration':
            for part in self.parts_state:
                state_bottle = yarp.Bottle()
                state_bottle.clear()
                state_bottle = self.in_ports[part].read()
                for i in range(0, state_bottle.size()):
                    self.parts_state[part][i] = state_bottle.get(i).asDouble()

        elif self.state == 'start':
            step = self.steps[str(self.current_step)]
            commands = {}
            for part in step:
                print(part)
                target_p = step[part]['position']
                target_t = step[part]['time']
                commands[part] = self.move_to(target_p, target_t)
            self.send_commands(commands)
            self.state = 'exploration'

        elif self.state == 'pause':
            time.sleep(0.1)
            for part in self.parts_state:
                state_bottle = yarp.Bottle()
                state_bottle.clear()
                state_bottle = self.in_ports[part].read()
                for i in range(0, state_bottle.size()):
                    self.parts_state[part][i] = state_bottle.get(i).asDouble()
            print(self.current_step)
            step = self.steps[str(self.current_step)]
            commands = {}
            for part in step:
                print(part)
                target_p = self.parts_state[part]
                target_t = step[part]['time']
                commands[part] = self.move_to(target_p, 1.0)
            self.send_commands(commands)
            self.state = 'do_nothing'

        elif self.state == 'do_nothing':
            pass
        else:
            print('state {:s} unknown'.format(self.state))
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
