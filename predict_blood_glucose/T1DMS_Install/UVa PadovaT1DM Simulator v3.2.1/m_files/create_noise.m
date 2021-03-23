%> @file create_noise.m
%> @brief Creates streams of noise to be used in generating synthetic CGM and SMBG readings.
%> Noise is applied in the glucose sensor module in testing_platform.mdl
%>
%> -# First, it generates noise according to an AR(1) process, i.e., using the recursion
%> @f{eqnarray*}{
%> \varepsilon_i &=& \theta \left(\varepsilon_{i-1} + v_i\right),
%> @f}
%> where @f$\theta@f$ is the partial auto-correlation coefficient (PACF), and @f$v_i@f$ is a
%> standard normal variate (mean 0, variance 1).
%> The noise process is later transformed to the proper sensor noise distribution using the inverse of a 
%> Johnson transform by calling function @link Johnson_transform@endlink. 
%> The PACF and Johnson transform parameters were obtained by fitting blood glucose concentrations and the 
%> corresponding continuous glucose meter (CGM) measurements for real patients, and it is used to 
%> generate a synthetic CGM reading with statistical properties similar to an actual CGM, as 
%> shown in @cite Breton2008.
%> 
%> -# It generates uncorrelated normally distributed noise to be used when simulating SMBG readings.
%>
%> @copyright 2008-2013 University of Virginia.
%> @copyright 2013 The Epsilon Group, An Alere Company.

%> @param struttura Matlab structure to which the error model is appended.
%> @param scenario Matlab structure containing simulation scenario information. For more information on 
%> the contents of this structure, see @link scn_doc.m@endlink, but note that only the simulation time 
%> (<i>scenario.Tsimul</i>) is used. 
%> @param hardware Matlab structure containing PACF and Johnson transform parameters for the error process.
%> For more detail on the contents of this structure, see @link hardware_doc.m@endlink.
%> @return This code will append the <b>struttura</b> Matlab structure with the two noise process. 
%> The first appended element, <b>struttura.noise.CGM</b>, will contain the time and CGM sensor reading 
%> vectors as columns 1 and 2, respectively.
%> The second appended element, <b>struttura.noise.SMBG</b>, will contain a stream of independent 
%> standard normal variates and corresponding times in the two columns of <b>struttura.noise.SMBG.noise</b>. 
%> In addition, the structure will contain the 
%> standard deviation of the allowed error as a fraction (<b>struttura.noise.SMBG.percent_error</b>), or as an absolute value
%> (<b>struttura.noise.SMBG.absolute_error</b>.), and the value dividing the
%> application of percent error and absolute error 
%> ISO standard threshold (mg/dL)(<b>struttura.noise.SMBG.thresh</b>.) 

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
jt = Johnson_transform(hardware.sensor_type,...
    hardware.sensor_gamma,hardware.sensor_delta,hardware.sensor_lambda,hardware.sensor_xi,e);
% struttura.noise.CGM(:,2)=moving_average(interp1(0:15:(length(e)-1)*15,jt,0:scenario.Tsimul,'linear','extrap'),7); 
struttura.noise.CGM(:,2)=moving_average(interp1(0:15:(length(e)-1)*15,jt,0:scenario.Tsimul,'linear','extrap'),7); 

% NOTE- Re-Name this file create_noise.m to use 2003 SMBG ISO Standards
% Now, generate SMBG-similar noise. 
% A vector of uncorrelated standard normal variates, 
% along with a percent error, and absolute error. 
struttura.noise.SMBG.noise(:,1)=[0:scenario.Tsimul]';
struttura.noise.SMBG.noise(:,2)=randn(scenario.Tsimul+1,1);
struttura.noise.SMBG.thresh = 75; % ISO 15197:2003
struttura.noise.SMBG.percent_error=0.20;  % 20% BG >= 75 mg/dL
struttura.noise.SMBG.absolute_error=15;  % 15 mg/dL BG <= 75 mg/dL  
