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
    sigma = [15 20 26 30 35];
    lambda = 0.0001;
    Nystrom_centres = 3000;
    iterations = 100;
    target_norms = [5 10 15 20 25 30 35];
    script_FALKON_voc2007_ZF_CV_norm_targets(bkg_numb, sigma, lambda, Nystrom_centres, iterations, target_norms, gpu_id);
    sendmail({'elisa.maiettini@gmail.com'}, ['Done M variation']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error M variation!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


