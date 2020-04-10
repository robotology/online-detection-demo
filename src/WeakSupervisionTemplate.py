import yarp
import numpy as np
from abc import ABC, abstractmethod


class WeakSupervisionTemplate(yarp.RFModule, ABC):
    def configure(self, rf):

        self.image_w = rf.find("image_w").asInt()
        self.image_h = rf.find("image_h").asInt()
        self.module_name = rf.find("module_name").asString()

        self.cmd_port = yarp.Port()
        self.cmd_port.open('/' + self.module_name + '/command:i')
        print('{:s} opened'.format('/' + self.module_name + '/command:i'))
        self.attach(self.cmd_port)

        self.cmd_exploration_port = yarp.BufferedPortBottle()
        self.cmd_exploration_port.open('/' + self.module_name + '/exploration/command:o')
        print('{:s} opened'.format('/' + self.module_name + '/exploration/command:o'))

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

        self.state = 'refine'

        return True

    @abstractmethod
    def receive_data(self) -> None:
        pass

    @abstractmethod
    def process_data(self) -> None:
        pass

    @abstractmethod
    def use_data(self) -> None:
        pass

    def terminate_process(self) -> None:
        pass

    def respond(self, command, reply):
        if command.get(0).asString() == 'refine':
            print('Command refine received')
            self.state = 'refine'
            reply.addString('refine state activated')
        elif command.get(0).asString() == 'stop':
            self.state = 'do_nothing'
            self.terminate_process()
            reply.addString('refine state deactivated')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))
        return True

    def cleanup(self):
        self.cmd_port.close()
        self._input_image_port.close()
        self._input_predictions_port.close()
        self._output_image_port.close()
        self._output_annotations_port.close()
        print('Cleanup function')

    def interruptModule(self):
        print('Interrupt function')
        self.cmd_port.interrupt()
        self._input_image_port.interrupt()
        self._input_predictions_port.interrupt()
        self._output_image_port.interrupt()
        self._output_annotations_port.interrupt()
        return True

    def getPeriod(self):
        return 0.001

    def updateModule(self):
        if self.state == 'do_nothing':
            pass
        elif self.state == 'refine':
            print('refine')
            # receive image and predictions
            self.receive_data()

            # process image and prediction considering:
            # - the chosen policy (SSM, uncertainty based, etc.)
            # - the chosen AL modality (stream based, pool based, etc.)
            self.process_data()

            # Populate the annotation data structure by either using
            # the predictions or sending a query to the the HRI and
            # depending on the chosen scenario send the image and
            # the new annotation back to the matlab or accumulate them
            self.use_data()

        return True
