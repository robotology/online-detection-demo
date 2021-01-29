function sendTrainDone(portAnnOut)
    b = portAnnOut.prepare();
    b.clear();
    
    det_list = b.addList();
    det_list.addString('done.');
        
    stamp = yarp.Stamp();
    portAnnOut.setEnvelope(stamp);
 
    portAnnOut.write();
end