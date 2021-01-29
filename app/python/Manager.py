import yarp
import sys

yarp.Network.init()


class Manager(yarp.RFModule):
    def configure(self, rf):

        self.module_name = rf.find("module_name").asString()

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        self.detection_cmd_port = yarp.BufferedPortBottle()
        self.detection_cmd_port.open('/' + self.module_name + '/detection/command:o')
        print('{:s} opened'.format('/' + self.module_name + '/detection/command:o'))

        self.dataset_cmd_port = yarp.BufferedPortBottle()
        self.dataset_cmd_port.open('/' + self.module_name + '/dataset/command:o')
        print('{:s} opened'.format('/' + self.module_name + '/dataset/command:o'))

        self.HRI_cmd_port = yarp.BufferedPortBottle()
        self.HRI_cmd_port.open('/' + self.module_name + '/blobAnnotation/command:o')
        print('{:s} opened'.format('/' + self.module_name + '/blobAnnotation/command:o'))

        return True

    def respond(self, command, reply):
        if command.get(0).asString() == 'start':
            if command.get(1).isString() and command.get(1).asString() == 'refinement':
                command_bottle = self.detection_cmd_port.prepare()
                command_bottle.clear()
                command_bottle.addString('refine')
                command_bottle.addString('stream')
                self.detection_cmd_port.write()
                reply.addString('WS refinement started')
        elif command.get(0).asString() == 'stop':
            if command.get(1).isString() and command.get(1).asString() == 'refinement':
                command_bottle = self.detection_cmd_port.prepare()
                command_bottle.clear()
                command_bottle.addString('stop')
                command_bottle.addString('refinement')
                self.detection_cmd_port.write()
                reply.addString('WS refinement stopped')
        elif command.get(0).asString() == 'train':
            if command.get(1).isString():
                label = command.get(1).asString()
                command_bottle = self.detection_cmd_port.prepare()
                command_bottle.clear()
                command_bottle.addString('train')
                command_bottle.addString(label)
                self.detection_cmd_port.write()
                reply.addString('Supervised train started ')
        elif command.get(0).asString() == 'forget':
            if command.get(1).isString():
                label = command.get(1).asString()
                command_bottle = self.detection_cmd_port.prepare()
                command_bottle.clear()
                command_bottle.addString('forget')
                command_bottle.addString(label)
                self.detection_cmd_port.write()
                reply.addString('Supervised train started ')
        elif command.get(0).asString() == 'change':
            if command.get(1).isString() and command.get(1).asString() == 'dataset':
                if command.get(2).isString():
                    label = command.get(2).asString()
                    command_bottle = self.dataset_cmd_port.prepare()
                    command_bottle.clear()
                    command_bottle.addString('imageset')
                    command_bottle.addString(label)
                    self.dataset_cmd_port.write()
                    reply.addString('Dataset changed')
        elif command.get(0).asString() == 'select':
            out_command = 'selectDetection'
            command_bottle = self.HRI_cmd_port.prepare()
            command_bottle.clear()
            command_bottle.addString(out_command)
            self.HRI_cmd_port.write()
            reply.addString('selectDetection command sent')
        elif command.get(0).asString() == 'add':
            out_command = 'addDetection'
            command_bottle = self.HRI_cmd_port.prepare()
            command_bottle.clear()
            command_bottle.addString(out_command)
            self.HRI_cmd_port.write()
            reply.addString('addDetection command sent')
        elif command.get(0).asString() == 'doneSelection':
            if command.get(1).isString():
                out_command = 'doneSelection'
                label = command.get(1).asString()
                command_bottle = self.HRI_cmd_port.prepare()
                command_bottle.clear()
                command_bottle.addString(out_command)
                command_bottle.addString(label)
                self.HRI_cmd_port.write()
                reply.addString('doneSelection command sent')
        elif command.get(0).asString() == 'deleteSelection':
            out_command = 'deleteSelection'
            command_bottle = self.HRI_cmd_port.prepare()
            command_bottle.clear()
            command_bottle.addString(out_command)
            self.HRI_cmd_port.write()
            reply.addString('deleteSelection command sent')
        elif command.get(0).asString() == 'finishAnnotation':
            out_command = 'finishAnnotation'
            command_bottle = self.HRI_cmd_port.prepare()
            command_bottle.clear()
            command_bottle.addString(out_command)
            self.HRI_cmd_port.write()
            reply.addString('finishAnnotation command sent')
        elif command.get(0).asString() == 'quit':
            out_command = 'quit'
            HRI_command_bottle = self.HRI_cmd_port.prepare()
            HRI_command_bottle.clear()
            HRI_command_bottle.addString(out_command)
            self.HRI_cmd_port.write()

            detection_command_bottle = self.detection_cmd_port.prepare()
            detection_command_bottle.clear()
            detection_command_bottle.addString(out_command)
            self.detection_cmd_port.write()
            reply.addString('quit command sent')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))
        return True

    def cleanup(self):
        self.cmd_port.close()
        self.detection_cmd_port.close()
        self.dataset_cmd_port.close()
        self.HRI_cmd_port.close()
        print('Cleanup function')

    def interruptModule(self):
        print('Interrupt function')
        self.cmd_port.interrupt()
        self.detection_cmd_port.interrupt()
        self.dataset_cmd_port.interrupt()
        self.HRI_cmd_port.interrupt()
        return True

    def getPeriod(self):
        return 0.001

    def updateModule(self):
        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("Manager")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../config/manager_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    manager = Manager()
    # try:
    manager.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
