from kivy.app import App
from kivy.uix.button import Button
from kivy.uix.floatlayout import FloatLayout
from kivy.uix.gridlayout import GridLayout
from kivy.core.window import Window
from kivy.config import Config
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput

import yarp
yarp.Network.init()

class ButtonsLayout(GridLayout):
    def __init__(self, labels, port, strInputLayout):
        super(ButtonsLayout, self).__init__(cols=2, spacing=[5,5], padding=[10,10,10,10])
        self.label_dict = labels
        self._out_port = port
        self.message = None
        self.strInputLayout = strInputLayout
        self.others = None

        for label, message in self.label_dict.items():
            print(label)
            button = Button(text=label, color=[0.4,0.4,0.4,1], background_color=[0.8,0.8,0.8,0.2])
            button.bind(on_press=self.buttonPressed)
            self.add_widget(button)


    def buttonPressed(self, instance):
        print(instance.text)

        self.message = None
        for i in range(0, len(self.label_dict[instance.text])):
            if self.message is None:
                self.message = self.label_dict[instance.text][i]
            else:
                self.message = self.message + ' ' + self.label_dict[instance.text][i]

        is_canceled = False
        if not instance.text is 'Train' and not instance.text is 'Forget' and not instance.text is 'Confirm':
            print('Sending message : ***{}***'.format(self.message))
            self.send_message()
            if instance.text == 'Start refinement':
                for child in self.children:
                    if child.text == 'Stop refinement':
                        child.disabled = False
                    else:
                        child.disabled = True

            elif instance.text == 'Stop refinement': 
                for child in self.children:
                    child.disabled = False

            if instance.text == 'Quit':
                exit(0)
            self.message = None
            
        else:
            if not self.others is None:
                for other in self.others:
                    other.disabled = True 
            self.disabled = True
            self.strInputLayout.disabled = False

    def send_message(self):
        to_send = self._out_port.prepare()
        to_send.clear()
        words_list = self.message.split(' ')
        for i in range(len(words_list)):
            to_send.addString(words_list[i])
        self._out_port.write()

    def get_message(self):
        return self.message

    def set_message(self, value):
        self.message = value

    def set_others(self, others):
        self.others = list(others)


class StrInputLayout(GridLayout):
    def __init__(self, port):
        super(StrInputLayout, self).__init__(cols=1, spacing=[5,5], padding=[10,10,10,10])

        self._out_port = port
        self.obj_name = None
        self.is_canceled = False
        self.button_layouts = None

        layout = GridLayout(cols=2, spacing=[5,5], padding=[10,10,10,10])

        layout.add_widget(Label(text='Insert object name', color=[0.4,0.4,0.4,1]))

        self.text_input = TextInput(multiline=False, text='object')
        self.text_input.bind(on_text_validate=self.on_enter)
        layout.add_widget(self.text_input)

        button = Button(text='Cancel', color=[0.4,0.4,0.4,1], background_color=[0.8,0.8,0.8,0.2])
        button.bind(on_press=self.cancelButtonPressed)

        self.add_widget(layout)

        self.add_widget(button)

    def cancelButtonPressed(self, instance):
        #self.text_input.disabled = True
        for button_layout in self.button_layouts:
            button_layout.set_message(None)

        if not self.button_layouts is None:
            for other in self.button_layouts:
                other.disabled = False 
        self.disabled = True

        print(instance.text)

    def on_enter(self, value):
        print('User pressed enter in ', value.text)
        for button_layout in self.button_layouts:
            message = button_layout.get_message()
            if not message is None:
                message = message + ' ' + value.text
                print('Sending message : ***{}***'.format(message))
                self.send_message(message)
                button_layout.set_message(None)
                break
        if not self.button_layouts is None:
            for other in self.button_layouts:
                other.disabled = False 
        self.disabled = True

    def set_button_layouts(self, button_layouts):
        self.button_layouts = list(button_layouts)


    def send_message(self, message):
        to_send = self._out_port.prepare()
        to_send.clear()
        words_list = message.split(' ')
        for i in range(len(words_list)):
            to_send.addString(words_list[i])
        self._out_port.write()



class OODRemoteLayout(GridLayout):

    def __init__(self):
        module_name = 'HRIgui'
        out_port = yarp.BufferedPortBottle()
        out_port.open('/' + module_name + '/cmd:o')
        print('{:s} opened'.format('/' + module_name + '/cmd:o'))
        super(OODRemoteLayout, self).__init__(cols=1)

        detection_label_dict = {'Train': ['train'], 'Start refinement': ['refine', 'start'], 'Stop refinement': ['refine', 'stop'], 'Forget': ['forget']}
        annotation_label_dict = {'Add': ['annotation', 'add'], 'Delete': ['annotation', 'delete'], 'Select': ['annotation', 'select'], 'Confirm': ['annotation', 'done'], 'Done.': ['annotation', 'finish'], 'Quit': ['quit']}  

        Window.size = (500, 500)
        Window.clearcolor = (1, 1, 1, 0.8)

        strInputLayout   = StrInputLayout(out_port)
        detectionLayout  = ButtonsLayout(detection_label_dict, out_port, strInputLayout) 
        annotationLayout = ButtonsLayout(annotation_label_dict, out_port, strInputLayout) 

        detectionLayout.set_others([annotationLayout])
        annotationLayout.set_others([detectionLayout])
        strInputLayout.set_button_layouts([detectionLayout, annotationLayout])
        strInputLayout.disabled = True

        self.add_widget(detectionLayout)
        self.add_widget(annotationLayout)
        self.add_widget(strInputLayout)


class OODRemote(App):
    
    def build(self):
        return OODRemoteLayout()

if __name__ == '__main__':
    OODRemote().run() 
