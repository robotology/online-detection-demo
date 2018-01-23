function [ image_mean ] = image_mean_calculation( )

% I0 = imread('0.1s_1.tif')
% sumImage = double(I0); % Inialize to first image.
% for i=2:10 % Read in remaining images.
%   rgbImage = imread(['0.1s_',num2str(i),'.tif']));
%   sumImage = sumImage + double(rgbImage);
% end;
% meanImage = sumImage / 10;
% 
% 
% mdb.image_ids = textread(sprintf(ICUBopts.imgsetpath, image_set), '%s');

fid = fopen('/home/IIT.LOCAL/emaiettini/workspace/Datasets/PascalVoc/VOCdevkit/VOC2007_test/ImageSets/Main/test.txt');
tline = fgetl(fid);
counter = 0;
% I0 = imread(strcat('/home/IIT.LOCAL/emaiettini/workspace/Datasets/PascalVoc/VOCdevkit/VOC2007/JPEGImages/',tline, '.jpg'));
% sumImage = double(I0); % Inialize to first image.
sumImage = zeros(224,224);
chosen_number = 0;
while ischar(tline)
    disp(tline)
    rgbImage = imread(strcat('/home/IIT.LOCAL/emaiettini/workspace/Datasets/PascalVoc/VOCdevkit/VOC2007_test/JPEGImages/',tline, '.jpg'));
    rgbImage = imresize(rgbImage,[224 224]);
    sumImage = sumImage + double(rgbImage);
    chosen_number = chosen_number +1;
    tline = fgetl(fid);
end

image_mean = sumImage / chosen_number;

fclose(fid);


