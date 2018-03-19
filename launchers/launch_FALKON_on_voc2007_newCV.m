myaddress = 'icubmatlab@gmail.com';
mypassword = 'icubmatlabAdmin';

setpref('Internet','E_mail',myaddress);
setpref('Internet','SMTP_Server','smtp.gmail.com');
setpref('Internet','SMTP_Username',myaddress);
setpref('Internet','SMTP_Password',mypassword);

props = java.lang.System.getProperties;
props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.socketFactory.class', ...
                  'javax.net.ssl.SSLSocketFactory');
props.setProperty('mail.smtp.socketFactory.port','465');

try
    startup;
    bkg_numb = 5000;
    gpu_id = 2;   
    Nystrom_centres = 3000;
    script_FALKON_on_voc2007_newCV(bkg_numb, Nystrom_centres, gpu_id)
    sendmail({'elisa.maiettini@gmail.com'}, ['Done: light CV']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error light CV!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


