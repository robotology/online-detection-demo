function VOCopts = get_voc_opts(path,image_set)

tmp = pwd;
cd(path);
try
%   addpath('VOCcode');
  if(strcmp(image_set,''))
      VOCinit;
  else
  end
catch
%   rmpath('VOCcode');
  cd(tmp);
  error(sprintf('VOCcode directory not found under %s', path));
end
% rmpath('VOCcode');
cd(tmp);
