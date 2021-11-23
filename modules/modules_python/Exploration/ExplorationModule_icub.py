#!/usr/bin/env python

import yarp
import sys
import time
import numpy as np
from pyquaternion import Quaternion
import math

# Initialise YARP
yarp.Network.init()


class ExplorationModule (yarp.RFModule):
    def configure(self, rf):
        self.robot = 'icub'

        self.module_name = rf.find("module_name").asString()
        print('MODULE_NAME: {}'.format(self.module_name))
        self.is_interaction = rf.find("is_interaction").asBool()
        self.is_exploration = rf.find("is_exploration").asBool()

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        if self.is_exploration:
            self.configure_exploration(rf)

        if self.is_interaction:
            self.configure_interaction(rf)

        self.state = 'do_nothing'

        return True

    def configure_interaction(self, rf):
        print('configure_interaction function')

        self.arm = rf.find("arm").asString()  # self.arm = 'left' or 'right'
        if self.arm == 'right':
            print('**************************************** WARNING: Actions with right arm not implemented ****************************************')

        # Prepare ports and images for receiving inputs
        self.image_w = rf.find("image_w").asInt()
        self.image_h = rf.find("image_h").asInt()

        # self.camera_fx = 618.0714111328125
        # self.camera_fy = 617.783447265625
        # self.camera_cx = 305.902252197265625
        # self.camera_cy = 246.352935791015625
        self.camera_fx = rf.find("camera_fx").asDouble()
        self.camera_fy = rf.find("camera_fy").asDouble()
        self.camera_cx = rf.find("camera_cx").asDouble()
        self.camera_cy = rf.find("camera_cy").asDouble()

        self.camera_pose_port = yarp.BufferedPortVector()
        self.camera_pose_port.open('/' + self.module_name + '/camera_pose:i')
        connected = yarp.Network().connect('/realsense-holder-publisher/pose:o', '/' + self.module_name + '/camera_pose:i')
        print('{}: {}'.format('/' + self.module_name + '/camera_pose:i', connected))

        self.target_in_port = yarp.BufferedPortBottle()
        self.target_in_port.open('/' + self.module_name + '/target:i')
        #connected = yarp.Network().connect('/dispBlobber/roi/left:o', '/' + self.module_name + '/target:i')
        #print('{}: {}'.format('/' + self.module_name + '/target:i', connected))

        self.depth_in_port = yarp.BufferedPortImageFloat()
        self.depth_in_port.open('/' + self.module_name + '/depth:i')
        connected = yarp.Network().connect('/depthCamera/depthImage:o', '/' + self.module_name + '/depth:i')
        print('{}: {}'.format('/' + self.module_name + '/depth:i', connected))

        self.depth_img = yarp.ImageFloat()
        self.depth_img.resize(self.image_w, self.image_h)
        self.depth_array = np.ones((self.image_h, self.image_w, 1), dtype=np.float32)
        self.depth_img.setExternal(self.depth_array.data, self.depth_array.shape[1], self.depth_array.shape[0])

        self.cam_H = None
        self.target_H = None
        self.target_np_to_send = None
        self.dimension = 0.0
        self.delta = 0.08
        self.interaction_sent = True
        self.torso_sent = True

        # Open port to give feedback on exploration

        # Open ports to communicate with karma
        # self._karma_commands_port = yarp.BufferedPortBottle()
        self._karma_commands_port = yarp.RpcClient()
        self._karma_commands_port.open('/' + self.module_name + '/karma_commands:o')
        print('{:s} opened'.format('/' + self.module_name + '/karma_commands:o'))

        # Open ports to communicate with ARE
        self._are_commands_port = yarp.RpcClient()
        self._are_commands_port.open('/' + self.module_name + '/are_commands:o')
        print('{:s} opened'.format('/' + self.module_name + '/are_commands:o'))

        # Open ports to communicate with ws module
        self._ws_commands_port = yarp.RpcClient()
        self._ws_commands_port.open('/' + self.module_name + '/ws_commands:o')
        print('{:s} opened'.format('/' + self.module_name + '/ws_commands:o'))

        return True

    def configure_exploration(self, rf):
        num_steps = rf.find("steps").asInt()
        print(num_steps)

        self.parts = ['right_arm', 'left_arm', 'torso', 'head']
        #self.parts = ['right_arm']

        # Example of steps structure
        # t = {'position': [-21.742, 20.0391, -9.93166, 35.0684, 0.977786, 0.0298225, -0.0565045, 0.163115],
        #      'time': 4.0}
        # s = {'right_arm': t}
        # self.steps = {'1': s}

        print('Gathering home position')
        self.home = {}
        for part in self.parts:
            part_name = 'home_' +  part
            if rf.check(part_name):
                print('Found {}'.format(part_name))
                rf_group = rf.findGroup(part_name)
                if self.robot == 'r1':
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
                elif self.robot == 'icub':
                    pos_list = rf_group.find('position').asList()
                    p = [None] * pos_list.size()
                    for j in range(0, pos_list.size()):
                        p[j] = pos_list.get(j).asDouble()
                    t = {'position': p, 'time': rf_group.find('time').asDouble()}
                else:
                    print('Robot {} unknown'.format(self.robot))
            self.home[part] = t

        self.steps = {}
        for i in range(0, num_steps):
            s = {}
            for part in self.parts:
                part_name = str(i) + '_' +  part
                if rf.check(part_name):
                    print('Found {}'.format(part_name))
                    rf_group = rf.findGroup(part_name)
                    if self.robot == 'r1':
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
                    elif self.robot == 'icub':
                        pos_list = rf_group.find('position').asList()
                        p = [None] * pos_list.size()
                        for j in range(0, pos_list.size()):
                            p[j] = pos_list.get(j).asDouble()
                        t = {'position': p, 'time': rf_group.find('time').asDouble()}
                    else:
                        print('Robot {} unknown'.format(self.robot))
                s[part] = t
            self.steps[str(i)] = s

        print(self.steps)

        self.parts_state = {}
        self.parts_state_previous = {}
        rf_group = rf.findGroup('parts')
        for part in self.parts:
            self.parts_state[part] = [None] * rf_group.find(part).asInt()
            self.parts_state_previous[part] = [None] * rf_group.find(part).asInt()

        self.current_step = 0
        self.out_ports = {}
        self.in_ports = {}

        self.is_same_counter = 100

        time.sleep(3)
        for i in range(0, len(self.parts)):
            self.in_port = yarp.BufferedPortBottle()
            self.in_port.open('/' + self.module_name + '/' + self.parts[i] + ':i')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':i'))
            print(yarp.NetworkBase.connect('/icub/' + self.parts[i] + '/state:o',
                                           '/' + self.module_name + '/' + self.parts[i] + ':i'))
            self.in_ports[self.parts[i]] = self.in_port

            self.out_port = yarp.Port()
            self.out_port.open('/' + self.module_name + '/' + self.parts[i] + ':o')
            print('{:s} opened'.format('/' + self.module_name + '/' + self.parts[i] + ':o'))
            connected = False
            if self.robot == 'r1':
                if self.parts[i] is not 'torso':
                    connected = yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o',
                                                         '/ctpservice/' + self.parts[i] + '/rpc')
                    print(connected)
                else:
                    connected = yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o',
                                                         '/cer/' + self.parts[i] + '/rpc:i')
                    print(connected)
            elif self.robot == 'icub':
                connected = yarp.NetworkBase.connect('/' + self.module_name + '/' + self.parts[i] + ':o',
                                                     '/ctpservice/' + self.parts[i] + '/rpc')
                print(connected)
            else:
                print('Robot {} unknown'.format(self.robot))

            if not connected:
                print('Error: missing connections')
            #                self.cleanup()
            #                sys.exit()

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
            if self.robot == 'r1':
                if part is not 'torso':
                    self.out_ports[part].write(commands[part])
                else:
                    self.out_ports[part].write(commands[part][0])
                    self.out_ports[part].write(commands[part][1])
            elif self.robot == 'icub':
                self.out_ports[part].write(commands[part])
            else:
                print('Robot {} unknown'.format(self.robot))

    def yarp_vector_to_se3(self):
        vector = self.camera_pose_port.read(False)

        if vector is not None:
            H = Quaternion(axis=[vector[3], vector[4], vector[5]], angle=vector[6]).transformation_matrix
            for i in range(3):
                H[i, 3] = vector[i]

            return True, H
        else:
            return False, []

    def blob_to_UVtarget(self, blob):
        '''
        This function computes the target as the center of the input bounding box
        '''
        blob_coord = blob.get(0).asList()
        print('Received blob (tlx,tly,brx,bry): ({},{},{},{})'.format(blob_coord.get(0).asInt(),
                                                                      blob_coord.get(1).asInt(),
                                                                      blob_coord.get(2).asInt(),
                                                                      blob_coord.get(3).asInt()))
        target_u = (blob_coord.get(0).asInt() + blob_coord.get(2).asInt()) / 2
        target_v = (blob_coord.get(1).asInt() + blob_coord.get(3).asInt()) / 2
        print('Correspondent pixel_target (u,v): ({}, {})'.format(target_u, target_v))

        return np.array([target_u, target_v])

    def UVtarget_to_xyztarget(self, pixel_target, pixel_contact, depth_img_array):
        '''
        This function convert an (u,v) pixel and depth information in (x,y,z) coordinates in the camera frame
        '''
        # Retrieve Depth from pixel
        d = depth_img_array[int(pixel_target[1]), int(pixel_target[0]), 0]
        print('depth: {}'.format(d))

        # Convert uv to xy
        target_x = ((pixel_target[0] - self.camera_cx) * d) / self.camera_fx
        target_y = ((pixel_target[1] - self.camera_cy) * d) / self.camera_fy
        print('Converted (x,y): ({},{})'.format(target_x, target_y))

        # Convert uv to xy
        contact_x = ((pixel_contact[0] - self.camera_cx)* d) / self.camera_fx
        contact_y = ((pixel_contact[1] - self.camera_cy)* d) / self.camera_fy
        print('Converted (x,y): ({},{})'.format(contact_x, contact_y))

        return np.array([target_x, target_y, d]), np.array([contact_x, contact_y, d])

    def xyztarget_to_targetH(self, target_xyz):
        target_H = np.array(
            [[1, 0, 0, target_xyz[0]], [0, 1, 0, target_xyz[1]], [0, 0, 1, target_xyz[2]], [0, 0, 0, 1]])
        print('target_H: {}'.format(target_H))
        return target_H

    def send_commands_to_karma(self, action, target_np, dimension, delta):
        # to_send = self._karma_commands_port.prepare()
        # to_send.clear()
        to_send = yarp.Bottle()
        reply = yarp.Bottle()

        # b = to_send.addList()
        # b.addString('train')
        to_send.addString(action)  # either push or vdraw
        to_print = '(' + action
        to_send.addDouble(target_np[0])
        to_print = to_print + ', ' + str(target_np[0])
        to_send.addDouble(target_np[1] + delta - dimension)
        to_print = to_print + ', ' + str(target_np[1] + delta - dimension)
        to_send.addDouble(target_np[2])
        to_print = to_print + ', ' + str(target_np[2])
        if self.arm == 'left':
            to_send.addDouble(180.0)
            to_print = to_print + ', ' + str(180.0)
        else:
            print('Actions with right arm not implemented')
        to_send.addDouble(delta)
        to_print = to_print + ', ' + str(delta)
        if action == 'vdraw':
            to_send.addDouble(0.01)
            to_print = to_print + ', ' + str(0.01)
        to_print = to_print + ')'
        print(to_print)

        self._karma_commands_port.write(to_send, reply)
        return reply

    def check_feasibility(self, target_np, dimension, delta):
        new_target_np = target_np

        # Check x coordinate and adjust it
        check_x = -0.60 <= target_np[0] <= -0.30
        if check_x and -0.60 <= target_np[0] <= -0.55:
            new_target_np[0] = -0.55
        elif check_x and -0.25 <= target_np[0] <= -0.30:
            new_target_np[0] = -0.30

        # Check y coordinate
        check_y = -0.20 <= target_np[1] - delta + dimension <= -0.10  # TO CHECK

        # Check z coordinate and adjust it
