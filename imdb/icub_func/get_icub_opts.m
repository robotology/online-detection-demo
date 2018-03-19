function ICUBopts = get_icub_opts(path, image_set,chosen_classes)

tmp = pwd;
cd(path);
try
%   if strcmp(image_set, 'train') || strcmp(image_set, 'test') || strcmp(image_set, 'val')
    ICUBinit; %Actually it should be always executed this code..TO CHECK
%     
%   elseif strcmp(image_set, 'TASK2_train') || strcmp(image_set, 'TASK2_test')
%     TASK2_ICUBinit;
%   elseif strcmp(image_set, 'TASK1_train') || strcmp(image_set, 'TASK1_test')
%     TASK1_ICUBinit;
%   end
catch
  cd(tmp);
  error(sprintf('get_icub_opts: ICUBcode directory not found under %s', path));
end
cd(tmp);
