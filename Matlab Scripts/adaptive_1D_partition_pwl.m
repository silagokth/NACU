function [partition, best_coeffs] = adaptive_1D_partition_pwl(wl, fl, num_intervs)
%ADAPTIVE_1D_PARTITION_PWL Creates non-uniform partition for Piece-Wise Linear approx. of Sigmoid
%   Function inputs:
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%   num_intervs = Desired number of partition intervals
%   
%   This algorithm creates a non-uniform input partition for a Non-Uniform PWL
%   implementation of sigmoid function. The algorithm works on fixed-point
%   numbers with bitwidth 'wl' and fractional bits 'fl'. 'num_intervs'
%   selects the number of intervals. This algorithm works properly only for
%   monotonically increasing functions like sigmoid or hyperbolic tangent.

% Copyright (c) 2019

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

%% Initialization

sigm = @(x) 1./(1+exp(-x));

min_num = -2^(wl-fl-1); % Minimum number that can be represented in fixed-point
max_num = 2^(wl-fl-1) - 2^(-fl); % Maximum number that can be represented in fixed-point
input_sfi = (min_num:2^(-fl):max_num); % Quantized input in fixed-point format

error_type = 'sum'; % Type of cost function used to compute error
if strcmp(error_type, 'sum')
    err_f = @(x) sum(x); % Cost function is sum of errors
elseif strcmp(error_type, 'max')
    err_f = @(x) max(x); % Cost function is maximum error
end

lower_bound = 0; % Input interval starting point
upper_bound = max_num; % Input interval end point

input_AdPart= input_sfi((input_sfi >= lower_bound) & (input_sfi <= upper_bound)); % Selects input interval from 'input_sfi'
output = sigm(input_sfi); % Computes 'sigm' on selected input interval

sigm_sat = 2^(-fl)*round(log(2^(fl+1)-1)/(2^(-fl))); % Saturation point for sigm

% If (num_intervs-1) intervals cannot be allocated in the space between lower_bound and sigm_sat
if sigm_sat < 2^(-fl)*(num_intervs-1) % case fl=0
    interval = upper_bound/num_intervs;
    sigm_sat = upper_bound-interval;
end

% (num_intervs-1) is used because last interval is reserved to cover saturation of sigmoid
interval = (sigm_sat-lower_bound)/(num_intervs-1);
partition = lower_bound:interval:sigm_sat;
partition = 2^(-fl)*floor(partition/(2^(-fl)));

% Rebuilds uniform partition after discretization, so that interval widths
% have increasing order
for i=2:length(partition); partition_widths(i-1) = partition(i)-partition(i-1);end
partition_widths = sort(partition_widths);
partition(1) = lower_bound;
for i=2:num_intervs-1
    partition(i) = partition(i-1)+partition_widths(i-1);
end
partition = [partition upper_bound];

new_coeffs = interpolate_sigmoid(input_sfi, partition, fl); % Obtain slope and offset for Sigmoid PWL

% Build PWL interpolation of Sigmoid from slopes and offsets
n_intervals = length(partition)-1;
test_ref_function_for_error = [];
for i=1:n_intervals
    range_pos = (input_sfi >= partition(i) & input_sfi < partition(i+1));
    if i == n_intervals
    range_pos = (input_sfi >= partition(i) & input_sfi <= partition(i+1));
    end
    input_range_pos = input_sfi(range_pos);
    input_range_neg = -fliplr(input_range_pos);
    if i == 1
        input_range_neg(end) = [];
    elseif i == n_intervals
        input_range_neg = [min_num input_range_neg];
    end
    y_pos = fixed_point_floor(new_coeffs(i,1)*input_range_pos + new_coeffs(i,2), fl);
    y_neg = fixed_point_floor(new_coeffs(i,1)*input_range_neg + 1-new_coeffs(i,2), fl);
    test_ref_function_for_error = [y_neg test_ref_function_for_error y_pos];
end

tot_error = zeros(num_intervs,1); % Error for each algorithm step
error_matlab_ref_function = abs(test_ref_function_for_error-output); % Error between PWL Sigmoid and Matlab Sigmoid
tot_error(end) = err_f(error_matlab_ref_function); % Initial error

%% Plot initial uniform PWL
%{
figure
set(gca, 'FontSize', 18);
hold on
plot(input_AdPart,output, 'DisplayName', 'Matlab ref_functionoid');
%plot(input, output_sfi, 'DisplayName', 'Matlab quant. ref_functionoid', 'LineStyle', '--');
%ylim([0.7 1.1]);

a(1) = stairs(input_AdPart, test_ref_function_for_error, 'DisplayName', 'Starting Partition Output', 'Color', 'red');
b(1) = scatter(partition, partition_plot, 'Marker', '+', 'LineWidth', 0.1, 'DisplayName', 'Partition');
%xlim([0.95 8]);

legend('show');

%}

min_part_width = 2^(-fl); % 1 LSB in fixed-point format

% Sets interval width increase step 
if fl < 10
    part_step = 2^(-fl);
else
    part_step = 2^(-fl+1);
end
prev_tot_error = tot_error(end); % Initializes "error from previous step"
prev_part_width = upper_bound-sigm_sat; % Initializes "width of previous interval"

best_coeffs = new_coeffs; % Best PWL coefficients

