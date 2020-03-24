function [partition] = adaptive_1D_partition(wl, fl, num_intervs)
%ADAPTIVE_1D_PARTITION Creates non-uniform partition for Sigmoid function
%   Function inputs:
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%   num_intervs = Desired number of partition intervals
%   
%   This algorithm creates a non-uniform input partition for a RALUT-based 
%   implementation of sigmoid function. The algorithm works on fixed-point
%   numbers with bitwidth 'wl' and fractional bits 'fl'. 'num_intervs'
%   selects the number of intervals. This algorithm works properly only for
%   monotonically increasing functions like sigmoid or hyperbolic tangent.


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

sigm = @(x) 1./(1+exp(-x)); % Sigmoid function

min_num = -2^(wl-fl-1); % Minimum number that can be represented in fixed-point
max_num = 2^(wl-fl-1) - 2^(-fl); % Maximum number that can be represented in fixed-point
input_sfi = (min_num:2^(-fl):max_num)'; % Quantized input in fixed-point format

error_type = 'sum'; % Type of cost function used to compute error
if strcmp(error_type, 'sum')
    err_f = @(x) sum(x); % Cost function is sum of errors
elseif strcmp(error_type, 'max')
    err_f = @(x) max(x); % Cost function is maximum error
end

lower_bound = 0; % Input interval starting point
upper_bound = max_num; % Input interval end point

input_AdPart= input_sfi((input_sfi >= lower_bound) & (input_sfi <= upper_bound)); % Selects input interval from 'input_sfi'
output = sigm(input_AdPart); % Computes 'sigm' on selected input interval

sigm_sat = 2^(-fl)*round(log(2^(fl+1)-1)/(2^(-fl))); % Saturation point for sigm

% If (num_intervs-1) intervals cannot be allocated in the space between lower_bound and sigm_sat
if sigm_sat < 2^(-fl)*(num_intervs-1) % case fl=0
    interval = upper_bound/num_intervs;
    sigm_sat = upper_bound-interval;
end

% Sets width of uniform intervals
% (num_intervs-1) is used because last interval is reserved to cover saturation of sigmoid
interval = (sigm_sat-lower_bound)/(num_intervs-1);

partition = lower_bound:interval:sigm_sat; % Creates starting uniform partition
partition = 2^(-fl)*floor(partition/(2^(-fl))); % Discretized uniform partition on fixed-point

% Rebuilds uniform partition after discretization, so that interval widths
% have increasing order
for i=2:length(partition); partition_widths(i-1) = partition(i)-partition(i-1);end
partition_widths = sort(partition_widths);
partition(1) = lower_bound;
for i=2:num_intervs-1
    partition(i) = partition(i-1)+partition_widths(i-1);
end
partition = [partition upper_bound];

test_sigm_output = zeros(length(partition)-1,1); % Sigmoid LUT values
test_sigm_for_error = zeros(length(input_AdPart),1); % Sigmoid LUT on input interval

% Computes Sigmoid LUT values and creates Sigmoid curve
for i=1:num_intervs
    test_sigm_output(i) = 0.5*(sigm(partition(i)) + sigm(partition(i+1)));
    test_sigm_output(i) = 2^(-fl)*round(test_sigm_output(i)/2^(-fl));
    test_sigm_for_error((input_AdPart >= partition(i)) & (input_AdPart < partition(i+1))) = test_sigm_output(i);
end
    
test_sigm_for_error(input_AdPart == partition(end)) = test_sigm_output(end); % Fixes final values
test_sigm_for_error(input_AdPart > partition(end)) = 1; % Fixes final values

tot_error = zeros(num_intervs,1); % Error for each algorithm step 
error_matlab_sigm = abs(test_sigm_for_error-output); % Error between LUT Sigmoid and Matlab Sigmoid
tot_error(end) = err_f(error_matlab_sigm); % Initial error
    
%% Plot initial uniform LUT
%{
partition_plot = min(output)*ones(length(partition),1);

figure
set(gca, 'FontSize', 18);
hold on
plot(input_AdPart,output, 'DisplayName', 'Matlab sigmoid');
%plot(input, output_sfi, 'DisplayName', 'Matlab quant. sigmoid', 'LineStyle', '--');
%ylim([0.7 1.1]);

a(1) = stairs(input_AdPart, test_sigm_for_error, 'DisplayName', 'Starting Partition Output', 'Color', 'red');
b(1) = scatter(partition, partition_plot, 'Marker', '+', 'LineWidth', 0.1, 'DisplayName', 'Partition');
%xlim([0.95 8]);

legend('show');
%}

