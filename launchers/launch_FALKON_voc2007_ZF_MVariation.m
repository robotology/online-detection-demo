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
    gpu_id = 1;
    sigma = 26;
    lambda = 0.0001;
    Nystrom_centres = [40 50 70 80 90 100 500 1000 1500 2000];
    iterations = [100];
    script_FALKON_voc2007_ZF_M_variation(bkg_numb, sigma, lambda, Nystrom_centres, iterations, gpu_id);
    sendmail({'elisa.maiettini@gmail.com'}, ['Done M variation']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error M variation!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


