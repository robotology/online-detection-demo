from src import WeakSupervisionTemplate as wsT
import sys
import yarp
import numpy as np

# Initialise YARP
yarp.Network.init()


class StreamUncertaintyBasedMethod(wsT.WeakSupervisionTemplate):
    def configure(self, rf):
        super(StreamUncertaintyBasedMethod, self).configure(rf)
        self.predictions = []
        self.annotations = []

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

        return True

    def ask_for_annotations(self):
        # Send image and doubtful predictions to the annotator
        self._ask_buf_array[:, :] = self._in_buf_array

        to_send = self._output_annotations_port.prepare()
        to_send.clear()

        if self.predictions is not None:
            for p in self.predictions:
                b = to_send.addList()
                b.addDouble(p['bbox'][0])
                b.addDouble(p['bbox'][1])
                b.addDouble(p['bbox'][2])
                b.addDouble(p['bbox'][3])
                b.addDouble(p['confidence'])
                b.addString(p['class'])

        self._ask_image_port.write(self._out_buf_image)
        self._ask_annotations_port.write()

        # Wait for the annotator's reply
        received_image = self._reply_image_port.read()
        print('Image received...')
        self._reply_buf_image.copy(received_image)
        assert self._reply_buf_array.__array_interface__['data'][0] == self._reply_buf_image.getRawImage().__int__()
        self._out_buf_array[:, :] = self._reply_buf_array

        print('Waiting for detections or annotations...')
        annotations = yarp.Bottle()
        annotations.clear()
        annotations = self._reply_annotations_port.read()

        self.annotations = []
        if annotations is not None:
            for i in range(0, annotations.size()):
                dets = annotations.get(i).asList()
                if dets.get(0).isInt():
                    bbox = [dets.get(0).asDouble(), dets.get(1).asDouble(), dets.get(2).asDouble(),
                            dets.get(3).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                    cls = dets.get(4).asString()  # label of i-th detection
                    detection_dict = {
                        'bbox': bbox,
                        'class': cls
                    }
                    self.annotations.append(detection_dict)

    def receive_data(self) -> None:
        received_image = self._input_image_port.read()
        print('Image received...')
        self._in_buf_image.copy(received_image)
        assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()

        print('Waiting for detections or annotations...')
        detections = yarp.Bottle()
        detections.clear()
        detections = self._input_predictions_port.read()

        self.predictions = []
        if detections is not None:
            for i in range(0, detections.size()):
                dets = detections.get(i).asList()
                if dets.get(0).isInt():
                    bbox = [dets.get(0).asDouble(), dets.get(1).asDouble(), dets.get(2).asDouble(),
                            dets.get(3).asDouble()]  # bbox format: [tl_x, tl_y, br_x, br_y]
                    score = dets.get(4).asDouble()  # score of i-th detection
                    cls = dets.get(5).asString()  # label of i-th detection
                    detection_dict = {
                        'bbox': bbox,
                        'confidence': score,
                        'class': cls
                    }
                    self.predictions.append(detection_dict)

    def process_data(self) -> None:
        print('to be implemented in StreamUncertaintyBasedMethod')
        # Populate self.annotations
        ask_image = False
        avg_conf = 0
        for p in self.predictions:
            if p['consfidence'] <=0.2:
                ask_image = True
                break
            avg_conf = avg_conf + p['consfidence']
        avg_conf = avg_conf/len(avg_conf)

        if avg_conf >= 0.8:
            self.annotations = self.predictions
            self._out_buf_array[:, :] = self._in_buf_array
        else:
            self.ask_for_annotations()

    def use_data(self) -> None:
        to_send = self._output_annotations_port.prepare()
        to_send.clear()

        if self.annotations is not None:
            for p in self.annotations:
                b = to_send.addList()
                b.addDouble(p['bbox'][0])
                b.addDouble(p['bbox'][1])
                b.addDouble(p['bbox'][2])
                b.addDouble(p['bbox'][3])
                b.addString(p['class'])

        self._output_image_port.write(self._out_buf_image)
        self._output_annotations_port.write()


if __name__ == '__main__':

    rf = yarp.ResourceFinder()
    rf.setVerbose(True)
    rf.setDefaultContext("WeakSupervisionModule")
    conffile = rf.find("from").asString()
    if not conffile:
        print('Using default conf file')
        rf.setDefaultConfigFile('../app/config/ws_module_conf.ini')
    else:
        rf.setDefaultConfigFile(rf.find("from").asString())

    rf.configure(sys.argv)

    # Run module
    sbu_method = StreamUncertaintyBasedMethod()
    # try:
    sbu_method.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
