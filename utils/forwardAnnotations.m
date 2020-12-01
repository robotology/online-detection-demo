function forwardAnnotations(yarp_img, boxes, new_labels, imgPort, portAnnOut)
    b = portAnnOut.prepare();
    b.clear();
    
    for i=1:size(boxes, 1)
        det_list = b.addList();
        det_list.addString('train');
        det_list.addDouble(boxes(i,1));       % x_min
        det_list.addDouble(boxes(i,2));       % y_min
        det_list.addDouble(boxes(i,3));       % x_max
        det_list.addDouble(boxes(i,4));       % y_max
        det_list.addString(new_labels{i});    % string label
    end
        
    stamp = yarp.Stamp();
    imgPort.setEnvelope(stamp); 
    portAnnOut.setEnvelope(stamp);
   
    portAnnOut.write();
    imgPort.write(yarp_img);   
end