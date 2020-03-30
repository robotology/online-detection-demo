import yarp
import sys

# Initialise YARP
yarp.Network.init()


class WeakSupervisionModule(yarp.RFModule):
    def configure(self, rf):

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/WSModule/command:i')
        print('{:s} opened'.format('/WSModule/command:i'))

        self.attach(self.cmd_port)

        return True

    def cleanup(self):
        self.cmd_port.close()
        print('Cleanup function')

    def respond(self, command, reply):
        if command.get(0).asString() == 'refine':
            print('Command refine received')
            reply.addString('ack')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('nack')
        return True

    def interruptModule(self):
        print('Interrupt function')
        self.cmd_port.interrupt()
        return True

    def getPeriod(self):
        return 0.001

    def updateModule(self):



        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("WeakSupervisionModule")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('ws_module_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    ws_module = WeakSupervisionModule()
    # try:
    ws_module.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
