%% Find_opt_sigmoid: Explores LUT, RALUT, Uniform PWL and Non-uniform PWL for Sigmoid
%
%   The script builds LUT, RALUT, Uniform PWL and Non-uniform PWL implem. for Sigmoid,
%   for selectable ranges of fractional bits 'fl' and partition intervals 'ni'.
%   In the first part, the script allows to choose one implementation type, then implements 
%   sigmoid for all 'fl' and all 'ni' in selected ranges. The results are sets of LUT entries 
%   for each 'fl' and 'ni', that are saved in a '.mat' workspace.
%   In the second part, the script loads the workspace and searches the implem. with optimal
%   'ni', for each 'fl'. The optimal sigmoid implem. are all saved into another '.mat' workspace
%   
%   MAIN PARAMETERS
%   fl_start = lower bound of fractional bits 'fl' to explore
%   fl_end = upper bound of fractional bits 'fl' to explore
%   ni_start = 2^(ni_start) is the lower bound of number of intervals 'ni' to explore
%   ni_end = 2^(ni_end) is the upper bound of number of intervals 'ni' to explore
%   ['number of interval' values are only powers of 2 from 2^(ni_start) to 2^(ni_end)]
%   lut_ralut_n = '1' for uniform partition, '0' for non-uniform partition
%   use_pwl = '0'for LUT (only offset), '1' for PWL (offset and slope)
%   compcoeff_compopt_n = '1' to compute selected implementation for all chosen 'fl' and 'ni'
%                         '0' to take results from compcoeff_compopt_n='1' and find the optimal 'ni' for each 'fl'
%


%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
%                                                                         #
%This file is part of SiLago.                                             #
%                                                                         #
%    SiLago platform source code is distributed freely: you can           #
%    redistribute it and/or modify it under the terms of the GNU          #
%    General Public License as published by the Free Software Foundation, #
%    either version 3 of the License, or (at your option) any             #
%    later version.                                                       #
%                                                                         #
%    SiLago is distributed in the hope that it will be useful,            #
%    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
%    GNU General Public License for more details.                         #
%                                                                         #
%    You should have received a copy of the GNU General Public License    #
%    along with SiLago.  If not, see <https://www.gnu.org/licenses/>.     #
%                                                                         #
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

clear variables
close all
clc

savepath = ('./');

compcoeff_compopt_n = 1;
lut_ralut_n = 0;
use_pwl = 1;

if compcoeff_compopt_n
%%

wl = 16; % Bitwidth
    
fl_start = 0; % Number of fractional bits
fl_end = 11;

ni_start = 2; % 2^ni = number of intervals
ni_end = 9;
 
% Initialize variables to store sigmoid curves as function of fl
new_coeffs_fl = cell(fl_end-fl_start+1, 1);
sigm_li_fl = cell(fl_end-fl_start+1, 1);
sigm_q_matlab_fl = cell(fl_end-fl_start+1, 1);
input_fl = cell(fl_end-fl_start+1, 1);

% Initialize error variables
avg_error_interp = zeros(fl_end-fl_start+1,ni_end-ni_start+1);
max_error_interp = zeros(fl_end-fl_start+1,ni_end-ni_start+1);
avg_rel_error_interp = zeros(fl_end-fl_start+1,ni_end-ni_start+1);
max_avg_rel_error_interp = zeros(fl_end-fl_start+1,ni_end-ni_start+1);

% Initialize partition variables
partitions = cell(fl_end-fl_start+1,ni_end-ni_start+1);
partition_steps = zeros(fl_end-fl_start+1,ni_end-ni_start+1);

