import cv2
import argparse
import glob
import numpy as np
import os
import time
import sys
import yarp


basedir = os.path.dirname(__file__)
sys.path.append(os.path.abspath(os.path.join(basedir, os.path.pardir, 'external', 're3-tensorflow')))
from tracker import re3_tracker

from re3_utils.util import drawing
from re3_utils.util import bb_util
from re3_utils.util import im_util

from constants import OUTPUT_WIDTH
from constants import OUTPUT_HEIGHT
from constants import PADDING

np.set_printoptions(precision=6)
np.set_printoptions(suppress=True)

drawnBox = np.zeros(4)
boxToDraw = np.zeros(4)
mousedown = False
mouseupdown = False
initialize = False

# Initialise YARP
yarp.Network.init()


class AnnotationsPropagator(yarp.RFModule):
    def configure(self, rf):

        # self.image_w = rf.find("image_w").asInt()
        # self.image_h = rf.find("image_h").asInt()
        self.image_w = 320
        self.image_h = 240
        # self.max_time = rf.find("max_propagation").asInt()
        self.max_time = 2000
        self.module_name = 'AnnotationsPropagator'

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        self._input_image_port = yarp.BufferedPortImageRgb()
        self._input_image_port.open('/' + self.module_name + '/image:i')
        print('{:s} opened'.format('/' + self.module_name + '/image:i'))

        self._input_predictions_port = yarp.BufferedPortBottle()
        self._input_predictions_port.open('/' + self.module_name + '/predictions:i')
        print('{:s} opened'.format('/' + self.module_name + '/predictions:i'))

        self._output_image_port = yarp.Port()
        self._output_image_port.open('/' + self.module_name + '/image:o')
        print('{:s} opened'.format('/' + self.module_name + '/image:o'))

        self._output_annotations_port = yarp.BufferedPortBottle()
        self._output_annotations_port.open('/' + self.module_name + '/annotations:o')
        print('{:s} opened'.format('/' + self.module_name + '/annotations:o'))

        self._ask_image_port = yarp.Port()
        self._ask_image_port.open('/' + self.module_name + '/ask/image:o')
        print('{:s} opened'.format('/' + self.module_name + '/ask/image:o'))

        self._ask_annotations_port = yarp.BufferedPortBottle()
        self._ask_annotations_port.open('/' + self.module_name + '/ask/annotations:o')
        print('{:s} opened'.format('/' + self.module_name + '/ask/annotations:o'))

        self._reply_image_port = yarp.BufferedPortImageRgb()
        self._reply_image_port.open('/' + self.module_name + '/reply/image:i')
        print('{:s} opened'.format('/' + self.module_name + '/reply/image:i'))

        self._reply_annotations_port = yarp.BufferedPortBottle()
        self._reply_annotations_port.open('/' + self.module_name + '/reply/annotations:i')
        print('{:s} opened'.format('/' + self.module_name + '/reply/annotations:i'))

        self.cmd_exploration_port = yarp.BufferedPortBottle()
        self.cmd_exploration_port.open('/' + self.module_name + '/exploration/command:o')
        print('{:s} opened'.format('/' + self.module_name + '/exploration/command:o'))
        #print(yarp.NetworkBase.connect('/' + self.module_name + '/exploration/command:o', '/exploration/command:i'))

        print('Preparing input image...')
        self._in_buf_array = np.ones((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._in_buf_image = yarp.ImageRgb()
        self._in_buf_image.resize(self.image_w, self.image_h)
        self._in_buf_image.setExternal(self._in_buf_array, self._in_buf_array.shape[1], self._in_buf_array.shape[0])

        print('Preparing output image...\n')
        self._out_buf_image = yarp.ImageRgb()
        self._out_buf_image.resize(self.image_w, self.image_h)
        self._out_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._out_buf_image.setExternal(self._out_buf_array, self._out_buf_array.shape[1], self._out_buf_array.shape[0])

        print('Preparing image to ask annotation...')
        self._ask_buf_image = yarp.ImageRgb()
        self._ask_buf_image.resize(self.image_w, self.image_h)
        self._ask_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._ask_buf_image.setExternal(self._ask_buf_array, self._ask_buf_array.shape[1], self._ask_buf_array.shape[0])

        print('Preparing annotated image...')
        self._reply_buf_array = np.ones((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._reply_buf_image = yarp.ImageRgb()
        self._reply_buf_image.resize(self.image_w, self.image_h)
        self._reply_buf_image.setExternal(self._reply_buf_array, self._reply_buf_array.shape[1], self._reply_buf_array.shape[0])

        self.state = 'propagate'
        self.time = time.time()
        self.interrupt = False
        self.isExploring = True

        self.predictions = yarp.Bottle()
        self.annotations = None

        self.tracker = re3_tracker.Re3Tracker()
        self.obj_names = []

        return True

    def respond(self, command, reply):
        if command.get(0).asString() == 'propagate':
            print('Command propagate received')
            reply.addString('Propagate state activated')
        elif command.get(0).asString() == 'interrupt':
            self.interrupt = True
            reply.addString('Propagation interrupted')
        elif command.get(0).asString() == 'max_time':
            if command.get(1).isInt():
                self.max_time = int(command.get(1).asInt())
                reply.addString('max_time value is now {:s}'.format(str(self.max_time)))
            else:
                reply.addString('nack')
        elif command.get(0).asString() == 'stop':
            self.state = 'do_nothing'
            # self.terminate_process()
            reply.addString('refine state deactivated')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))

        return True

    def ask_for_annotations(self):
        print('Asking for annotations')
        # Send image and doubtful predictions to the annotator

        self._ask_buf_array[:, :] = self._in_buf_array

        to_send = self._ask_annotations_port.prepare()
        to_send.clear()

        to_send.copy(self.predictions)

        self._ask_image_port.write(self._ask_buf_image)
        self._ask_annotations_port.write()

        # Wait for the annotator's reply
        print('Waiting for annotator reply')
        annotations = yarp.Bottle()
        annotations.clear()
        annotations = self._reply_annotations_port.read()
        received_image = self._reply_image_port.read()

        print('Image and annotations received')
        self._reply_buf_image.copy(received_image)
        assert self._reply_buf_array.__array_interface__['data'][0] == self._reply_buf_image.getRawImage().__int__()
        self._out_buf_array[:, :] = self._reply_buf_array

        self.annotations = annotations.get(0).asList()

    def compute_overlap(self, A,B):
        '''
        calculate two box's iou
        '''
        width = min(A[2],B[2])-max(A[0],B[0]) + 1
        height = min(A[3],B[3])-max(A[1],B[1]) + 1
        if width<=0 or height<=0:
            return 0
        Aarea =(A[2]-A[0])*(A[3]-A[1]+1) 
        Barea =(B[2]-B[0])*(B[3]-B[1]+1)
        iner_area = width* height
        return iner_area/(Aarea+Barea-iner_area)


    def check_annotations_quality(self):
        is_annotation_ok = True

        if not self.annotations is None and not self.annotations.size() == 0:
            boxes = {}
            for i in range(0, self.annotations.size()):
                ann = self.annotations.get(i).asList()
                obj_name = ann.get(4).asString()
                # self.obj_names.append(obj_name)
                boxes[obj_name] = [ann.get(0).asDouble(), ann.get(1).asDouble(),
                                   ann.get(2).asDouble(), ann.get(3).asDouble()]
        
        overlap_thresh = 0.7           
        for name1, box1 in boxes.items():
            for name2, box2 in boxes.items():
                if not name1 == name2:
                    o = self.compute_overlap(box1, box2)
                    print('overlap: {}'.format(o))
                    if o > overlap_thresh:
                        is_annotation_ok = False
                        break

        return is_annotation_ok


    def send_annotations(self):
        print('Sending annotations')
        to_send = self._output_annotations_port.prepare()
        to_send.clear()
        to_send.copy(self.annotations)
        self._output_annotations_port.write()
        self._output_image_port.write(self._out_buf_image)


    def cleanup(self):
        print('Cleanup function')
        self.cmd_port.close()
        self._input_image_port.close()
        self._input_predictions_port.close()
        self._ask_image_port.close()
        self._ask_annotations_port.close()
        self._reply_image_port.close()
        self._reply_annotations_port.close()
        self._output_image_port.close()
        self._output_annotations_port.close()

    def interruptModule(self):
        print('Interrupt function')
        self.cmd_port.interrupt()
        self._input_image_port.interrupt()
        self._input_predictions_port.interrupt()
        self._ask_image_port.interrupt()
        self._ask_annotations_port.interrupt()
        self._reply_image_port.interrupt()
        self._reply_annotations_port.interrupt()
        self._output_image_port.close()
        self._output_annotations_port.close()

        return True

    def getPeriod(self):
        return 0.001

    def initialize_tracker(self):
        print('Initialize tracker')
        if self.annotations is not None:
            self.obj_names = []
            image = self._in_buf_array
            # annotations_list = self.annotations.get(0).asList()
            if self.annotations.size() == 1:
                print('annotations list is of size 1')
                ann = self.annotations.get(0).asList()
                obj_name = ann.get(4).asString()
                self.obj_names.append(obj_name)
                initial_bbox = [ann.get(0).asDouble(), ann.get(1).asDouble(),
                                ann.get(2).asDouble(), ann.get(3).asDouble()]
                self.tracker.track(obj_name, image, initial_bbox)

            elif self.annotations.size() > 1:
                print('annotations list is of size greater than 1')
                initial_boxes = {}
                for i in range(0, self.annotations.size()):
                    ann = self.annotations.get(i).asList()
                    obj_name = ann.get(4).asString()
                    self.obj_names.append(obj_name)
                    initial_boxes[obj_name] = [ann.get(0).asDouble(), ann.get(1).asDouble(),
                                               ann.get(2).asDouble(), ann.get(3).asDouble()]

                self.tracker.multi_track(self.obj_names, image, initial_boxes)

            else:
                print('annotations_list is empty')
                self.annotations.addList()

    def propagate_annotations(self):
        print('Propagate annotations')
        image = self._in_buf_array
        self._out_buf_array[:, :] = self._in_buf_array

        if self.annotations is not None:
            # annotations_list = self.annotations.get(0).asList()
            if self.annotations.size() == 1:
                print('annotations list is of size 1')
                boxes = self.tracker.track(self.obj_names[0], image)

                self.annotations = yarp.Bottle()
                # ann = self.annotations.addList()
                b = self.annotations.addList()
                #b.addString('train')
                b.addInt(int(boxes[0]))
                b.addInt(int(boxes[1]))
                b.addInt(int(boxes[2]))
                b.addInt(int(boxes[3]))
                b.addString(self.obj_names[0])

            elif self.annotations.size() > 1:
                print('annotations list is of size greater than 1')
                boxes = self.tracker.multi_track(self.obj_names, image)

                self.annotations = yarp.Bottle()
                # ann = self.annotations.addList()
                for i, obj_name in enumerate(self.obj_names):
                    b = self.annotations.addList()
                    #b.addString('train')
                    b.addInt(int(boxes[i, 0]))
                    b.addInt(int(boxes[i, 1]))
                    b.addInt(int(boxes[i, 2]))
                    b.addInt(int(boxes[i, 3]))
                    b.addString(obj_name)
            else:
                print('annotations_list is empty')
                self.annotations.addList()

    def sendExplorationCommand(self, action):
                to_send = self.cmd_exploration_port.prepare()
                to_send.clear()
                to_send.addString('explore')
                to_send.addString(action)
                self.cmd_exploration_port.write()

    def do_HRI(self, detections):
        self.sendExplorationCommand('pause')
        self.predictions = detections
        self.ask_for_annotations()
        self.initialize_tracker()
        self.time = time.time()
        if self.interrupt:
            self.interrupt = False
        self.send_annotations()
        self.sendExplorationCommand('resume')        

    def updateModule(self):
        if self.state == 'do_nothing':
            pass
        elif self.state == 'propagate':
            print('propagate')

            received_image = self._input_image_port.read()
            print('Image received...')
            self._in_buf_image.copy(received_image)
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()

            print('Waiting for detections or annotations...')
            detections = yarp.Bottle()
            detections.clear()
            detections = self._input_predictions_port.read()

            if detections.get(0).isString() and detections.get(0).asString() == "skip":
                self.propagate_annotations()
            elif time.time() - self.time > self.max_time or self.annotations is None or self.interrupt:
                self.do_HRI(detections)

            else:
                self.propagate_annotations()
                if not self.check_annotations_quality():
                    print('*****************************BAD PREDICTIONS*************************************************')
                    self.do_HRI(detections)    
                else:                
                    self.send_annotations()

        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("AnnotationsPropagatorModule")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../app/config/annotations_propagator_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    ap = AnnotationsPropagator()
    # try:
    ap.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
