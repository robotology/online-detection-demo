import sys
import yarp
import numpy as np
import os
import torch

basedir = os.path.dirname(__file__)
sys.path.append(os.path.abspath(os.path.join(basedir, os.path.pardir, '..')))
import WeakSupervisionTemplate as wsT
# Initialise YARP
yarp.Network.init()


class InteractionBasedMethod(wsT.WeakSupervisionTemplate):
    def configure(self, rf):
        super(InteractionBasedMethod, self).configure(rf)
        self.arm = rf.find("arm").asString()  # self.arm = 'left' or 'right'
        self.predictions = []
        self.annotations = []

        self._ask_image_port = yarp.Port()
        self._ask_image_port.open('/' + self.module_name + '/ask/image:o')
        print('{:s} opened'.format('/' + self.module_name + '/ask/image:o'))

        self._ask_annotations_port = yarp.BufferedPortBottle()
        self._ask_annotations_port.open('/' + self.module_name + '/ask/annotations:o')
        print('{:s} opened'.format('/' + self.module_name + '/ask/annotations:o'))

        self._send_exploration_image_port = yarp.Port()
        self._send_exploration_image_port.open('/' + self.module_name + '/exploration/image:o')
        print('{:s} opened'.format('/' + self.module_name + '/exploration/image:o'))

        self._send_exploration_targets_port = yarp.BufferedPortBottle()
        self._send_exploration_targets_port.open('/' + self.module_name + '/exploration/targets:o')
        print('{:s} opened'.format('/' + self.module_name + '/exploration/targets:o'))

        self._reply_image_port = yarp.BufferedPortImageRgb()
        self._reply_image_port.open('/' + self.module_name + '/reply/image:i')
        print('{:s} opened'.format('/' + self.module_name + '/reply/image:i'))

        self._reply_annotations_port = yarp.BufferedPortBottle()
        self._reply_annotations_port.open('/' + self.module_name + '/reply/annotations:i')
        print('{:s} opened'.format('/' + self.module_name + '/reply/annotations:i'))

        # Ports to send commands to state machine and detection modules
        self.manager_cmd = yarp.BufferedPortBottle()
        self.manager_cmd.open('/' + self.module_name + '/manager_cmd:o')
        print('{:s} opened'.format('/' + self.module_name + '/manager_cmd:o'))

        print('Preparing image to ask annotation...')
        self._ask_buf_image = yarp.ImageRgb()
        self._ask_buf_image.resize(self.image_w, self.image_h)
        self._ask_buf_array = np.zeros((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._ask_buf_image.setExternal(self._ask_buf_array.data, self._ask_buf_array.shape[1], self._ask_buf_array.shape[0])

        print('Preparing annotated image...')
        self._reply_buf_array = np.ones((self.image_h, self.image_w, 3), dtype=np.uint8)
        self._reply_buf_image = yarp.ImageRgb()
        self._reply_buf_image.resize(self.image_w, self.image_h)
        self._reply_buf_image.setExternal(self._reply_buf_array.data, self._reply_buf_array.shape[1], self._reply_buf_array.shape[0])

        self.skip = False
        self.performed_action = 'active'
        self.exploring = False
        self.state = 'do_nothing'

        return True

    def respond(self, command, reply):
        super(InteractionBasedMethod, self).respond(command, reply)
        if command.get(0).asString() == 'interaction':
            if self.exploring:
                if command.get(1).asString() == 'success':
                    self.exploring = False
                    # Send to the state machine the end of the exploration phase
                    self.send_interaction_success()
                    reply.addString('Current interaction step succeeded, stopping interaction')
                    print('Current interaction step succeeded, starting next one')
                    self.state = 'do_nothing'
                elif command.get(1).asString() == 'fail':
                    self.exploring = False
                    # Send to the state machine the end of the exploration phase with failure:
                    # an action needs to be taken, like the human moving the objects in front of the robot
                    # to change the current configuration
                    self.send_interaction_failure()
                    reply.addString('Current interaction step failed, stopping interaction')
                    print('Current interaction step failed')
                    self.state = 'do_nothing'
                else:
                    reply.addString('No ongoing interaction. Doing nothing.')
                    print('No ongoing interaction. Doing nothing.')
        elif command.get(0).asString() == 'refine':
            self.skip = False
        elif command.get(0).asString() == 'start':
            if command.get(1).asString() == 'interaction':
                self.skip = False
                self.state = 'refine'
                reply.addString('Enetering interaction state.')
                print('Enetering interaction state.')
            else:
                reply.addString('Unknown action to start')
                print('Unknown action to start.')
        elif command.get(0).asString() == 'stop':
            if command.get(1).asString() == 'interaction':
                self.state = 'do_nothing'
                reply.addString('Stopping interaction state.')
                print('Stopping interaction state.')
            else:
                reply.addString('Unknown action to start')
                print('Unknown action to start.')
        else:
            print('Command {:s} not recognized'.format(command.get(0).asString()))
            reply.addString('Command {:s} not recognized'.format(command.get(0).asString()))
        return True

    def send_interaction_success(self):
        if self.state == 'refine':
            print('sending interaction success')
            to_send = self.manager_cmd.prepare()
            to_send.clear()
            to_send.addString('interact')
            to_send.addString('stop')
            self.manager_cmd.write()
            self.state = 'do_nothing'
            self.skip = True
        else:
            print('Not sending interaction success')

    def send_interaction_failure(self):
        if self.state == 'refine':
            print('sending interaction failure')
            to_send = self.manager_cmd.prepare()
            to_send.clear()
            to_send.addString('interact')
            to_send.addString('fail')
            self.manager_cmd.write()
            self.skip = True
            self.state = 'do_nothing'
        else:
            print('Not sending interaction failure')

    def ask_for_annotations(self):
        # Send image and doubtful predictions to the annotator
        self._ask_buf_array[:, :] = self._in_buf_array

        to_send = self._ask_annotations_port.prepare()
        to_send.clear()
        t = to_send.addList()

        if self.predictions is not None:
            for p in self.predictions:
                b = t.addList()
                b.addDouble(p['bbox'][0])
                b.addDouble(p['bbox'][1])
                b.addDouble(p['bbox'][2])
                b.addDouble(p['bbox'][3])
                b.addString(p['class'])

        self._ask_annotations_port.write()
        self._ask_image_port.write(self._ask_buf_image)

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

    def propagate_image(self):
        self._ask_buf_array[:, :] = self._in_buf_array
        self._ask_image_port.write(self._ask_buf_image)

        to_send = self._ask_annotations_port.prepare()
        to_send.clear()
        to_send.addString('skip')
        self._ask_annotations_port.write()

    def receive_data(self) -> None:
        if self.state == 'refine':
            print('Waiting for detections...')
            detections = yarp.Bottle()
            detections.clear()
            detections = self._input_predictions_port.read()
            received_image = self._input_image_port.read()
            print('Image received...')
            self._in_buf_image.copy(received_image)
            assert self._in_buf_array.__array_interface__['data'][0] == self._in_buf_image.getRawImage().__int__()

            self.predictions = []
            if detections is not None:
                for i in range(0, detections.size()):
                    dets = detections.get(i).asList()
                    if dets.get(0).isDouble():
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
        else:
            print('Not receivieng data')

    @staticmethod
    def compute_overlap(A, B):
        '''
        calculate two box's iou
        '''
        width = min(A[2], B[2]) - max(A[0], B[0]) + 1
        height = min(A[3], B[3]) - max(A[1], B[1]) + 1
        if width <= 0 or height <= 0:
            return 0
        Aarea = (A[2] - A[0]) * (A[3] - A[1] + 1)
        Barea = (B[2] - B[0]) * (B[3] - B[1] + 1)
        iner_area = width * height
        return iner_area / (Aarea + Barea - iner_area)

    def pick_target(self):
        '''
        This function compares the predictions and annotations
        and pick the first to explore
        '''
        self.target = [-1] * 4

        # Compute IoU between predictions and annotations of the same class
        all_max_overlaps = -1 * np.ones([len(self.annotations), 2])
        temp_predictions = self.predictions.copy()
        for i in range(0, len(self.annotations)):
            a = self.annotations[i]
            c = a['class']
            max_overlap = -1
            max_overlap_id = -1
            # Find the prediction that overlaps the most with a
            for j, p in enumerate(temp_predictions):
                if c == p['class']:
                    overlap = self.compute_overlap(a['bbox'], p['bbox'])
                    if overlap > max_overlap:
                        max_overlap = overlap
                        max_overlap_id = j
            # If the prediction has been found, retrieve the index back in the original list
            if not max_overlap == -1:
                p = temp_predictions[max_overlap_id]
                for k, pp in enumerate(self.predictions):
                    if p['class'] == pp['class'] and p['bbox'][0] == pp['bbox'][0] and p['confidence'] == pp['confidence']:
                        all_max_overlaps[i] = [max_overlap, k]
                        break
            if max_overlap > 0.6:
                temp_predictions.pop(max_overlap_id)

        # Compute centers
        centers = [-1] * len(self.annotations)
        for i, a in enumerate(self.annotations):
            cx = a['bbox'][0] + (a['bbox'][2] - a['bbox'][0])/2
            cy = a['bbox'][1] + (a['bbox'][3] - a['bbox'][1])/2
            centers[i] = [cx, cy]

        # Pick the target to explore such that:
        # - If there are annotations without corresponding detections, you choose the one closer to considered arm
        # - If all annotations have a correspondent detection, you choose the one with the lowest confidence which is
        #   in the workspace of the considered arm
        # indices = [i for i, x in enumerate(all_max_overlaps) if x == -1]
        indices = np.where(all_max_overlaps[:, 0] == -1)[0]
        if indices.size:
            index_to_pick = -1
            if self.arm == 'left':
                print('Picking target for left arm from annotations')
                x_to_pick = int((self.image_w/9)*4)
                for i in indices:
                    if centers[i][0] < x_to_pick:
                        x_to_pick = centers[i][0]
                        index_to_pick = i
            else:
                print('Picking target for right arm from annotations')
                x_to_pick = int(self.image_w/3)+1
                for i in indices:
                    if centers[i][0] > int((self.image_w/9)*6):
                        x_to_pick = centers[i][0]
                        index_to_pick = i
            if not index_to_pick == -1:
                print(self.annotations[index_to_pick]['class'])
                self.target[:] = self.annotations[index_to_pick]['bbox'][:]

        if self.target[0] == -1:
            index_to_pick = -1
            confidence_to_pick = 2
            for i, p in enumerate(self.predictions):
                if np.where(all_max_overlaps[:, 1] == i)[0].size and p['confidence'] < confidence_to_pick:
                    center_x = p['bbox'][0] + (p['bbox'][2] - p['bbox'][0])/2
                    if self.arm == 'left' and center_x < int((self.image_w/9)*4):
                        print('Picking target for left arm from predictions')
                        index_to_pick = np.where(all_max_overlaps[:, 1] == i)[0][0]
                        confidence_to_pick = p['confidence']
                    elif self.arm == 'right' and center_x > int((self.image_w/9)*6):
                        print('Picking target for right arm from predictions')
                        index_to_pick = np.where(all_max_overlaps[:, 1] == i)[0][0]
                        confidence_to_pick = p['confidence']
                    else:
                        print('Conditions not verified')
            if not index_to_pick == -1:
                self.target[:] = self.annotations[index_to_pick]['bbox'][:]
                print(self.annotations[index_to_pick]['class'])
            else:
                print('Exploration target not found')
                self.exploring = False
                self.send_interaction_failure()
                self.state = 'do_nothing'

    def send_exploration_target(self):
        '''
        This function sends the next target to explore
        '''
        if self.state == 'refine' and not self.target[0] == -1 and not self.skip:
            print('Sending exploration target')
            to_send = self._send_exploration_targets_port.prepare()
            to_send.clear()
            #t = to_send.addList()

            b = to_send.addList()
            b.addInt(int(self.target[0]))
            b.addInt(int(self.target[1]))
            b.addInt(int(self.target[2]))
            b.addInt(int(self.target[3]))
            self._send_exploration_targets_port.write()
            self._send_exploration_image_port.write(self._ask_buf_image)  # To check if it is still the correct image
            self.exploring = True
        else:
            print('No exploration target sent')

    def process_data(self) -> None:
        '''
        After receiving a prediction:
          - if we are in interaction mode but still not exploring:
             1. Asks the annotation to the tracker
             2. Pick the box to explore
             3. Sends a new target to explore
          - if we are not in interaction mode and we are not exploring we only
          want to propagate image to the tracker
        '''
        if not self.exploring and self.state == 'refine':
            self.ask_for_annotations()
            self.pick_target()
            self.send_exploration_target()
        elif self.exploring and self.state == 'refine':
            self._out_buf_array[:, :] = self._in_buf_array
            self.propagate_image()

    def use_data(self) -> None:
        if self.state == 'refine':
            print('Using received annotations')
            to_send = self._output_annotations_port.prepare()
            to_send.clear()

            if self.annotations is not None and not self.skip:
                for p in self.annotations:
                    b = to_send.addList()
                    # b.addString('train')
                    b.addDouble(p['bbox'][0])
                    b.addDouble(p['bbox'][1])
                    b.addDouble(p['bbox'][2])
                    b.addDouble(p['bbox'][3])
                    b.addString(p['class'])
                    b.addString(self.performed_action)
            elif self.skip:
                self.skip = False
                to_send.addString('skip')

            self._output_annotations_port.write()
            self._output_image_port.write(self._out_buf_image)
        else:
            pass

    def cleanup(self):
        super(InteractionBasedMethod, self).cleanup()
        self._ask_image_port.close()
        self._ask_annotations_port.close()
        self._reply_image_port.close()
        self._reply_annotations_port.close()

        print('Cleanup function')

    def interruptModule(self):
        print('Interrupt function')
        super(InteractionBasedMethod, self).interruptModule()
        self._ask_image_port.interrupt()
        self._ask_annotations_port.interrupt()
        self._reply_image_port.interrupt()
        self._reply_annotations_port.interrupt()

        return True


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
    sbu_method = InteractionBasedMethod()
    # try:
    sbu_method.runModule(rf)
    # finally:
    #     print('Closing SegmentationDrawer due to an error..')
    #     player.cleanup()