% For each number of fractional bits inside the range
for fl=fl_start:fl_end 
    
    min_num = -2^(wl-fl-1); % Minimum number that can be represented in fixed-point
    max_num = 2^(wl-fl-1) - 2^(-fl); % Maximum number that can be represented in fixed-point
    input = min_num:2^(-fl):max_num; % Quantized input in fixed-point format

    input_fl{fl-fl_start+1} = input; % Save input for current 'fl' value
    
    sigm = @(x) 1./(1+exp(-x)); % Sigmoid function
    deriv_sigm = @(x) exp(-x)./((1+exp(-x)).^2); % Sigmoid derivative function

    sigmoid = sigm(input); % Sigmoid evaluated on quantized input vector
    sigmoid_q = fixed_point(sigmoid, wl,fl); % Quantized Sigmoid 
    sigm_q_matlab_fl{fl-fl_start+1} = sigmoid_q; % Save Quantized Sigmoid
    
    % Initialize variables to store sigmoid curves as function of ni
    new_coeffs_ni = cell(ni_start-ni_end+1,1);
    sigm_li_ni = cell(ni_start-ni_end+1,1);
    
    % For each number of intervals 'ni'
    for ni=ni_start:ni_end
     %% Compute Sigmoid implementations
        num_intervals = 2^(ni);
        
        % uniform LUT case
        if lut_ralut_n == 1
            % Generate uniform partition
            interval = fixed_point(max_num/num_intervals, wl, fl);
            partition = 0:interval:max_num;

            if length(partition) < num_intervals+1
                partition = [partition max_num];
            end
            
            % Uniform PWL case
            if use_pwl == 1
                % Get slopes and offsets for PWL interpolation
                new_coeffs = interpolate_sigmoid(input, partition, fl);
            else % simple LUT case
                % Set slopes to zero and get offsets for LUT implementation
                new_coeffs = zeros(num_intervals,2);
                best_q = lut_sigmoid(partition, wl, fl);
                new_coeffs(:,2) = best_q;
            end
        else % Non-uniform LUT case
            
            % Non-Uniform PWL case
            if use_pwl == 1
                % Get slopes and offsets for Non-Uniform PWL implementation 
                [partition, new_coeffs] = adaptive_1D_partition_pwl(wl, fl, num_intervals);
            else
                % Set slopes to zero and get offsets for RALUT implementation
                partition = adaptive_1D_partition(wl, fl, num_intervals);
                new_coeffs = zeros(num_intervals,2);
                new_coeffs(:,2) = lut_sigmoid(partition, wl, fl);
            end
        end
        
        partitions{fl-fl_start+1}{ni-ni_start+1} = partition; % Save partition

        %% Build Sigmoid curves
        
        n_intervals = length(partition)-1; 
        sigm_linear_interp = [];
        for i=1:n_intervals
            range_pos = (input >= partition(i) & input < partition(i+1));
            if i == n_intervals
            range_pos = (input >= partition(i) & input <= partition(i+1));
            end
            input_range_pos = input(range_pos);
            input_range_neg = -fliplr(input_range_pos);
            if i == 1
                input_range_neg(end) = [];
            elseif i == n_intervals
                input_range_neg = [min_num input_range_neg];
            end

            y_pos = fixed_point_floor(new_coeffs(i,1)*input_range_pos + new_coeffs(i,2), fl);
            y_neg = fixed_point_floor(new_coeffs(i,1)*input_range_neg + 1-new_coeffs(i,2), fl);
            sigm_linear_interp = [y_neg sigm_linear_interp y_pos];
        end

        % Assign new results to cells
        new_coeffs_ni{ni-ni_start+1} = new_coeffs;
        sigm_li_ni{ni-ni_start+1} = sigm_linear_interp;
        
        % Compute errors
        error_interp = abs(sigm_linear_interp-sigmoid);
        avg_error_interp(fl-fl_start+1,ni-ni_start+1) = sum(error_interp)./length(error_interp);
        max_error_interp(fl-fl_start+1,ni-ni_start+1) = max(error_interp);
        rel_error_interp = 100*error_interp./sigmoid;
        avg_rel_error_interp(fl-fl_start+1,ni-ni_start+1) = sum(rel_error_interp)./length(rel_error_interp);
        max_avg_rel_error_interp(fl-fl_start+1,ni-ni_start+1) = max(rel_error_interp);
    
    end % for ni=ni_start:ni_end
    % Assign 'ni' cells to 'fl' cells
    new_coeffs_fl{fl-fl_start+1} = new_coeffs_ni;
    sigm_li_fl{fl-fl_start+1} = sigm_li_ni;
end % for fl=fl_start:fl_end 

    % Save variables to use for mode compcoeff_compopt_n = '0'
    if lut_ralut_n == 1
        if use_pwl == 1
        save('li_lut_changeQ.mat', 'wl', 'fl_start', 'fl_end', 'ni_start', 'ni_end', 'new_coeffs_fl', 'sigm_li_fl', 'sigm_q_matlab_fl', ...
             'input_fl', 'avg_error_interp', 'max_error_interp', 'avg_rel_error_interp', 'max_avg_rel_error_interp', 'partitions');
        else
        save('lut_changeQ.mat', 'wl', 'fl_start', 'fl_end', 'ni_start', 'ni_end', 'new_coeffs_fl', 'sigm_li_fl', 'sigm_q_matlab_fl', ...
             'input_fl', 'avg_error_interp', 'max_error_interp', 'avg_rel_error_interp', 'max_avg_rel_error_interp', 'partitions');
        end
    else
        if use_pwl == 1
        save('li_ralut_changeQ2.mat', 'wl', 'fl_start', 'fl_end', 'ni_start', 'ni_end', 'new_coeffs_fl', 'sigm_li_fl', 'sigm_q_matlab_fl', ...
             'input_fl', 'avg_error_interp', 'max_error_interp', 'avg_rel_error_interp', 'max_avg_rel_error_interp', 'partitions');
        else
        save('ralut_changeQ.mat', 'wl', 'fl_start', 'fl_end', 'ni_start', 'ni_end', 'new_coeffs_fl', 'sigm_li_fl', 'sigm_q_matlab_fl', ...
             'input_fl', 'avg_error_interp', 'max_error_interp', 'avg_rel_error_interp', 'max_avg_rel_error_interp', 'partitions');            
        end
    end

