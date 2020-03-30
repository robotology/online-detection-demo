import yarp
import sys

# Initialise YARP
yarp.Network.init()

class WeakSupervisionModule(yarp.RFModule):
    def configure(self, rf):

        return True

    def cleanup(self):
        print('Cleanup function')


    def interruptModule(self):
        print('Interrupt function')

        return True

    def getPeriod(self):
        return 0.1

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
