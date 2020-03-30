import yarp
import sys
import numpy as np
from PIL import Image
import os
import xml.etree.ElementTree as ET
import numpy as np
import time

# Initialise YARP
yarp.Network.init()

class iCWT_player(yarp.RFModule):
    def configure(self, rf):
        self.dataset_folder = '/home/elisa/Data/Datasets/iCubWorld-Transformations'
        self.images_folder = self.dataset_folder + '/Images'
        self.annotations_folder = self.dataset_folder + '/Annotations'
        self.imageset = self.dataset_folder + '/ImageSets/sprayers.txt'

        self.image_w = 640
        self.image_h = 480

        self.fake = False

        self.output_image_port = yarp.Port()
        self.output_image_port.open('/iCWTPlayer/image:o')
        print('{:s} opened'.format('/iCWTPlayer/image:o'))

        self.output_box_port = yarp.BufferedPortBottle()
        self.output_box_port.open('/iCWTPlayer/box:o')
        print('{:s} opened'.format('/iCWTPlayer/box:o'))

        self.cmd_port = yarp.BufferedPortBottle()
        self.cmd_port.open('/iCWTPlayer/cmd:i')
        print('{:s} opened'.format('/iCWTPlayer/cmd:i'))

        print('Preparing output image...')
        self.out_buf_image = yarp.ImageRgb()
        self.out_buf_image.resize(self.image_w, self.image_h)
        self.out_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self.out_buf_image.setExternal(self.out_buf_array, self.out_buf_array.shape[1], self.out_buf_array.shape[0])

        with open(self.imageset, 'r') as f:
            self.lines = f.readlines()

        self.counter = 0
        return True

    def cleanup(self):
        print('Cleanup function')
        self.output_image_port.close()
        self.output_box_port.close()
        self.cmd_port.close()

    def interruptModule(self):
        print('Interrupt function')
        self.output_image_port.interrupt()
        self.output_box_port.interrupt()
        self.cmd_port.interrupt()
        return True

    def getPeriod(self):
        return 0.1

    def updateModule(self):

        cmd = yarp.Bottle()
        cmd = self.cmd_port.read(False)

        if cmd is not None:
            print('not null')
            if cmd.get(0).asString() == 'imageset':
                self.imageset = self.dataset_folder + '/ImageSets/' + cmd.get(1).asString() + '.txt'
                if os.path.exists(self.imageset):
                    with open(self.imageset, 'r') as f:
                        self.lines = f.readlines()

                    self.counter = 0
            elif cmd.get(0).asString() == 'startfake':
                self.fake = True
            elif cmd.get(0).asString() == 'stopfake':
                self.fake = False


        item = self.lines[self.counter]
        item = item.rstrip()
        print(item)

        image = np.array(Image.open(os.path.join(self.images_folder, item + '.jpg')))
        self.out_buf_array[:, :] = image

        annotations = ET.parse(os.path.join(self.annotations_folder, item + '.xml')).getroot()

        annotations_bottle = self.output_box_port.prepare()
        annotations_bottle.clear()
        for object in annotations.findall('object'):
            b = annotations_bottle.addList()
            bbox = object.find('bndbox')
            b.addInt(int(bbox.find('xmin').text))
            b.addInt(int(bbox.find('ymin').text))
            b.addInt(int(bbox.find('xmax').text))
            b.addInt(int(bbox.find('ymax').text))
            b.addString(object.find('name').text)

        if self.fake:
            c = annotations_bottle.addList()
            c.addInt(100)
            c.addInt(100)
            c.addInt(250)
            c.addInt(250)
            c.addString('fake')

        self.output_image_port.write(self.out_buf_image)
        self.output_box_port.write()

        if self.counter >= len(self.lines)-1:
            self.counter = 0
        else:
            self.counter = self.counter + 1

        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("assignment_DL-segmentation")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('DLcls_forTest2.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    player = iCWT_player()
    # try:
    player.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