else % compcoeff_compopt_n = 0    
    
    sigm = @(x) 1./(1+exp(-x)); % Sigmoid function

    % Load results from mode compcoeff_compopt_n = 1
    if lut_ralut_n == 1
        if use_pwl == 1
            load('li_lut_changeQ.mat');
        else
            load('lut_changeQ.mat');
        end
    else
        if use_pwl == 1
            load('li_ralut_changeQ2.mat');
        else
            load('ralut_changeQ.mat');
        end
    end
    
    % Initialize optimal parameters for each fl
    new_coeffs_opt = cell(fl_end-fl_start+1,1);
    partition_step_opt = zeros(fl_end-fl_start+1,1);
    partition_opt = cell(fl_end-fl_start+1,1);
    max_error_opt = zeros(fl_end-fl_start+1,1);
    sigm_li_fl_opt = cell(fl_end-fl_start+1,1);
    tanh_li_fl_opt = cell(fl_end-fl_start+1,1);
    exp_li_fl_opt = cell(fl_end-fl_start+1,1);
    
    opt_fig_merit = zeros(fl_end-fl_start+1,1);
    
    fl_vect = fl_start:1:fl_end;
    ni_vect = 2.^(ni_start:1:ni_end);
    
    % Compute number of unique values in slopes and offsets
    num_entries = zeros(fl_end-fl_start+1, ni_end-ni_start+1);
    for fl=fl_start:fl_end
        fl_eff = fl-fl_start+1;
        for ni=ni_start:ni_end
            ni_eff=ni-ni_start+1;
            new_coeffs_tmp = new_coeffs_fl{fl_eff}{ni_eff};
            num_entries(fl_eff,ni_eff) = length(unique(new_coeffs_tmp(:,1))) + length(unique(new_coeffs_tmp(:,2)));
        end
    end
    
    num_entries_opt = zeros(fl_end-fl_start+1,1); % Initialize vector of optimal number of entries 
    
    % For each number of fractional bits inside range
    for fl=fl_start:fl_end
        
        max_num = 2^(wl-fl-1)-2^(-fl); % Maximum number that can be represented in fixed-point
        
        fl_eff = fl-fl_start+1; % fl index 
        
        % Extract variables for 'fl' value
        max_error_tmp = max_error_interp(fl_eff,:); 
        avg_error_tmp = avg_error_interp(fl_eff,:);
        num_entries_tmp = num_entries(fl_eff,:);
        
        % Compute trade-off between max error and number of entries
        max_error_norm = max_error_tmp/max(max_error_tmp);
        num_entries_norm = num_entries_tmp/max(num_entries_tmp);
        fig_merit = max_error_norm.*num_entries_norm;

        % Find minimum of figure of merit = optimal 'ni'
        [~, opt_idx] = min(fig_merit);
        
        % Save minimum of figure of merit
        opt_fig_merit(fl_eff) = max_error_tmp(opt_idx)*num_entries_tmp(opt_idx);
        opt_idx_vect(fl_eff) = opt_idx;
        
        % Save optimal parameters for 'fl'
        new_coeffs_opt{fl_eff} = new_coeffs_fl{fl_eff}{opt_idx};
        num_entries_opt(fl_eff) = num_entries(fl_eff,opt_idx);
        partition_opt{fl_eff} = partitions{fl_eff}{opt_idx};
        max_error_opt(fl_eff) = max_error_tmp(opt_idx);
        avg_error_opt(fl_eff) = avg_error_tmp(opt_idx);
        sigm_li_fl_opt{fl_eff} = sigm_li_fl{fl_eff}{opt_idx};
        
        % Generate Tanh from sigmoid
        tanh_li_fl_opt{fl_eff} = create_tanh_from_sigm(new_coeffs_opt{fl_eff}, input_fl{fl_eff}, partition_opt{fl_eff}, wl, fl);
        % Generate Exponential from sigmoid
        exp_li_fl_opt{fl_eff} = create_exp_from_sigm(sigm_li_fl_opt{fl_eff}, wl, fl);
    end

    % Save optimal sigmoid, tanh and exp curves for each 'fl' inside range
    if lut_ralut_n == 1
        save('sigm_linear_interp_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'new_coeffs_opt', 'sigm_li_fl_opt');
        save('tanh_linear_interp_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'tanh_li_fl_opt');
        save('exp_linear_interp_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'exp_li_fl_opt');
    else
        save('sigm_linear_interp_ralut_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'new_coeffs_opt', 'sigm_li_fl_opt');
        save('tanh_linear_interp_ralut_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'tanh_li_fl_opt');
        save('exp_linear_interp_ralut_fl.mat', 'wl', 'fl_start', 'fl_end', 'input_fl', 'partition_opt', 'partition_step_opt', 'exp_li_fl_opt');
    end
end
