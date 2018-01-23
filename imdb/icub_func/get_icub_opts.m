function ICUBopts = get_icub_opts(path, image_set)

tmp = pwd;
cd(path);
try
%   addpath('VOCcode');
  if strcmp(image_set, 'train') || strcmp(image_set, 'test')
    ICUBinit; %ELISA todo
  elseif strcmp(image_set, 'TASK2_train') || strcmp(image_set, 'TASK2_test')
    TASK2_ICUBinit;
  elseif strcmp(image_set, 'TASK1_train') || strcmp(image_set, 'TASK1_test')
    TASK1_ICUBinit;
  end
catch
%   rmpath('VOCcode');
  cd(tmp);
  error(sprintf('get_icub_opts: ICUBcode directory not found under %s', path));
end
% rmpath('VOCcode');
cd(tmp);
