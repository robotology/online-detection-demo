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
%     sigmas = [5 10 12 15 18 20 24];
%     lambdas = [0.001 0.0001 0.00001 0.000001 0.0000001];
%     script_FALKON_on_voc2007_ZF_bboxReg_validation(7000, sigmas, lambdas, 2);
    script_FALKON_on_voc2007_ZF_bboxReg_validation(7000, 12, 0.0001, 1)
    sendmail({'elisa.maiettini@gmail.com'}, ['Done: bbox reg validation']);
    quit;
catch error_struct
    sendmail({'elisa.maiettini@gmail.com'},'Error bbox reg validation!', [error_struct.message char(10) 'in file: ' error_struct.stack(1).file char(10) 'at line: ' num2str(error_struct.stack(1).line)]);
    quit;
end