% For each interval from right to left and excluding the sigmoid saturation interval 
for iter=length(partition)-2:-1:2
        %% First, widen the active interval so that the two output levels are different
        
        flag = 0; % tells if active interval has been processed
        at_least_one_min = 0; % tells if total error has decreased at least once
        prev_test_ref_function_output = 1+2^(-fl); % Initialization
        
        % Until total error on Sigmoid is decreasing
        while(flag == 0)
                
            new_min = 0; % tells if a new minimum for total error was found in this iteration
            partition(iter) = partition(iter)-part_step; % Decrease partition point by 1 LSB
            
            % If next interval is wider than the minimum AND active interval is smaller than the
            % previous interval
            if ((partition(iter)-partition(iter-1) >= min_part_width) && (partition(iter+1)-partition(iter) <= prev_part_width))
                % Build new uniform partition for points [1,iter]
                new_upper_bound = partition(iter);
                new_interval = (new_upper_bound-lower_bound)/(iter-1);
                partition(1:iter) = lower_bound:new_interval:new_upper_bound;
                partition(1:iter) = 2^(-fl)*floor(partition(1:iter)/(2^(-fl)));
                partition_widths = sort(gradient(partition(1:iter)));
                partition(1) = lower_bound;
                for i=2:iter-1
                    partition(i) = partition(i-1)+partition_widths(i-1);
                end
                partition(iter) = new_upper_bound;

                % Evaluate sigmoid on the new non uniform partition
                new_coeffs = interpolate_sigmoid(input_sfi, partition, fl);
                n_intervals = length(partition)-1;
                test_ref_function_for_error = [];
                for i=1:n_intervals
                    range_pos = (input_sfi >= partition(i) & input_sfi < partition(i+1));
                    if i == n_intervals
                    range_pos = (input_sfi >= partition(i) & input_sfi <= partition(i+1));
                    end
                    input_range_pos = input_sfi(range_pos);
                    input_range_neg = -fliplr(input_range_pos);
                    if i == 1
                        input_range_neg(end) = [];
                    elseif i == n_intervals
                        input_range_neg = [min_num input_range_neg];
                    end

                    y_pos = fixed_point_floor(new_coeffs(i,1)*input_range_pos + new_coeffs(i,2), fl);
                    y_neg = fixed_point_floor(new_coeffs(i,1)*input_range_neg + 1-new_coeffs(i,2), fl);
                    test_ref_function_for_error = [y_neg test_ref_function_for_error y_pos];
                end
                
                % Evaluate error on new partition
                error_matlab_ref_function = abs(test_ref_function_for_error-output);
                tot_error(iter) = err_f(error_matlab_ref_function);

                % If the total error is lower than previous iteration 
                 if (tot_error(iter) <= prev_tot_error) 
                    % The new partition is better than the previous one so it is saved
                    prev_tot_error = tot_error(iter);
                    best_coeffs = new_coeffs;
                    at_least_one_min = 1;
                    new_min = 1;
                    restore_partition = partition;
                    restore_test_ref_function_for_error = test_ref_function_for_error;
                    restore_avg_error = tot_error(iter);
                 end

                 % If the error has decreased at least once but now it has stopped decreasing
                 if(at_least_one_min == 1 && new_min == 0)
                    % Restore the previous valid partition and move to the next partition point
                    flag = 1;
                    partition = restore_partition;
                    prev_part_width = partition(iter+1)-partition(iter);
                    test_ref_function_for_error = restore_test_ref_function_for_error;
                    tot_error(iter) = restore_avg_error;
                 end               
            else
                partition(iter) = partition(iter)+part_step; % Partition is invalid so it is restored to previous state
                flag = 1; % Stop processing active interval and move to next one
            end % ((partition(iter)-partition(iter-1) >= min_part_width) && (partition(iter+1)-partition(iter) <= prev_part_width))
        end % while(flag == 0)
end % iter=length(partition)-2:-1:2
    
%% Debug: Final error evaluation
%{
for i=2:length(partition)-1
    partition_widths(i) = partition(i)-partition(i-1);
end

n_intervals = length(partition)-1;
test_ref_function_for_error = [];

for i=1:n_intervals
    range_pos = (input_sfi >= partition(i) & input_sfi < partition(i+1));
    if i == n_intervals
    range_pos = (input_sfi >= partition(i) & input_sfi <= partition(i+1));
    end
    input_range_pos = input_sfi(range_pos);
    input_range_neg = -fliplr(input_range_pos);
    if i == 1
        input_range_neg(end) = [];
    elseif i == n_intervals
        input_range_neg = [min_num input_range_neg];
    end

    y_pos = fixed_point_floor(best_coeffs(i,1)*input_range_pos + best_coeffs(i,2), fl);
    y_neg = fixed_point_floor(best_coeffs(i,1)*input_range_neg + 1-best_coeffs(i,2), fl);
    test_ref_function_for_error = [y_neg test_ref_function_for_error y_pos];
end
                    
 error_matlab_ref_function = abs(test_ref_function_for_error-output);
 avg_error_matlab_ref_function = sum(error_matlab_ref_function)/length(error_matlab_ref_function);
 max_error_matlab_ref_function = max(error_matlab_ref_function);
 rel_error_matlab_ref_function = error_matlab_ref_function./(output);
 final_avg_rel_error= 100*sum(rel_error_matlab_ref_function)/length(rel_error_matlab_ref_function);

test_ref_function_for_error = test_ref_function_for_error';
%}

partition = partition';

end

