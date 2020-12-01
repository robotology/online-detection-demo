function sendDetections(detections, detPort, imgPort, image, classes, tool, img_dims)

    b = detPort.prepare();
    b.clear();
    
    is_dets_per_class = cell2mat(cellfun(@(x) ~isempty(x), detections, 'UniformOutput', false));
    if sum(is_dets_per_class)

        % Prepare bottle b with detections and labels
        for i = 1:length(detections)
            for j = 1:size(detections{i},1)
                % Prepare list
                det_list = b.addList();
                % Add bounding box coordinates, score and string label of detected the object
                det_list.addDouble(detections{i}(j,1));       % x_min
                det_list.addDouble(detections{i}(j,2));       % y_min
                det_list.addDouble(detections{i}(j,3));       % x_max
                det_list.addDouble(detections{i}(j,4));       % y_max
                det_list.addDouble(detections{i}(j,5));       % score
                det_list.addString(classes{i});               % string label
                tmp_cls_list = det_list.addList();
                for c =  1:length(classes)
                    tmp_cls_list.addString(classes{c})
                end
            end
        end
    else
        det_list = b.addList();
        tmp_cls_list = det_list.addList();
        for c =  1:length(classes)
            tmp_cls_list.addString(classes{c})
        end
       % disp('no detection found')
    end
    

    
    % Set timestamp for the two ports
    stamp = yarp.Stamp();
    imgPort.setEnvelope(stamp); 
    detPort.setEnvelope(stamp);
    
    %Send image and list of detections
    detPort.write();
%     else
% %         det_list = b.addList();
%        disp('no detection found')
%     end
        % Prepare image to send
    yarp_img = yarp.ImageRgb();                                                 % create a new yarp image to send results to ports
    yarp_img.resize(img_dims(2),img_dims(1));                                   % resize it to the desired size
    yarp_img.zero();                                                            % set all pixels to black
    image = reshape(image, [img_dims(1)*img_dims(2)*img_dims(3) 1]);            % reshape the matlab image to 1D
    tempImg = cast(image ,'int16');                                             % cast it to int16
    yarp_img = tool.setRawImg(tempImg, img_dims(1), img_dims(2), img_dims(3));  % pass it to the setRawImg function (returns the full image)
    imgPort.write(yarp_img);   

end
