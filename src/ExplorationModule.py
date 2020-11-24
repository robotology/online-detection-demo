#!/usr/bin/env python

import yarp
import sys
import time

# Initialise YARP
yarp.Network.init()

class ExplorationModule (yarp.RFModule):
    def configure(self, rf):

        self.module_name = rf.find("module_name").asString()
        num_steps = rf.find("steps").asInt()
        print(num_steps)

        self.parts = ['right_arm', 'left_arm', 'torso', 'head']
        #self.parts = ['right_arm']

        # Example of steps structure
        # t = {'position': [-21.742, 20.0391, -9.93166, 35.0684, 0.977786, 0.0298225, -0.0565045, 0.163115], 'time': 4.0}
        # s = {'right_arm': t}
        # self.steps = {'1': s}

        print('Gathering home position')
        self.home = {}
        for part in self.parts:
            part_name = 'home_' +  part
            if rf.check(part_name):
                print('Found {}'.format(part_name))
                rf_group = rf.findGroup(part_name)
                if part is not 'torso':
                    pos_list = rf_group.find('position').asList()
                    p = [None] * pos_list.size()
                    for j in range(0, pos_list.size()):
                        p[j] = pos_list.get(j).asDouble()
                    t = {'position': p, 'time': rf_group.find('time').asDouble()}
                else:
                    poss_list = rf_group.find('poss').asList()
                    p = [None] * poss_list.size()
                    for j in range(0, poss_list.size()):
                        p[j] = poss_list.get(j).asDouble()

                    vels_list = rf_group.find('vels').asList()
                    v = [None] * vels_list.size()
                    for j in range(0, vels_list.size()):
                        v[j] = vels_list.get(j).asDouble()
                    t = {'vels': v, 'poss': p}
            self.home[part] = t

        self.steps = {}
        for i in range(0, num_steps):
            s = {}
            for part in self.parts:
                part_name = str(i) + '_' +  part
                if rf.check(part_name):
                    print('Found {}'.format(part_name))
                    rf_group = rf.findGroup(part_name)
                    if part is not 'torso':
                        pos_list = rf_group.find('position').asList()
                        p = [None] * pos_list.size()
                        for j in range(0, pos_list.size()):
                            p[j] = pos_list.get(j).asDouble()
                        t = {'position': p, 'time': rf_group.find('time').asDouble()}
                    else:
                        poss_list = rf_group.find('poss').asList()
                        p = [None] * poss_list.size()
                        for j in range(0, poss_list.size()):
                            p[j] = poss_list.get(j).asDouble()

                        vels_list = rf_group.find('vels').asList()
                        v = [None] * vels_list.size()
                        for j in range(0, vels_list.size()):
                            v[j] = vels_list.get(j).asDouble()
                        t = {'vels': v, 'poss': p}
                s[part] = t
            self.steps[str(i)] = s

        print(self.steps)
            
        self.state = 'do_nothing'
        self.parts_state = {}
        self.parts_state_previous = {}
        rf_group = rf.findGroup('parts')
        for part in self.parts:
            self.parts_state[part] = [None] * rf_group.find(part).asInt()
            self.parts_state_previous[part] = [None] * rf_group.find(part).asInt()

        self.current_step = 0
        self.out_ports = {}
        self.in_ports = {}

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)
        self.is_same_counter = 100

        time.sleep(3)
        for i in range(0, len(self.parts)):
            self.in_port = yarp.BufferedPortBottle()
            self.in_port.open('/' + self.module_name + '/' + self.parts[i] + ':i')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':i'))
            print(yarp.NetworkBase.connect('/cer/' + self.parts[i] + '/state:o', '/' + self.module_name + '/' + self.parts[i] + ':i'))
            self.in_ports[self.parts[i]] = self.in_port

            self.out_port = yarp.Port()
            self.out_port.open('/' + self.module_name + '/' + self.parts[i] + ':o')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':o'))
            connected = False
            if self.parts[i] is not 'torso':
                connected = yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o', '/ctpservice/' + self.parts[i] + '/rpc')
                print(connected)
            else:
                connected = yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o', '/cer/' + self.parts[i] + '/rpc:i')
                print(connected)
            if not connected:
                print('Error: missing connections')
                self.cleanup()
                sys.exit()
            
            self.out_ports[self.parts[i]] = self.out_port

        return True

    def move_all_to(self, position, secs):
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

    def move_torso_to(self, target_v, target_p):
        to_send_v = yarp.Bottle()
        to_send_v.clear()

        to_send_v.addString('set')
        to_send_v.addString('vels')
        t = to_send_v.addList()
        for i in range(0, len(target_v)):
            t.addDouble(target_v[i])

        to_send_p = yarp.Bottle()
        to_send_p.clear()

        to_send_p.addString('set')
        to_send_p.addString('poss')
        t = to_send_p.addList()
        for i in range(0, len(target_p)):
            t.addDouble(target_p[i])

        return [to_send_v, to_send_p]

    def send_commands(self, commands):
        for part in commands:
            if part is not 'torso':
                self.out_ports[part].write(commands[part])
            else:
                self.out_ports[part].write(commands[part][0])
                self.out_ports[part].write(commands[part][1])

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
        elif command.get(0).asString() == 'stop':
            if self.state == 'exploration':
                print('Stopping exploration. Going home.')
                self.state = 'home'
                reply.addString('Exploration stopped')
            else:
                print('The robot is not exploring. Going home.')
                self.state = 'home'
                reply.addString('The robot is not exploring. Going home.')
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
            is_same = True
            for part in self.parts_state:
                if is_same:
                    for i in range(0, len(self.parts_state[part])):
                        if not self.parts_state_previous[part][i] is None and abs(self.parts_state[part][i] - self.parts_state_previous[part][i]) > 0.1:
                           is_same = False
                           break
                else:
                    break
            
            if is_same:
                self.is_same_counter = self.is_same_counter + 1
            else:
                self.is_same_counter = 0

            if self.is_same_counter > 250:
                for part in self.parts_state:
                    self.parts_state_previous[part] = self.parts_state[part].copy()
                print('is the same')
                self.state = 'start'
                self.current_step = self.current_step + 1
                self.is_same_counter = 0
                print(self.current_step)
                if self.current_step >= len(self.steps):
                    self.current_step = 0
                    self.state = 'do_nothing'
                    print('switch to do nothing')
                else:
                    print(self.steps[str(self.current_step)])
            else:

                for part in self.parts_state:
                    self.parts_state_previous[part] = self.parts_state[part].copy()
                #print('is not the same')

        elif self.state == 'start':
            print('state start')
            print(self.current_step)
            step = self.steps[str(self.current_step)]
            commands = {}
            for part in step:
                print(part)
                if part is not 'torso':
                    target_p = step[part]['position']
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    target_p = step[part]['poss']
                    target_v = step[part]['vels']
                    commands[part] = self.move_torso_to(target_v, target_p)
            self.send_commands(commands)
            self.state = 'exploration'

        elif self.state == 'pause':
            #time.sleep(0.1)
            print('pause state')
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
                if part is not 'torso':
                    target_p = self.parts_state[part]
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    target_p = self.parts_state[part]
                    target_v = step[part]['vels']
                    commands[part] = self.move_torso_to(target_v, target_p)
            self.send_commands(commands)
            self.send_commands(commands)
            self.state = 'do_nothing'

        elif self.state == 'home':
            print('state home')
            step = self.home
            commands = {}
            for part in step:
                print(part)
                if part is not 'torso':
                    target_p = step[part]['position']
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    target_p = step[part]['poss']
                    target_v = step[part]['vels']
                    commands[part] = self.move_torso_to(target_v, target_p)
            self.send_commands(commands)
            self.current_step = 0
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
        rf.setDefaultConfigFile('../app/config/exploration_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    em = ExplorationModule()
    em.runModule(rf)
