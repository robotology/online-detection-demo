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
    bkg_numb = 7000;
    gpu_id = 1;
    sigma = 28;
    lambda = 0.0001;
    iterations = [1 5 10 15 20 25 30 35 40 45 50];
    script_FALKON_voc2007_ZF_T_variation(bkg_numb, sigma, lambda, iterations, gpu_id);
    sendmail({'elisa.maiettini@gmail.com'}, ['Done T variation']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error T variation!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