#        check_z = target_np[2] >= -0.08
#        if check_z and target_np[2] >= -0.04:
        new_target_np[2] = -0.06
        check_z = True

        # Prepare and send vdraw command to karma
        vdraw_ok = False
        reply = self.send_commands_to_karma('vdraw', new_target_np, dimension, delta)
        print('vdraw output: {}'.format(str(reply.get(1).asDouble())))
        if reply.get(1).asDouble() < 0.6:
            vdraw_ok = True

        is_feasible = check_x and check_y and check_z and vdraw_ok
        return is_feasible, new_target_np

    def respond(self, command, reply):
        if command.get(0).asString() == 'start':
            if command.get(1).asString() == 'exploration':
                print('Starting exploration')
                self.state = 'start_exploration'
                reply.addString('Exploration started')
            # elif command.get(1).asString() == 'interaction':
            #     print('Starting interaction')
            #     self.state = 'start_interaction'
            #     reply.addString('Interaction started')
        elif command.get(0).asString() == 'stick':
            if command.get(1).asString() == 'interaction':
                print('Starting interaction with stick')
                self.state = 'stick_interaction'
                reply.addString('Interaction with stick started')
        elif command.get(0).asString() == 'torso':
            if command.get(1).asString() == 'interaction':
                print('Exploration with torso started')
                self.state = 'torso_interaction'
                reply.addString('Exploration with torso started')
        elif command.get(0).asString() == 'send':
            if command.get(1).asString() == 'interaction':
                if not self.interaction_sent or not self.torso_sent:
                    print('Sending interaction command')
                    self.state = 'send_interaction'
                    reply.addString('Sending interaction command')
                else:
                    print('No interaction command to send')
                    self.state = 'do_nothing'
                    reply.addString('No interaction command to send')
        elif command.get(0).asString() == 'pause':
            if command.get(1).asString() == 'exploration':
                if self.state == 'exploration':
                    print('Pausing exploration')
                    self.state = 'pause_exploration'
                    reply.addString('Exploration paused')
                else:
                    print('Cannot pause exploration. Current state is {}'.format(self.state))
                    reply.addString('Cannot pause exploration. Current state is {}'.format(self.state))
            elif command.get(1).asString() == 'interaction':
                print('Pausing interaction')
                self.state = 'pause_interaction'
                reply.addString('Interaction paused')
        elif command.get(0).asString() == 'resume':
            if command.get(1).asString() == 'exploration':
                if self.state == 'pause_exploration':
                    print('Resuming exploration')
                    self.state = 'start_exploration'
                    reply.addString('Exploration resumed')
                else:
                    print('Cannot resume exploration. Current state is {}'.format(self.state))
                    reply.addString('Cannot resume exploration. Current state is {}'.format(self.state))
            elif command.get(1).asString() == 'interaction':
                print('Resuming interaction')
                self.state = 'start_interaction'
                reply.addString('Interaction resumed')
        elif command.get(0).asString() == 'stop':
            if self.state == 'exploration':
                print('Stopping exploration. Going home.')
                self.state = 'home_exploration'
                reply.addString('Exploration stopped')
            elif self.state == 'interaction':
                print('Stopping interaction. Going home.')
                self.state = 'home_interaction'
                reply.addString('Interaction stopped')
            else:  # I don't know if it makes sense anymore
                print('The robot is neither exploring nor interacting. Doing nothing.')
                reply.addString('The robot is not exploring nor interacting. Doing nothing.')
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
                    if self.robot == 'r1':
                        for i in range(0, len(self.parts_state[part])):
                            if not self.parts_state_previous[part][i] is None and abs(self.parts_state[part][i] - self.parts_state_previous[part][i]) > 0.1:
                               print('part: {:s}'.format(part))
                               print('current {:f} ; previous {:f}'.format(self.parts_state[part][i], self.parts_state_previous[part][i]))
                               is_same = False
                               break
                    if self.robot == 'icub':
                        # 3 because is the number of minimum parts for torso
                        for i in range(0, 3):
                            if not self.parts_state_previous[part][i] is None and abs(self.parts_state[part][i] - self.parts_state_previous[part][i]) > 0.4:
                               print('part: {:s}'.format(part))
                               print('current {:f} ; previous {:f}'.format(self.parts_state[part][i], self.parts_state_previous[part][i]))
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
                self.state = 'start_exploration'
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

        elif self.state == 'start_exploration':
            print('state start')
            print(self.current_step)
            step = self.steps[str(self.current_step)]
            commands = {}
            for part in step:
                print(part)
                if self.robot == 'r1':
                    if part is not 'torso':
                        target_p = step[part]['position']
                        target_t = step[part]['time']
                        commands[part] = self.move_all_to(target_p, target_t)
                    else:
                        target_p = step[part]['poss']
                        target_v = step[part]['vels']
                        commands[part] = self.move_torso_to(target_v, target_p)
                elif self.robot == 'icub':
                    target_p = step[part]['position']
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    print('Robot {} unknown'.format(self.robot))
            self.send_commands(commands)
            self.state = 'exploration'

        elif self.state == 'pause_exploration':
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
                if self.robot == 'r1':
                    if part is not 'torso':
                        target_p = self.parts_state[part]
                        target_t = step[part]['time']
                        commands[part] = self.move_all_to(target_p, target_t)
                    else:
                        target_p = self.parts_state[part]
                        target_v = step[part]['vels']
                        commands[part] = self.move_torso_to(target_v, target_p)
                elif self.robot == 'icub':
                    target_p = self.parts_state[part]
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    print('Robot {} unknown'.format(self.robot))
            self.send_commands(commands)
            self.send_commands(commands)
            self.state = 'do_nothing'

        elif self.state == 'home_exploration':
            print('state home')
            step = self.home
            commands = {}
            for part in step:
                print(part)
                if self.robot == 'r1':
                    if part is not 'torso':
                        target_p = step[part]['position']
                        target_t = step[part]['time']
                        commands[part] = self.move_all_to(target_p, target_t)
                    else:
                        target_p = step[part]['poss']
                        target_v = step[part]['vels']
                        commands[part] = self.move_torso_to(target_v, target_p)
                elif self.robot == 'icub':
                    target_p = step[part]['position']
                    target_t = step[part]['time']
                    commands[part] = self.move_all_to(target_p, target_t)
                else:
                    print('Robot {} unknown'.format(self.robot))
                    
            self.send_commands(commands)
            self.current_step = 0
            self.state = 'do_nothing'

        elif self.state == 'interaction':
            print('interaction state')
        elif self.state == 'torso_interaction':
            print('torso_interaction state')
            if not self.torso_sent:
                self.torso_sent = True
                print('An old interaction command has not been sent. Resetting.')
            self.state = 'interaction'

            # Read camera pose
            ok, new_cam_H = self.yarp_vector_to_se3()
            if ok:
                self.cam_H = new_cam_H

            # Read target and depth image from WS module
            fixation_point_bottle = self.target_in_port.read(True)  # fixation_point_bottle = (cx,cy)
            received_img = self.depth_in_port.read(True)
            self.depth_img.copy(received_img)
            assert self.depth_array.__array_interface__['data'][0] == self.depth_img.getRawImage().__int__()

