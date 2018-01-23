function VOCopts = get_voc_opts_reduced(path,image_set,removed_classes)

tmp = pwd;
cd(path);
try
%   addpath('VOCcode');
  if(strcmp(image_set,''))
      VOCinit;
  else
      VOCinit_reduced;
  end
catch
%   rmpath('VOCcode');
  cd(tmp);
  error(sprintf('VOCcode directory not found under %s', path));
end
% rmpath('VOCcode');
cd(tmp);
