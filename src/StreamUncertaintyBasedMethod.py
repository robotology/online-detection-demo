from src import WeakSupervisionTemplate as wsT
import sys
import yarp

# Initialise YARP
yarp.Network.init()


class StreamUncertaintyBasedMethod(wsT.WeakSupervisionTemplate):
    def configure(self, rf):
        super(StreamUncertaintyBasedMethod, self).configure(rf)
        self.predictions = []
        self.annotations = []
        return True

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
        for p in self.predictions:
            self.annotations.append(
                {'bbox': p['bbox'],
                 'class': p['class']}
            )

    def use_data(self) -> None:
        self._out_buf_array[:, :] = self._in_buf_array

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


