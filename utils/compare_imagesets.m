function compare_imagesets( full_set_filename, to_remove_filename, new_imageset_filename )

 full_set = textread(full_set_filename, '%s');
 to_remove_set = textread(to_remove_filename, '%s');
  
fid = fopen(new_imageset_filename, 'w');

  
  for i=1:length(full_set)
      to_remove = false;
      for j=1:length(to_remove_set)
          if strcmp(to_remove_set{j},full_set{i})
             to_remove = true; 
          end
      end
      if ~to_remove
         fprintf(fid, '%s\n',full_set{i});
      end
  end
  

end

