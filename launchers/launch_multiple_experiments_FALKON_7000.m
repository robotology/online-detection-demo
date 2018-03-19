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
    bkg_numbs = 7000;
    gpu_id = 1;
    sigmas = [1 16 18 20 22 24 26 28 30 40 50 60 70 80 90 100];
    script_multiple_rls_voc2007_reduced_ZF(bkg_numbs, sigmas, gpu_id);
    sendmail({'elisa.maiettini@gmail.com'}, ['Done FALKON 7000 bkg']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error FALKON 7000 bkg!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


