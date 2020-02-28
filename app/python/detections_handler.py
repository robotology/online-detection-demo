#!/usr/bin/env python

# --------------------------------------------------------
# Online-Object-Detection Demo
# Author: Elisa Maiettini
# --------------------------------------------------------

"""
Demo script showing detections in sample images.

See README.md for installation instructions before running.
"""

import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio
import os, sys, cv2
import argparse

import yarp
import scipy.ndimage
import matplotlib.pylab
import time
from random import randint

# Initialise YARP
yarp.Network.init()

class DetectionsHandler (yarp.RFModule):
    def __init__(self, input_image_port_name, out_det_img_port_name, input_detections_port_name, rpc_thresh_port_name, out_det_port_name, image_w, image_h):

         print('Setting classes dictionary...\n')
         self._cls2colors = {};

         print('Opening yarp ports...\n')

         self._input_image_port = yarp.BufferedPortImageRgb()
         self._input_image_port_name = input_image_port_name
         self._input_image_port.open(self._input_image_port_name)
         print('{:s} opened'.format(self._input_image_port_name))

         self._input_detections_port = yarp.BufferedPortBottle()
         self._input_detections_port_name = input_detections_port_name
         self._input_detections_port.open(self._input_detections_port_name)
         print('{:s} opened'.format(self._input_detections_port_name))

         self._out_det_img_port = yarp.Port()
         self._out_det_img_port_name = out_det_img_port_name
         self._out_det_img_port.open(self._out_det_img_port_name)
         print('{:s} opened'.format(self._out_det_img_port_name))

         self._rpc_thresh_port = yarp.RpcServer()
         self._rpc_thresh_port_name = rpc_thresh_port_name
         self._rpc_thresh_port.open(rpc_thresh_port_name)
         print('{:s} opened'.format(self._rpc_thresh_port_name))

         self._out_det_port = yarp.BufferedPortBottle()
         self._out_det_port_name = out_det_port_name
         self._out_det_port.open(self._out_det_port_name)
         print('{:s} opened'.format(self._out_det_port_name))

         print('Preparing input image...\n')
         self._in_buf_array = np.ones((image_h, image_w, 3), dtype = np.uint8)
         self._in_buf_image = yarp.ImageRgb()
         self._in_buf_image.resize(image_w, image_h)
         print('Before setExternal...\n')
         self._in_buf_image.setExternal(self._in_buf_array, self._in_buf_array.shape[1], self._in_buf_array.shape[0])

         print('Preparing output image...\n')
         self._out_buf_image = yarp.ImageRgb()
         self._out_buf_image.resize(image_w, image_h)
         self._out_buf_array = np.zeros((image_h, image_w, 3), dtype = np.uint8)
         self._out_buf_image.setExternal(self._out_buf_array, self._out_buf_array.shape[1], self._out_buf_array.shape[0])


         print('Setting buffer data...\n')        
         self._old_classes        = {}
         self._old_bboxes         = {}
         self._is_train           = False
         self._old_train_bottle   = yarp.Bottle()
         self._old_train_counter  = 0
         self._current_detections = yarp.Bottle()

    def _set_label(self, im, text, font, color, bbox):
        scale = 0.4
        thickness = 1
        size = cv2.getTextSize(text, font, scale, thickness)[0]
        print(text)
        print(bbox)
        label_origin = (int(bbox[0]), int(bbox[1]) - 15)
        label_bottom = (int(bbox[0])+size[0], int(bbox[1]) -10 + size[1])
        rect = (label_origin, label_bottom)

        cv2.rectangle(im, label_origin, label_bottom, color, -2)
        cv2.putText(im, text, (int(bbox[0]) + 1, int(bbox[1]) - 5), font, scale, (255,255,255))

    def _pruneOldDetections(self):
         # Remove all boxes that are older than T frames from the buffers of old detections  
         # and all train display older than T1 framse
         print('pruning old detections')
         for cls_old in list(self._old_classes.keys()):
             if self._old_classes[cls_old] >= 8: # T = 8
                 del self._old_classes[cls_old]
                 del self._old_bboxes[cls_old]
         if self._old_train_counter >= 3: # T1 = 3 
             self._old_train_bottle = yarp.Bottle()
             b = self._old_train_bottle.addList()
             self._old_train_counter = 0
            
           

    def _checkOldDetectionsAndUpdate(self, all_dets_received):
         # all_dets = all_dets_received
         if all_dets_received is not None and not all_dets_received.get(0).asList().get(0).isString(): 
             all_dets = all_dets_received
         # If received Bottle is not None and if it's not train command
             self._is_train = False
             print('here')
             # Add to old detections all the new received detections that are not present in the buffers
             for j in range(0,all_dets_received.size()):
                 dets_current = all_dets.get(j).asList()
                 cls_current  = dets_current.get(5).asString()    
                 if not cls_current in self._old_classes and not cls_current == '': 
                     self._old_classes[cls_current] = 0
                     self._old_bboxes[cls_current]  = [dets_current.get(0).asDouble(), dets_current.get(1).asDouble(), dets_current.get(2).asDouble(), dets_current.get(3).asDouble(),dets_current.get(4).asDouble()]
                     print('After adding:')
                     print(self._old_classes)
                     print(self._old_bboxes)

             # Add to all_dets all the old detections which are not present in all_dets_received 
             # Update buffer of old detections if you find a detection that was already present
             for cls_old in self._old_classes:
                 found = False 
                 for j in range(0,all_dets.size()):
                     dets_current = all_dets.get(j).asList()
                     cls_current  = dets_current.get(5).asString()
                     if cls_old == cls_current  and not cls_current == '': 
                         found = True
                         print('Found: cls_current: ' + cls_current + ' cls_old: ' + cls_old)
                         break 
                 if found:
                       self._old_classes[cls_old] = 0
                       self._old_bboxes[cls_old]  = [dets_current.get(0).asDouble(), dets_current.get(1).asDouble(), dets_current.get(2).asDouble(), dets_current.get(3).asDouble(), dets_current.get(4).asDouble()]
                 else:
                       self._old_classes[cls_old] = self._old_classes[cls_old] + 1
                       b = yarp.Bottle
                       b = all_dets.addList()
                       b.addDouble(self._old_bboxes[cls_old][0])
                       b.addDouble(self._old_bboxes[cls_old][1])
                       b.addDouble(self._old_bboxes[cls_old][2])
                       b.addDouble(self._old_bboxes[cls_old][3])
                       b.addDouble(self._old_bboxes[cls_old][4])
                       b.addString(cls_old)
             print('After updating:')
             print(self._old_classes)
             print(self._old_bboxes)
         # If received Bottle is not None and it's a train command
         elif all_dets_received is not None and all_dets_received.get(0).asList().get(0).isString() and all_dets_received.get(0).asList().get(0).asString() == 'train':
             all_dets = all_dets_received
             self._is_train = True
             self._old_train_bottle = all_dets
             self._old_train_counter = 0
         
         # If received Bottle is empty and model is training
         elif all_dets_received is None and self._is_train:
             all_dets = self._old_train_bottle
             self._old_train_counter = self._old_train_counter + 1
             
             
         # If received Bottle is empty but there are old detections in the buffer, populate all_dets with old detections from the buffer
         elif all_dets_received is None and bool(self._old_classes) and not self._is_train:
             print('HERE')
             all_dets = yarp.Bottle()
             for cls_old in self._old_classes:
                 self._old_classes[cls_old] = self._old_classes[cls_old] + 1
                 # b = yarp.Bottle()
                 b = all_dets.addList()
                 b.addDouble(self._old_bboxes[cls_old][0])
                 b.addDouble(self._old_bboxes[cls_old][1])
                 b.addDouble(self._old_bboxes[cls_old][2])
                 b.addDouble(self._old_bboxes[cls_old][3])
                 b.addDouble(self._old_bboxes[cls_old][4])
                 b.addString(cls_old)
                 print('After updating when received detection is empty:') 
                 print(self._old_classes)
                 print(self._old_bboxes)
         else:
             all_dets = yarp.Bottle()  
             b = all_dets.addList()
      
         return all_dets                   

    def _drawDetections(self, im, all_dets_received, thresh=0.15, vis=False):
            print('drawDetections*********************************')
            all_dets = self._checkOldDetectionsAndUpdate(all_dets_received)
            if all_dets is not None:
                    for i in range(0,all_dets.size()):
                        dets = all_dets.get(i).asList()
                        if dets.get(0).isDouble():
                                bbox = [dets.get(0).asDouble(), dets.get(1).asDouble(), dets.get(2).asDouble(), dets.get(3).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                                score = dets.get(4).asDouble()                                                                           # score of i-th detection
                                cls = dets.get(5).asString()                                                                             # label of i-th detection

                                if not cls in self._cls2colors:
                                    new_color = ( randint(0, 255),  randint(0, 255),  randint(0, 255))
                                    self._cls2colors[cls] = new_color

                                # Threshold detections by scores
                                if score >=thresh:
                                    # Draw bounding box for i-th detection
                                    color = self._cls2colors.get(cls)
                                    cv2.rectangle(im,(int(round(bbox[0])), int(round(bbox[1]))),(int(round(bbox[2])), int(round(bbox[3]))),color, 2)

                                    # print(text for i-th detection)
                                    font = cv2.FONT_HERSHEY_SIMPLEX
                                    text = '{:s} {:.3f}'.format(cls, score)
                                    self._set_label(im, text, font, color, bbox)


                        elif dets.get(0).isString() and dets.get(0).asString() == 'train':
                           for j in range(0,all_dets.size()):
                                ann = all_dets.get(j).asList()
                                bbox = [ann.get(1).asDouble(), ann.get(2).asDouble(), ann.get(3).asDouble(), ann.get(4).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                                cls = ann.get(5).asString()                                                                          # label 

                                # Draw bounding box
                                color = (0,0,255)
                                cv2.rectangle(im,(int(round(bbox[0])), int(round(bbox[1]))),(int(round(bbox[2])), int(round(bbox[3]))),color, 2)

                                # print(text
                                font = cv2.FONT_HERSHEY_SIMPLEX
                                text = 'Train: {:s}'.format(cls)
                                self._set_label(im, text, font, color, bbox)

                    self._current_detections = self._out_det_port.prepare()
                    self._current_detections.clear()
                    self._current_detections.copy(all_dets)
            else:
                    self._current_detections = self._out_det_port.prepare()
                    self._current_detections.clear()
                    b = self._current_detections.addList()
                    


            # Return an RGB image with drawn detections
            im=cv2.cvtColor(im,cv2.COLOR_RGB2BGR)
            return im

    def _sendDetectedImage(self,im):
        # Send the result to the image output port
        self._out_buf_array[:,:] = im
        self._out_det_img_port.write(self._out_buf_image)


    def _sendDetections(self):
        print('sending detections...')
        self._out_det_port.write()
     

    def _set_threshold(self,cmd, reply):
        print('setting threshold')
        if cmd.get(0).isDouble():
            new_thresh = cmd.get(0).asDouble()
            print('changing threshold to ' + str(new_thresh))
            self._threshold = cmd.get(0).asDouble()
            ans = 'threshold now is ' + str(new_thresh) + '. done!'
            reply.addString(ans)
            raw_input('press any key to continue')
        else:
            reply.addString('invalid threshold, it is not a double')
            raw_input('press any key to continue')

    def updateModule(self):
        cmd = yarp.Bottle()
        reply = yarp.Bottle()
        print('reading cmd in updateModule\n')
        self._rpc_thresh_port.read(cmd, willReply=True)
        if cmd.size() is 1:
            raw_input('press any key to continue')
            print('cmd size 1\n')
            self._set_threshold(cmd, reply)
            self._rpc_thresh_port.reply(reply)
        else:
            raw_input('press any key to continue')
            print('cmd size != 1\n')
            ans = 'Received bottle has invalid size of ' + cmd.size()
            reply.addString(ans)
            self._rpc_thresh_port.reply(reply)

    def cleanup(self):
         print('cleanup')
         self._input_image_port.close()
         self._input_detections_port.close()
         self._out_det_img_port.close()
         self._rpc_thresh_port.close()
         self._input_train_port.close()
         self._out_det_port.close()

    def run(self):

         while(True):

            # Read image from port
            print('\n\nWaiting for image...\n')
            received_image = self._input_image_port.read()
            print('Image received...\n')
            self._in_buf_image.copy(received_image)
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()

            #Read Detections or Annotations from port
            print('Waiting for detections or annotations...\n')
            detections = yarp.Bottle()
            detections.clear()

            detections = self._input_detections_port.read(False)

            frame = self._in_buf_array
            frame = cv2.cvtColor(frame,cv2.COLOR_RGB2BGR)
            
            t_draw = time.time()
            plotted_image = self._drawDetections(frame, detections)
            print('Time required for drawing on image: %s' % (time.time() - t_draw))

            # Update buffers of old detections        
            t_send = time.time()  
            self._pruneOldDetections()
            self._sendDetections()

            self._sendDetectedImage(plotted_image)
            print('Time required for sending detected image: %s' % (time.time() - t_send))

def parse_args():
    """Parse input arguments."""
    
    parser = argparse.ArgumentParser(description='online-Detection demo')

    # Port names
    parser.add_argument('--inputImagePort', dest='input_image_port_name', help='input image port',
                        default='/detHandler/image:i')
    parser.add_argument('--outputDetImgPort', dest='out_det_img_port_name', help='output port for detected images',
                        default='/detHandler/image:o')
    parser.add_argument('--inputDetectionsPort', dest='input_detections_port_name', help='input port for detections',
                        default='/detHandler/detections:i')
    parser.add_argument('--thresh_port', dest='rpc_thresh_port_name', help='rpc port name where to set detection threshold',
                        default='/detHandler:thresh')
    parser.add_argument('--output_detection_port', dest='out_det_port_name', help='output port for detections',
                        default='/detHandler:dets:o')

    # Image dimensions
    parser.add_argument('--image_w', type=int, dest='image_width', help='width of the images',
                        default=640)
    parser.add_argument('--image_h', type=int, dest='image_height', help='height of the images',
                        default=480)

    args = parser.parse_args()

    return args

if __name__ == '__main__':
    # Read input parametres
    args = parse_args()

    detHandler = DetectionsHandler(args.input_image_port_name, args.out_det_img_port_name, args.input_detections_port_name, args.rpc_thresh_port_name, args.out_det_port_name, args.image_width, args.image_height)

    try:
        detHandler.run()

    finally:
        print('Closing DetectionsHandler')
        detHandler.cleanup()