min_part_width = 2^(-fl); % 1 LSB in fixed-point format
prev_tot_error = tot_error(end); % Initializes "error from previous step"
prev_part_width = upper_bound-sigm_sat; % Initializes "width of previous interval"

% For each interval from right to left and excluding the sigmoid saturation interval 
for iter=length(partition)-2:-1:2
        %% First, widen the active interval so that the two output levels are different
        
        flag = 0; % tells if active interval has been processed
        at_least_one_min = 0; % tells if total error has decreased at least once
        
        % Until total error on Sigmoid is decreasing
        while(flag == 0)
            
            new_min = 0; % tells if a new minimum for total error was found in this iteration
            partition(iter) = partition(iter)-min_part_width; % Decrease partition point by 1 LSB (increases active interval width by 1 LSB)
            % If next interval is wider than the minimum AND active interval is smaller than the
            % previous interval
            if((partition(iter)-partition(iter-1) >= min_part_width) && (partition(iter+1)-partition(iter) <= prev_part_width))
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
                for i=1:length(test_sigm_output)
                    test_sigm_output(i) = 0.5*(sigm(partition(i)) + sigm(partition(i+1)));
                    test_sigm_output(i) = 2^(-fl)*round(test_sigm_output(i)/2^(-fl));
                end
                
                % If Sigmoid LUT value for active interval is different than the previous
                % interval...
                if(test_sigm_output(iter-1) ~= test_sigm_output(iter)) 

                    % Reinitialize 'test_sigm_for_error'
                    test_sigm_for_error = zeros(length(input_AdPart),1);
                    for i=1:length(test_sigm_output)
                        test_sigm_for_error((input_AdPart >= partition(i)) & (input_AdPart < partition(i+1))) = test_sigm_output(i);
                    end  
                    test_sigm_for_error(end) = test_sigm_for_error(end-1);

                    % Evaluate error on new partition
                    error_matlab_sigm = abs(test_sigm_for_error-output);
                    tot_error(iter) = err_f(error_matlab_sigm);
                    
                    % If the total error is lower than previous iteration 
                     if (tot_error(iter) <= prev_tot_error) 
                        % The new partition is better than the previous one so it is saved
                        prev_tot_error = tot_error(iter);
                        at_least_one_min = 1;
                        new_min = 1;
                        restore_partition = partition;
                        restore_temp_sigm_output =  test_sigm_output;
                        restore_test_sigm_for_error = test_sigm_for_error;
                        restore_avg_error = tot_error(iter);
                     end
                     
                     % If the error has decreased at least once but now it has stopped decreasing
                     if(at_least_one_min == 1 && new_min == 0)
                        % Restore the previous valid partition and move to the next partition point
                        flag = 1;
                        partition = restore_partition;
                        prev_part_width = partition(iter+1)-partition(iter);
                        test_sigm_output = restore_temp_sigm_output;
                        test_sigm_for_error = restore_test_sigm_for_error;
                        tot_error(iter) = restore_avg_error;
                     end
                end % if(test_sigm_output(iter-1) ~= test_sigm_output(iter))            
            else 
                partition(iter) = partition(iter)+min_part_width; % Partition is invalid so it is restored to previous state
                flag = 1; % Stop processing active interval and move to next one
            end % if((partition(iter)-partition(iter-1) >= min_part_width) && (partition(iter+1)-partition(iter) <= prev_part_width))
        end % while(flag == 0)
end % for iter=length(partition)-2:-1:2

%% Debug: Final error evaluation
%{
test_sigm_for_error(end) = test_sigm_for_error(end-1);
partition = 2^(-fl)*round(partition/2^(-fl));

% Debug: Computes final partition widths
for i=2:length(partition)-1
    partition_widths(i) = partition(i)-partition(i-1);
end

for i=1:length(test_sigm_output)
    test_sigm_output(i) = 0.5*(sigm(partition(i)) + sigm(partition(i+1)));
    test_sigm_output(i) = 2^(-fl)*round(test_sigm_output(i)/2^(-fl));
    %prev_test_sigm_for_error = test_sigm_for_error(input_AdPart >= partition(iter));
    test_sigm_for_error((input_AdPart >= partition(i)) & (input_AdPart < partition(i+1))) = test_sigm_output(i);
end  
 test_sigm_for_error(end) = test_sigm_for_error(end-1);

error_matlab_sigm = abs(test_sigm_for_error-output);
avg_error_matlab_sigm = sum(error_matlab_sigm)/length(error_matlab_sigm);
max_error_matlab_sigm = max(error_matlab_sigm);
rel_error_matlab_sigm = error_matlab_sigm./(output);
final_avg_rel_error= 100*sum(rel_error_matlab_sigm)/length(rel_error_matlab_sigm);
%}

partition = partition';
end

