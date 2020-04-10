import sys
import yarp
import numpy as np
import cv2
from random import randint

# Initialise YARP
yarp.Network.init()


class BoxesVisualizer(yarp.RFModule):
    def configure(self, rf):
        self.image_w = rf.find("image_w").asInt()
        self.image_h = rf.find("image_h").asInt()
        self.module_name = rf.find("module_name").asString()
        if self.module_name == '':
            self.module_name = 'BoxesVisualizer'

        self._input_image_port = yarp.BufferedPortImageRgb()
        self._input_image_port.open('/' + self.module_name + '/visualization/image:i')
        print('{:s} opened'.format('/' + self.module_name + '/visualization/image:i'))

        self._input_boxes_port = yarp.BufferedPortBottle()
        self._input_boxes_port.open('/' + self.module_name + '/visualization/boxes:i')
        print('{:s} opened'.format('/' + self.module_name + '/visualization/boxes:i'))

        self._output_image_port = yarp.Port()
        self._output_image_port.open('/' + self.module_name + '/visualization/image:o')
        print('{:s} opened'.format('/' + self.module_name + '/visualization/image:o'))

        print('Preparing input image...')
        self._in_buf_array = np.ones((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._in_buf_image = yarp.ImageRgb()
        self._in_buf_image.resize(self.image_w, self.image_h)
        self._in_buf_image.setExternal(self._in_buf_array, self._in_buf_array.shape[1], self._in_buf_array.shape[0])

        print('Preparing output image...')
        self._out_buf_image = yarp.ImageRgb()
        self._out_buf_image.resize(self.image_w, self.image_h)
        self._out_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._out_buf_image.setExternal(self._out_buf_array, self._out_buf_array.shape[1], self._out_buf_array.shape[0])

        self._cls2colors = {};

        return True

    def cleanup(self):
        self._input_image_port.close()
        self._input_boxes_port.close()
        self._output_image_port.close()
        print('Cleanup function')

    def interruptModule(self):
        print('Interrupt function')
        self._input_image_port.interrupt()
        self._input_boxes_port.interrupt()
        self._output_image_port.interrupt()
        return True

    def set_label(self, im, text, font, color, bbox):
        scale = 0.4
        thickness = 1
        size = cv2.getTextSize(text, font, scale, thickness)[0]
        print(text)
        print(bbox)
        label_origin = (int(bbox[0]), int(bbox[1]) - 15)
        label_bottom = (int(bbox[0])+size[0], int(bbox[1]) -10 + size[1])
        rect = (label_origin, label_bottom)

        cv2.rectangle(im, label_origin, label_bottom, color, -2)
        cv2.putText(im, text, (int(bbox[0]) + 1, int(bbox[1]) - 5), font, scale, (255, 255, 255))

    def drawBoxes(self, im, all_dets):
        print('draw boxes*********************************')
        if all_dets is not None:
            for i in range(0, all_dets.size()):
                if all_dets.get(i).isList():
                    dets = all_dets.get(i).asList()
                else:
                    dets = all_dets
                if dets.get(0).isDouble() or dets.get(0).isInt():
                    bbox = [dets.get(0).asDouble(), dets.get(1).asDouble(), dets.get(2).asDouble(),
                            dets.get(3).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                    if dets.get(4).isDouble():
                        score = dets.get(4).asDouble()
                        cls = dets.get(5).asString()
                    elif dets.get(4).isString():
                        score = -2
                        cls = dets.get(4).asString()

                    if cls not in self._cls2colors:
                        new_color = (randint(0, 255), randint(0, 255), randint(0, 255))
                        self._cls2colors[cls] = new_color

                    # Threshold detections by scores
                    # if score >= thresh:
                    # Draw bounding box for i-th box
                    color = self._cls2colors.get(cls)
                    cv2.rectangle(im, (int(round(bbox[0])), int(round(bbox[1]))),
                                  (int(round(bbox[2])), int(round(bbox[3]))), color, 2)

                    # print(text for i-th box)
                    font = cv2.FONT_HERSHEY_SIMPLEX
                    if score == -2:
                        text = '{:s}'.format(cls)
                    else:
                        text = '{:s} {:.3f}'.format(cls, score)
                    self.set_label(im, text, font, color, bbox)

                elif dets.get(0).isString() and dets.get(0).asString() == 'train':
                    for j in range(0, all_dets.size()):
                        ann = all_dets.get(j).asList()
                        bbox = [ann.get(1).asDouble(), ann.get(2).asDouble(), ann.get(3).asDouble(),
                                ann.get(4).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                        cls = ann.get(5).asString()  # label

                        # Draw bounding box
                        color = (0, 0, 255)
                        cv2.rectangle(im, (int(round(bbox[0])), int(round(bbox[1]))),
                                      (int(round(bbox[2])), int(round(bbox[3]))), color, 2)

                        # print(text
                        font = cv2.FONT_HERSHEY_SIMPLEX
                        text = 'Train: {:s}'.format(cls)
                        self.set_label(im, text, font, color, bbox)

        # Return an RGB image with drawn detections
        im = cv2.cvtColor(im, cv2.COLOR_RGB2BGR)
        return im

    def sendDetectedImage(self, im):
        # Send the result to the image output port
        self._out_buf_array[:, :] = im
        self._output_image_port.write(self._out_buf_image)

    def getPeriod(self):
        return 0.001

    def updateModule(self):
        boxes = yarp.Bottle()
        boxes.clear()

        received_image = self._input_image_port.read()
        boxes = self._input_boxes_port.read(False)
        print('Image received')

        if boxes is not None and boxes.get(0).isString() and boxes.get(0).asString() == 'skip':
            pass
        else:
            self._in_buf_image.copy(received_image)
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()

            frame = self._in_buf_array
            frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

            plotted_image = self.drawBoxes(frame, boxes)
            self.sendDetectedImage(plotted_image)

        return True


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("WeakSupervisionModule")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../config/ws_module_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    bv = BoxesVisualizer()
    # try:
    bv.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
