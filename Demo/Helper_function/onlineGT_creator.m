function [  ] = onlineGT_creator(  )

current_path = pwd;
dataset_path = [current_path '/datasets/iCubWorld-Transformations/'];

image_set = 'train_TASK2_10objs';
image_ids = importdata([dataset_path, 'ImageSets/', image_set, '.txt']);

annotations = cell(length(image_ids),1);
for j = 1:length(image_ids)
    annotations{j} = struct;
    xml_file_name = [dataset_path 'Annotations/' image_ids{j} '.xml' ];
    DOMnode = xmlread(xml_file_name);
    annotations{j}.bbox = [str2double(DOMnode.getElementsByTagName( 'xmin' ).item(0).getFirstChild().getNodeValue()),str2double(DOMnode.getElementsByTagName( 'ymin' ).item(0).getFirstChild().getNodeValue()),str2double(DOMnode.getElementsByTagName( 'xmax' ).item(0).getFirstChild().getNodeValue()),str2double(DOMnode.getElementsByTagName( 'ymax' ).item(0).getFirstChild().getNodeValue())];
    annotations{j}.label = str2mat(DOMnode.getElementsByTagName( 'name' ).item(0).getFirstChild().getNodeValue());
end

end

