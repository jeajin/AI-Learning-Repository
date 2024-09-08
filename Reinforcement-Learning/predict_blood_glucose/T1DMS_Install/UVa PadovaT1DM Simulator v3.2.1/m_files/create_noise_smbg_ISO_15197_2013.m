%> @file create_noise_smbg_ISO_15197_2013.m
%> @brief see create_noise.m documentation
%> 
%> Rename file create_noise dot m or dot p as applicable to apply 2013
%> standards for percent error & absolute error & threshold of application 
%> 
%> module does not apply the 2013 Parkes Error Grid analysis requirement
%> 
%> struttura.noise.SMBG.thresh = 100; % ISO 15197:2013
%> 
%> struttura.noise.SMBG.percent_error=0.15;  % 15% BG >= 100 mg/dL
%> 
%> struttura.noise.SMBG.absolute_error=15;  % 15 mg/dL BG <= 100 mg/dL 
%> 
%> @copyright 2008-2013 University of Virginia.
%> @copyright 2013 The Epsilon Group, An Alere Company. 

function struttura=create_noise(struttura,scenario,hardware)
path_root=[cd filesep 'controller setup'];
path_root=[cd 'scenario'];
path_root=[cd '..'];
addpath(path_root )

struttura.noise.CGM=[];
struttura.noise.CGM=[(0:scenario.Tsimul)' zeros(size((0:scenario.Tsimul)'))];
struttura.noise_switch=1;

% create a normally distributed AR(1) time series with noise mean 0 and variance 1
v=randn(floor(scenario.Tsimul/15),1);
e(1)=v(1);
for i=2:scenario.Tsimul/15
    e(i)=hardware.sensor_PACF*v(i)+hardware.sensor_PACF*e(i-1);
end

% transform the standard normally distributed TS to obtain proper sensor
% noise distribution using Johnson family of distributions.
struttura.noise.CGM(:,2)=smooth(interp1(0:15:(length(e)-1)*15,moving_average(hardware.sensor_type,...
    hardware.sensor_gamma,hardware.sensor_delta,hardware.sensor_lambda,hardware.sensor_xi,e),...
    0:scenario.Tsimul,'linear','extrap'),7); 

% NOTE- Re-Name this file create_noise.m to use 2013 SMBG ISO Standards
% Now, generate SMBG-similar noise. 
% A vector of uncorrelated standard normal variates, 
% along with a percent error, and absolute error. 
struttura.noise.SMBG.noise(:,1)=[0:scenario.Tsimul]';
struttura.noise.SMBG.noise(:,2)=randn(scenario.Tsimul+1,1);
struttura.noise.SMBG.thresh = 100; % ISO 15197:2013
struttura.noise.SMBG.percent_error=0.15;  % 15% BG >= 100 mg/dL
struttura.noise.SMBG.absolute_error=15;  % 15 mg/dL BG < 100 mg/dL  
