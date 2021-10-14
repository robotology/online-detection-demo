import numpy
import time
import yarp
from pyquaternion import Quaternion

props = yarp.Property()
props.put('device', 'gazecontrollerclient')
props.put('local', '/sin_gaze/gaze')
props.put('remote', '/iKinGazeCtrl')
gaze_driver = yarp.PolyDriver(props)
gaze = gaze_driver.viewIGazeControl()
gaze.blockNeckRoll(0.0);
gaze.setNeckTrajTime(1.0);
gaze.setEyesTrajTime(1.0);
# gaze.clearEyes()
# gaze.blockEyes(0.0)
image_w = 640
image_h = 480

home_vec = yarp.Vector(3)
home_vec[0] = float(-1.0)
home_vec[1] = float(0.0)
home_vec[2] = float(0.3)
gaze.lookAtFixationPoint(home_vec)

cmd_port = yarp.BufferedPortBottle()
cmd_port.open('/blob-tracker/command:i')

camera_pose_port = yarp.BufferedPortVector()
camera_pose_port.open('/blob-tracker/pose:i')
yarp.Network().connect('/realsense-holder-publisher/pose:o', '/blob-tracker/pose:i')

blob_in_port = yarp.BufferedPortBottle()
blob_in_port.open('/blob-tracker/blob:i')
yarp.Network().connect('/dispBlobber/roi/left:o', '/blob-tracker/blob:i')

depth_in_port = yarp.BufferedPortImageFloat()
depth_in_port.open('/blob-tracker/depth:i')
yarp.Network().connect('/depthCamera/depthImage:o', '/blob-tracker/depth:i')

depth_img = yarp.ImageFloat()
depth_img.resize(image_w, image_h)
depth_array = numpy.ones((image_h, image_w, 1), dtype=numpy.float32)
depth_img.setExternal(depth_array.data, depth_array.shape[1], depth_array.shape[0])

camera_fx = 618.0714111328125
camera_fy = 617.783447265625
camera_cx = 305.902252197265625
camera_cy = 246.352935791015625


#target_pose_port = yarp.BufferedPortVector()
#target_pose_port.open('/target/pose/in')
#yarp.Network().connect('/roft-tracker/probe/pose:o', '/target/pose/in')


def yarp_vector_to_se3(port):
    vector = port.read(False)

    if vector is not None:
        H = Quaternion(axis = [vector[3], vector[4], vector[5]], angle = vector[6]).transformation_matrix
        for i in range(3):
            H[i, 3] = vector[i]

        return True, H
    else:
        return False, []
        

def blob_to_UVtarget(blob):    
    blob_coord = blob.get(0).asList()
    print('Received blob (tlx,tly,brx,bry): ({},{},{},{})'.format(blob_coord.get(0).asInt(), blob_coord.get(1).asInt(), blob_coord.get(2).asInt(), blob_coord.get(3).asInt()))
    target_u = (blob_coord.get(0).asInt() + blob_coord.get(2).asInt())/2
    target_v = (blob_coord.get(1).asInt() + blob_coord.get(3).asInt())/2
    print('Correspondent pixel_target (u,v): ({}, {})'.format(target_u, target_v))
    
    return numpy.array([target_u, target_v])
    
def UVtarget_to_xyztarget(pixel_target, depth_img_array):
    # Retrieve Depth from pixel
    d = depth_img_array[int(pixel_target[1]),int(pixel_target[0]),0]
    print('depth: {}'.format(d))
    
    # Convert uv to xy
    target_x = (pixel_target[0] - camera_cx)/camera_fx
    target_y = (pixel_target[1] - camera_cy)/camera_fy
    print('Converted (x,y): ({},{})'.format(target_x, target_y))
    
    return numpy.array([target_x, target_y, d])
  
def xyztarget_to_targetH(target_xyz):   
    target_H = numpy.array([[1,0,0,target_xyz[0]], [0,1,0,target_xyz[1]], [0,0,1,target_xyz[2]],[0,0,0,1]])
    print('target_H: {}'.format(target_H))
    return target_H   

cam_H = None
target_H = None
numpy.set_printoptions(suppress=True)
track = False
home = False

while True:
    cmd = cmd_port.read(False)
    if cmd is not None:
        if cmd.get(0).asString() == 'track-blob':
            track = True
            print('received track-blob')
        elif cmd.get(0).asString() == 'stop':
            print('received stop')
            track = False
            home = False
    
    if track:    
        ok, new_cam_H = yarp_vector_to_se3(camera_pose_port)
        if ok:
    	    cam_H = new_cam_H
	
        blob = blob_in_port.read(True) # blob = (tlx,tly,brx,bry)
        received_img = depth_in_port.read(True)
        depth_img.copy(received_img)
        assert depth_array.__array_interface__['data'][0] == depth_img.getRawImage().__int__()
    
        pixel_target = blob_to_UVtarget(blob)    
        target_xyz = UVtarget_to_xyztarget(pixel_target, depth_array)
        target_H = xyztarget_to_targetH(target_xyz)

        #if (cam_H is not None) and (target_H is not None):
        if (cam_H is not None):
        #if target_H is not None:
            root_to_target = cam_H.dot(target_H)
	    #root_to_target = target_H

            target_np = [root_to_target[i, 3] for i in range(3)]
            target = yarp.Vector(3)
            for i in range(3):
                target[i] = root_to_target[i, 3]
            if target_np[0] > -1.0:
                print('target: {}'.format(target_np))
                gaze.lookAtFixationPoint(target)
        time.sleep(1 / 30.0)
        print('------------------------------------------------------------------------------')
    else:
        if not home:
            gaze.lookAtFixationPoint(home_vec)
            home = True
            
