function ICUBopts = get_icub_opts(path)

tmp = pwd;
cd(path);
try
  addpath('VOCcode');
  ICUBinit; %ELISA todo
catch
  rmpath('VOCcode');
  cd(tmp);
  error(sprintf('get_icub_opts: ICUBcode directory not found under %s', path));
end
rmpath('VOCcode');
cd(tmp);
