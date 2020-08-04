import yarp
import sys
import numpy as np
from PIL import Image
import os
import xml.etree.ElementTree as ET
import numpy as np
import time
import random

# Initialise YARP
yarp.Network.init()

class iCWT_player(yarp.RFModule):
    def configure(self, rf):
        self.dataset_folder = '/home/elisa/Data/Datasets/iCubWorld-Transformations'
        self.images_folder = self.dataset_folder + '/Images'
        self.annotations_folder = self.dataset_folder + '/Annotations'
        self.imageset = self.dataset_folder + '/ImageSets/flower7.txt'

        self.image_w = 320
        self.image_h = 240

        self.fake = False
        self.sendScore = False

        self.module_name = ''

        self._input_image_port = yarp.BufferedPortImageRgb()
        self._input_image_port.open('/iCWTPlayer/image:i')
        print('{:s} opened'.format('/iCWTPlayer/image:i'))

        self._input_boxes_port = yarp.BufferedPortBottle()
        self._input_boxes_port.open('/iCWTPlayer/box:i')
        print('{:s} opened'.format('/iCWTPlayer/box:i'))

        self.output_image_port = yarp.Port()
        self.output_image_port.open('/iCWTPlayer/image:o')
        print('{:s} opened'.format('/iCWTPlayer/image:o'))

        self.output_box_port = yarp.BufferedPortBottle()
        self.output_box_port.open('/iCWTPlayer/box:o')
        print('{:s} opened'.format('/iCWTPlayer/box:o'))

        self.cmd_port = yarp.BufferedPortBottle()
        self.cmd_port.open('/iCWTPlayer/cmd:i')
        print('{:s} opened'.format('/iCWTPlayer/cmd:i'))

        print('Preparing input image...')
        self._in_buf_array = np.ones((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._in_buf_image = yarp.ImageRgb()
        self._in_buf_image.resize(self.image_w, self.image_h)
        self._in_buf_image.setExternal(self._in_buf_array, self._in_buf_array.shape[1], self._in_buf_array.shape[0])

        print('Preparing output image...')
        self.out_buf_image = yarp.ImageRgb()
        self.out_buf_image.resize(self.image_w, self.image_h)
        self.out_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self.out_buf_image.setExternal(self.out_buf_array, self.out_buf_array.shape[1], self.out_buf_array.shape[0])

        #with open(self.imageset, 'r') as f:
        #    self.lines = f.readlines()
        #    self.lines = sorted(self.lines)

        self.counter = 0
        self.state = 'stream_from_port'
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
        return 0.15

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
                        self.lines = sorted(self.lines)
                    self.counter = 0
            elif cmd.get(0).asString() == 'startfake':
                self.fake = True
            elif cmd.get(0).asString() == 'pause':
                self.state = 'do_nothing'
            elif cmd.get(0).asString() == 'resume':
                self.state = 'stream'
            elif cmd.get(0).asString() == 'stopfake':
                self.fake = False
            elif cmd.get(0).asString() == 'startScore':
                self.sendScore = True
            elif cmd.get(0).asString() == 'stopScore':
                self.sendScore = False
            elif cmd.get(0).asString() == 'fromPort':
                self.state = 'stream_from_port'

        if self.state == 'stream':
            item = self.lines[self.counter]
            item = item.rstrip()
            print(item)

            if os.path.exists(os.path.join(self.images_folder, item + '.jpg')):
                image = np.array(Image.open(os.path.join(self.images_folder, item + '.jpg')))
            elif os.path.exists(os.path.join(self.images_folder, item + '.ppm')):
                image = np.array(Image.open(os.path.join(self.images_folder, item + '.ppm')))
            elif os.path.exists(os.path.join(self.images_folder, item + '.png')):
                image = np.array(Image.open(os.path.join(self.images_folder, item + '.png')))

            self.out_buf_array[:, :] = image

            if os.path.exists(os.path.join(self.annotations_folder, item + '.xml')):
                annotations = ET.parse(os.path.join(self.annotations_folder, item + '.xml')).getroot()

                annotations_bottle = self.output_box_port.prepare()
                annotations_bottle.clear()
                # ann = annotations_bottle.addList()
                for object in annotations.findall('object'):
                    b = annotations_bottle.addList()
                    bbox = object.find('bndbox')
                    b.addInt(int(bbox.find('xmin').text))
                    b.addInt(int(bbox.find('ymin').text))
                    b.addInt(int(bbox.find('xmax').text))
                    b.addInt(int(bbox.find('ymax').text))
                    if self.sendScore:
                        b.addDouble(random.randrange(0, 10)/10)
                    b.addString(object.find('name').text)

                if self.fake:
                    c = annotations_bottle.addList()
                    c.addInt(100)
                    c.addInt(100)
                    c.addInt(250)
                    c.addInt(250)
                    c.addString('fake')

                self.output_box_port.write()
            self.output_image_port.write(self.out_buf_image)

            if self.counter >= len(self.lines)-1:
                self.counter = 0
            else:
                self.counter = self.counter + 1

        elif self.state == 'stream_from_port':
            boxes = yarp.Bottle()
            boxes.clear()

            received_image = self._input_image_port.read()
            boxes = self._input_boxes_port.read()

            self._in_buf_image.copy(received_image)
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()
            self.out_buf_array = self._in_buf_image
            self.output_image_port.write(self.out_buf_image)

            annotations_bottle = self.output_box_port.prepare()
            annotations_bottle.clear()
            annotations_bottle.copy(boxes)
            self.output_box_port.write()
        else:
            pass
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