#            cx = fixation_point_bottle.get(0).asList().get(0).asInt()
#            cy = fixation_point_bottle.get(0).asList().get(1).asInt()
            cx = int(self.image_w/2)
            cy = int(self.image_h/2)

            fixation_point_pixel = [cx, cy]
            print('Received fixation point (cx, cy): ({},{})'.format(cx, cy))

            # Find measures in meters of the target and of the contact point
            fixation_point_xyz, _ = self.UVtarget_to_xyztarget(fixation_point_pixel, fixation_point_pixel, self.depth_array)
            print('xyz fixation point: {}'.format(str(fixation_point_xyz)))
            fixation_point_H = self.xyztarget_to_targetH(fixation_point_xyz)

            root_to_target = self.cam_H.dot(fixation_point_H)
            fixation_point_np = [root_to_target[i, 3] for i in range(3)]  # target_np = (x,y,z) in robot coordinate system
            print('fixation_point_np: ({},{},{})'.format(str(fixation_point_np[0]), str(fixation_point_np[1]), str(fixation_point_np[2])))
            self.fixation_point_np_to_send = fixation_point_np
            self.state = 'do_nothing'
            self.torso_sent = False

        elif self.state == 'stick_interaction':
            print('stick_interaction state')
            if not self.interaction_sent:
                self.interaction_sent = True
                print('An old interaction command has not been sent. Resetting.')
            self.state = 'interaction'

            # Read camera pose
            ok, new_cam_H = self.yarp_vector_to_se3()
            if ok:
                self.cam_H = new_cam_H

            # Read target and depth image from WS module
            target_box = self.target_in_port.read(True)  # target_box = (tlx,tly,brx,bry)
            received_img = self.depth_in_port.read(True)
            self.depth_img.copy(received_img)
            assert self.depth_array.__array_interface__['data'][0] == self.depth_img.getRawImage().__int__()

            # Find measures in meters of the target and of the contact point
            pixel_target = self.blob_to_UVtarget(target_box)
            print('pixel target: {}'.format(str(pixel_target)))
            pixel_contact = np.array([target_box.get(0).asList().get(2).asInt(), pixel_target[1]])
            print('pixel contact: {}'.format(str(pixel_contact)))
            target_xyz, contact_xyz = self.UVtarget_to_xyztarget(pixel_target, pixel_contact, self.depth_array)
            print('xyz target: {}'.format(str(target_xyz)))
            print('xyz contact: ({},{},{})'.format(str(contact_xyz[0]), str(contact_xyz[1]), str(contact_xyz[2])))
            target_H = self.xyztarget_to_targetH(target_xyz)
            contact_H = self.xyztarget_to_targetH(contact_xyz)

            root_to_target = self.cam_H.dot(target_H)
            target_np = [root_to_target[i, 3] for i in range(3)]  # target_np = (x,y,z) in robot coordinate system
            print('target_np: ({},{},{})'.format(str(target_np[0]), str(target_np[1]), str(target_np[2])))

            root_to_contact = self.cam_H.dot(contact_H)
            contact_np = [root_to_contact[i, 3] for i in range(3)]  # contactt_np = (x,y,z) in robot coordinate system
            print('contact_np: ({},{},{})'.format(str(contact_np[0]), str(contact_np[1]), str(contact_np[2])))

            # Identify right values for karma
            self.dimension = math.sqrt(math.pow(target_np[0]-contact_np[0], 2) + math.pow(target_np[1]-contact_np[1], 2) + math.pow(target_np[2]-contact_np[2], 2))
            #delta = 0.08
            print('dimension: {}'.format(self.dimension))
            print('delta: {}'.format(self.delta))

            if self.arm == 'left':
                # Check feasibility
                is_feasible, self.target_np_to_send = self.check_feasibility(target_np, self.dimension, self.delta)
                print('is_feasible: {}'.format(is_feasible))
                print('new_target_np: ({},{},{})'.format(str(self.target_np_to_send[0]), str(self.target_np_to_send[1]), str(self.target_np_to_send[2])))

                # Prepare and send push command to karma
                if is_feasible:
                    print('Feasible action, waiting for send interaction command')
                    self.state = 'do_nothing'
                    self.interaction_sent = False
                else:
                    to_send = yarp.Bottle()
                    reply = yarp.Bottle()
                    to_send.clear()
                    to_send.addString('interaction')
                    to_send.addString('fail')
                    self._ws_commands_port.write(to_send, reply)
                    self.state = 'do_nothing'
            elif self.arm == 'right':
                print('Actions with right arm, not implemented')
                self.state = 'do_nothing'
            else:
                print('Unknown arm: {}'.format(self.arm))
                self.state = 'do_nothing'

        elif self.state == 'pause_interaction':
            print('pause_interaction state not implemented')
            # .... To see if it is ill posed
            #self.state = 'do_nothing'
        elif self.state == 'home_interaction':
            print('home_interaction state')
            to_send = yarp.Bottle()
            reply = yarp.Bottle()
            to_send.clear()

            to_send.addString('home')
            to_send.addString('arms')
            to_send.addString('head')

            self._are_commands_port.write(to_send, reply)
            self.state = 'do_nothing'
            print('home command sent')
        elif self.state == 'send_interaction':
            if not self.interaction_sent:
                self.send_commands_to_karma('push', self.target_np_to_send, self.dimension, self.delta)
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()
                to_send.addString('interaction')
                to_send.addString('success')
                self._ws_commands_port.write(to_send, reply)
                self.interaction_sent = True
                self.state = 'home_interaction'
                print('interaction command sent')
            elif not self.torso_sent:
                # Send look with fixation command to ARE
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()
                to_send.addString('look')
                t = to_send.addList()
                t.addDouble(self.fixation_point_np_to_send[0])
                t.addDouble(self.fixation_point_np_to_send[1])
                t.addDouble(self.fixation_point_np_to_send[2])
                to_send.addString('fixate')
                print('Command to send to ARE: look {} {} {} fixate'.format(float(self.fixation_point_np_to_send[0]),
                                                                            float(self.fixation_point_np_to_send[1]),
                                                                            float(self.fixation_point_np_to_send[2])))
                self._are_commands_port.write(to_send, reply)
                print('Command sent')

                # Send explore torso command to ARE
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()
                to_send.addString('explore')
                to_send.addString('torso')
                print('Command to send to ARE: explore torso')
                self._are_commands_port.write(to_send, reply)
                print('Command sent')

                # Send idle command to ARE
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()
                to_send.addString('idle')
                print('Command to send to ARE: idle')
                self._are_commands_port.write(to_send, reply)
                print('Command sent')

                # Restore variables
                self.torso_sent = True
                # Send home command to ARE
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()

                to_send.addString('home')
                to_send.addString('arms')
                to_send.addString('head')
                self._are_commands_port.write(to_send, reply)
                self.state = 'do_nothing'
                print('home command sent')

                # Send interaction success to WSmodule
                to_send = yarp.Bottle()
                reply = yarp.Bottle()
                to_send.clear()
                to_send.addString('interaction')
                to_send.addString('success')
                self._ws_commands_port.write(to_send, reply)

            else:
                self.state = 'do_nothing'
                print('no interaction command to send')
        elif self.state == 'do_nothing':
            pass
        else:
            print('state {:s} unknown'.format(self.state))
        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("ExplorationModule")
#    conffile = rf.find("from").asString()
    conffile = 'projects/public/online-detection-demo/app/config/interactive_exploration_conf_icub.ini'
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../app/config/exploration_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())
        rf.setDefaultConfigFile(conffile)

    rf.configure(sys.argv)

    # Run module
    em = ExplorationModule()
    em.runModule(rf)
