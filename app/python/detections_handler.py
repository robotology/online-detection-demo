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
    def __init__(self, input_image_port_name, out_det_img_port_name, input_detections_port_name, rpc_thresh_port_name, image_w, image_h):

         print 'Setting classes dictionary...\n'
         self._cls2colors = {};

         print 'Opening yarp ports...\n'

         self._input_image_port = yarp.BufferedPortImageRgb()
         self._input_image_port_name = input_image_port_name
         self._input_image_port.open(self._input_image_port_name)
         print '{:s} opened'.format(self._input_image_port_name)

         self._input_detections_port = yarp.BufferedPortBottle()
         self._input_detections_port_name = input_detections_port_name
         self._input_detections_port.open(self._input_detections_port_name)
         print '{:s} opened'.format(self._input_detections_port_name)

         self._out_det_img_port = yarp.Port()
         self._out_det_img_port_name = out_det_img_port_name
         self._out_det_img_port.open(self._out_det_img_port_name)
         print '{:s} opened'.format(self._out_det_img_port_name)

         self._rpc_thresh_port = yarp.RpcServer()
         self._rpc_thresh_port_name = rpc_thresh_port_name
         self._rpc_thresh_port.open(rpc_thresh_port_name)
         print '{:s} opened'.format(self._rpc_thresh_port_name)


         print 'Preparing input image...\n'
         self._in_buf_array = np.ones((image_h, image_w, 3), dtype = np.uint8)
         self._in_buf_image = yarp.ImageRgb()
         self._in_buf_image.resize(image_w, image_h)
         self._in_buf_image.setExternal(self._in_buf_array, self._in_buf_array.shape[1], self._in_buf_array.shape[0])

         print 'Preparing output image...\n'
         self._out_buf_image = yarp.ImageRgb()
         self._out_buf_image.resize(image_w, image_h)
         self._out_buf_array = np.zeros((image_h, image_w, 3), dtype = np.uint8)
         self._out_buf_image.setExternal(self._out_buf_array, self._out_buf_array.shape[1], self._out_buf_array.shape[0])

         self._old_all_dets = yarp.Bottle()
         self._old_all_dets.clear()
         self._counter_old = 0

    def _set_label(self, im, text, font, color, bbox):
    	 scale = 0.4
    	 thickness = 1
    	 size = cv2.getTextSize(text, font, scale, thickness)[0]
         print text
    	 print bbox
    	 label_origin = (int(bbox[0]), int(bbox[1]) - 15)
    	 label_bottom = (int(bbox[0])+size[0], int(bbox[1]) -10 + size[1])
    	 rect = (label_origin, label_bottom)

    	 cv2.rectangle(im, label_origin, label_bottom, color, -2)
         cv2.putText(im, text, (int(bbox[0]) + 1, int(bbox[1]) - 5), font, scale, (255,255,255))

    def _drawDetections(self, im, all_dets, thresh=0.15, vis=False):
            print 'drawDetections*********************************\n'
            if all_dets is not None:
            #if not all_dets.size() == 0:
                    print 'here'
                    self._old_all_dets = all_dets
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

				    # Print text for i-th detection
				    font = cv2.FONT_HERSHEY_SIMPLEX
				    text = '{:s} {:.3f}'.format(cls, score)
				    self._set_label(im, text, font, color, bbox)
                                    self._counter_old = 0

		        elif dets.get(0).isString() and dets.get(0).asString() == 'train':
			   for i in range(0,all_dets.size()):
				ann = all_dets.get(i).asList()
				bbox = [ann.get(1).asDouble(), ann.get(2).asDouble(), ann.get(3).asDouble(), ann.get(4).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
				cls = ann.get(5).asString()                                                                          # label 
			
				# Draw bounding box
				color = (0,0,255)
				cv2.rectangle(im,(int(round(bbox[0])), int(round(bbox[1]))),(int(round(bbox[2])), int(round(bbox[3]))),color, 2)

				# Print text
				font = cv2.FONT_HERSHEY_SIMPLEX
				text = 'Train: {:s}'.format(cls)
				self._set_label(im, text, font, color, bbox)
            elif self._old_all_dets is not None:
                    print 'HERE'
            	    all_dets = self._old_all_dets
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

				    # Print text for i-th detection
				    font = cv2.FONT_HERSHEY_SIMPLEX
				    text = '{:s} {:.3f}'.format(cls, score)
				    self._set_label(im, text, font, color, bbox)

		        elif dets.get(0).isString() and dets.get(0).asString() == 'train':
			   for i in range(0,all_dets.size()):
				ann = all_dets.get(i).asList()
				bbox = [ann.get(1).asDouble(), ann.get(2).asDouble(), ann.get(3).asDouble(), ann.get(4).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
				cls = ann.get(5).asString()                                                                          # label 
			
				# Draw bounding box
				color = (0,0,255)
				cv2.rectangle(im,(int(round(bbox[0])), int(round(bbox[1]))),(int(round(bbox[2])), int(round(bbox[3]))),color, 2)

				# Print text
				font = cv2.FONT_HERSHEY_SIMPLEX
				text = 'Train: {:s}'.format(cls)
				self._set_label(im, text, font, color, bbox)
                    self._counter_old = self._counter_old +1
                    if self._counter_old == 20:
                        self._old_all_dets.clear()
                        self._counter_old = 0

            # Return an RGB image with drawn detections
            im=cv2.cvtColor(im,cv2.COLOR_RGB2BGR)
            return im

    def _sendDetectedImage(self,im):
        # Send the result to the image output port
        self._out_buf_array[:,:] = im
        self._out_det_img_port.write(self._out_buf_image)

    def _set_threshold(self,cmd, reply):
        print 'setting threshold'
        if cmd.get(0).isDouble():
            new_thresh = cmd.get(0).asDouble()
            print 'changing threshold to ' + str(new_thresh)
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
        print 'reading cmd in updateModule\n'
        self._rpc_thresh_port.read(cmd, willReply=True)
        if cmd.size() is 1:
            raw_input('press any key to continue')
            print 'cmd size 1\n'
            self._set_threshold(cmd, reply)
            self._rpc_thresh_port.reply(reply)
        else:
            raw_input('press any key to continue')
            print 'cmd size != 1\n'
            ans = 'Received bottle has invalid size of ' + cmd.size()
            reply.addString(ans)
            self._rpc_thresh_port.reply(reply)

    def cleanup(self):
         print 'cleanup'
         self._input_image_port.close()
         self._input_detections_port.close()
         self._out_det_img_port.close()
         self._rpc_thresh_port.close()
         self._input_train_port.close()

    def run(self):

         while(True):

            # Read image from port
            print 'Waiting for image...\n'
            received_image = self._input_image_port.read()
            print 'Image received...\n'
            self._in_buf_image.copy(received_image)
            print 'Array assigned...\n'
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__long__()

            #Read detections from port
            print 'Waiting for detections...\n'
            detections = yarp.Bottle()
            detections.clear()

            detections = self._input_detections_port.read(False)

            frame = self._in_buf_array
            frame = cv2.cvtColor(frame,cv2.COLOR_RGB2BGR)
            
            t_draw = time.time()

            plotted_image = self._drawDetections(frame, detections)
            print 'Time required for drawing on image: %s' % (time.time() - t_draw)

            t_send = time.time()
            self._sendDetectedImage(plotted_image)
            print 'Time required for sending detected image: %s' % (time.time() - t_send)

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

    detHandler = DetectionsHandler(args.input_image_port_name, args.out_det_img_port_name, args.input_detections_port_name, args.rpc_thresh_port_name, args.image_width, args.image_height)

    #try:
    detHandler.run()

    #finally:
     #   print 'Closing DetectionsHandler'
      #  detHandler.cleanup()
