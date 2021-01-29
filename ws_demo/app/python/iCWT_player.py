import yarp
import numpy as np
from PIL import Image
import os
import xml.etree.ElementTree as ET


# Initialise YARP
yarp.Network.init()
dataset_folder = '/home/elisa/Data/Datasets/iCubWorld-Transformations'
images_folder = dataset_folder + '/Images'
annotations_folder = dataset_folder + '/Annotations'
imageset = dataset_folder + '/ImageSets/sprayers.txt'

image_w = 640
image_h = 480

output_image_port = yarp.Port()
output_image_port.open('/iCWTPlayer/image:o')
print('{:s} opened'.format('/iCWTPlayer/image:o'))

output_box_port = yarp.BufferedPortBottle()
output_box_port.open('/iCWTPlayer/box:o')
print('{:s} opened'.format('/iCWTPlayer/box:o'))

print('Preparing output image...')
out_buf_image = yarp.ImageRgb()
out_buf_image.resize(image_w, image_h)
out_buf_array = np.zeros((image_h, image_w, 3), dtype=np.uint8)
out_buf_image.setExternal(out_buf_array, out_buf_array.shape[1], out_buf_array.shape[0])

if __name__ == '__main__':
    with open(imageset, 'r') as f:
        lines = f.readlines()

    while True:
        for item in lines:
            item = item.rstrip()
            print(item)

            image = np.array(Image.open(os.path.join(images_folder, item + '.jpg')))
            out_buf_array[:, :] = image

            annotations = ET.parse(os.path.join(annotations_folder, item + '.xml')).getroot()

            annotations_bottle = output_box_port.prepare()
            annotations_bottle.clear()
            for object in annotations.findall('object'):
                b = annotations_bottle.addList()
                bbox = object.find('bndbox')
                b.addInt(int(bbox.find('xmin').text))
                b.addInt(int(bbox.find('ymin').text))
                b.addInt(int(bbox.find('xmax').text))
                b.addInt(int(bbox.find('ymax').text))
                b.addString(object.find('name').text)

            output_image_port.write(out_buf_image)
            output_box_port.write()
