# T1DMS contoller 분석 2021-01-04 

* contoller 호출 순서
  1. simulator 호출 
  2. Run Simulation 버튼 클릭 -> run_Callback 호춯
  3. run_Callback에서 ctrlsetup 호출
<img src="https://github.com/jeajin/predict_blood_glucose/blob/main/img/ctrlsetup%ED%98%B8%EC%B6%9C.png" >
<pre>
<code>
function ctrller=ctrlsetup(Quest,hd,sc,ctrller,struttura)

% OPTIONAL add a name for auditing; can be checked in sim_results
% see data.ctrlsetup
% NOTE actual required filename is always ctrlsetup.m

%ctrller.ctrlname='Std_Controller_teg'; % user-specified 원본
ctrller.ctrlname='Testing_Std_Control'; % controller name
display(ctrller.ctrlname)
%[dataMetab]=run_metabolic_test(filename,struttura,scanario,hd,Quest)
% Adding path names may be required with complex control & functions
path_root=[cd '\controller setup'];
addpath(path_root) 
%%
try
%% Controller Dosing Algorithm Robustness Analysis Modifiers
% % user can use these parameters explore & evaluate response to stress
% NOT included in FDA master file

% SImult will apply for the entire Tsimul
ctrller.SImult=1; % modify SI, insulin sensitivity

% Mealmult will apply for the entire Tsimul
ctrller.Mealmult=1; % modify meal speed (<1=slower)

% test with mis-announcement of the meals amount in the controller
ctrller.meal_announce_modifier=[0 1]; % multiplicative time dependent modifier 
% modifier on meal_announce amount, set = 0 for no meal announcement 
% first column contains time (minutes) from which to apply the values in the second column

% ADD additive and/or multiplicative Bias to the CGM
ctrller.CGM_bias=[0 0]; % additive time dependent modifier on CGM signal, 
% first column contains time from which to apply the values in the second column
ctrller.CGM_bias_rel=[0 1]; % multiplicative time dependent modifier on CGM signal, 
% first column contains time from which to apply the values in the second column

%% write your ctrlsetup code below

%% ** 
%% Standard Controller
% Subject-Specific: Quest information available to the controller
%Optimal Basal, Optimal Carb Ratio, Max.BG.Drop/Unit Insulin
ctrller.basal=Quest.basal; % U/hr
ctrller.OB=Quest.OB;  % U/gCHO
ctrller.MD=Quest.MD;  % Maximum BG drop mg/dL per U insulin
ctrller.CR=Quest.OB; % Carb Ratio, gCHO/U insulin
ctrller.CF=Quest.MD;   % Correction Factor max BG drop/U insulin

ctrller.name=Quest.names; % subject name - determine adult, teen or child
ctrller.BW=Quest.weight; % subject weight, kg
ctrller.fastingBG=Quest.fastingBG; % subject fasting BG mg/dL w/basal

% Target & Threshhold values generally used w/correction bolus calculation
ctrller.corr_tgt=100; % set correction bolus target mg/dL
ctrller.corr_thresh=150; % set correction bolus threshhold mg/dL
ctrller.corr_CFmeal=0; % Correction Bolus w/Meal; =0 => off, =1 => 100%

catch e
    e.message
end
</code>
</pre>
  
  4. run_Callback으로 복귀 후 ctrlsetup의 반환값을 가지고 accross_output 호출
  
  accross_output(data,output,get(handles.saveastxt,'Value'));
