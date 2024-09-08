%> @file ctrlsetup_MetabTest.m
%> @brief An example of a ctlsetup.m file that might be used in conjunction with the use of <b>Metabolic Testing</b>
%> @par This file is provided as a reference for the user
function ctrller=ctrlsetup(Quest,hd,sc,ctrller,struttura)

% OPTIONAL add a name for auditing; can be checked in sim results file
% NOTE actual required filename is always ctrlsetup.m
ctrller.ctrlname='Add_Metabolic_Testing';
%[dataMetab]=run_metabolic_test(filename,struttura,scanario,hd,Quest)
%%  Metabolic Testing
%% 
% Adding path names may be required with complex control & functions
path_root=[cd '\controller setup'];
addpath(path_root) 
%%
try
%%robustness analysis modifiers
ctrller.SImult=1; %modify SI
ctrller.Mealmult=1; %modify meal speed (<1=slower)
ctrller.meal_announce_modifier=[0 1]; %multiplicative time dependent modifier 
%on meal_announce amount, to miss-announce a meal set at 0; 
% first column contains time from which to apply the values in the second column

ctrller.CGM_bias=[0 0]; %additive time dependent modifier on CGM signal, 
% first column contains time from which to apply the values in the second column

ctrller.CGM_bias_rel=[0 1]; %multiplicative time dependent modifier on CGM signal, 
% first column contains time from which to apply the values in the second column

%% write your code below

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

%% Metabolic Testing Example
% => this example specifies a scenario in scenario folder named metabolic_test.scn
[dataMetab] = run_metabolic_test('metabolic_test.scn',struttura,sc,hd,Quest); 
% The following example is for Define Metabolic Test, 'select_metab_meas'
% Plasma glucose, Plasma insulin & SQ glucose selected !!!
Time = dataMetab(1,3).time;
CkGlucose = dataMetab(1,1).value;  % plasma glucose
CkInsulin = dataMetab(1,2).value;  % plasma insulin
SQGlucose = dataMetab(1,3).value;  % CGM sensor value
min(CkInsulin)
min(CkGlucose)
min(SQGlucose)
if min(CkGlucose)<100  % example, modify basal using dataMetab
    ctrller.basal=Quest.basal/2;
end
% save dataMetab dataMetab  % save dataMetab beta test
%%
catch e
    e.message
end

