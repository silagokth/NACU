function [new_coeffs] = interpolate_sigmoid(input, partition, fl)
% LUT_SIGMOID: Derives Slope and Offset for Piece-Wise Linear approx. of Sigmoid 
%   INPUTS:
%   input: 
%   partition = set of partition points
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%   frac_len = number of fractional bits of fixed-point format
%   OUTPUTS:
%   new_coeffs = set of outputs, each one associated to a partition interval
%
%   For each partition interval, the function generates a range of offsets and slopes to explore and
%   identifies the combination yielding the lowest error for PWL implementation. The function gives
%   out the set of slopes and offsets associated to each interval

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

num_intervals = length(partition)-1; % Number of intervals

new_coeffs = zeros(num_intervals,2); % Initialize slope and offset coefficients
sigm = @(x) 1./(1+exp(-x)); % Sigmoid functions
deriv_sigm = @(x) exp(-x)./((1+exp(-x)).^2); % Sigmoid derivative
error_line = 0; % Initialize total error

% For each interval
for i=1:num_intervals
    % Identify active interval inside 'input'
    range = (input >= partition(i) & input < partition(i+1));
    % Last interval includes rightmost point
    if i == num_intervals
        range = (input >= partition(i) & input <= partition(i+1));
    end
    
    input_range_pos = input(range); % Extract positive interval
    input_range_neg = -fliplr(input_range_pos);  % Extract negative interval
    center_idx = floor(length(input_range_pos)/2); % Take central point inside active interval
    center_idx(center_idx == 0) = 1;
    output_range_pos = sigm(input_range_pos); % Compute Sigmoid on positive interval
    output_range_neg = sigm(input_range_neg); % Compute Sigmoid on negative interval

    center_deriv = deriv_sigm(input_range_pos(center_idx)); % Compute Sigmoid derivative on central point
    m_lower_bound = 2^(-fl)*round(center_deriv/(2^(-fl)))-5*2^(-fl); % Lower bound for slope range
    m_upper_bound = 2^(-fl)*round(center_deriv/(2^(-fl)))+5*2^(-fl); % Upper bound for slope range
    m_range = m_lower_bound:2^(-fl):m_upper_bound; % Generate range of slope values to explore

    q_bound = sigm(input_range_pos(center_idx));  % Compute Sigmoid on central point
    q_lower_bound = 2^(-fl)*round(q_bound/(2^(-fl)))-5*2^(-fl); % Lower bound for offset range
    q_upper_bound = 2^(-fl)*round(q_bound/(2^(-fl)))+5*2^(-fl); % Upper bound for offset range
    q_range = q_lower_bound:2^(-fl):q_upper_bound; % Generate range of offset values to explore
    best_error = realmax; % Initialize error to max representable value
    
    % For each offset value inside the offset range
    for j = 1:length(q_range)

        error = zeros(1,length(m_range)); % Initialize errors for slope range
        
        % For each slope value inside the slope range
        for k=1:length(m_range)
            % Adjust offset to center line on 'center_idx'
            q = q_range(j) - m_range(k)*input_range_pos(center_idx); 
            q = 2^(-fl)*round(q/2^(-fl));
            
            % Generate PWL sigmoid output on positive interval
            test_output_pos = m_range(k)*input_range_pos + q;
            test_output_pos = 2^(-fl)*floor(test_output_pos/2^(-fl));
            % Generate PWL sigmoid output on negative interval
            test_output_neg = m_range(k)*input_range_neg +1-q;  
            test_output_neg = 2^(-fl)*floor(test_output_neg/2^(-fl));
            % Compute total error on both positive and negative intervals
            error(k) = sum(abs(test_output_pos-output_range_pos)) + sum(abs(test_output_neg-output_range_neg)); 
        end
        % Identify slope and offset which give minimum error
        [min_error_k, min_err_idx] = min(error);

        % If a new minimum for error was found
        if(min_error_k <= best_error)
            % Update minimum error and best values for slope and offset
            best_error = error(min_err_idx);
            best_m = m_range(min_err_idx);
            best_q = q_range(j) - best_m*input_range_pos(center_idx);
            best_q = 2^(-fl)*round(best_q/2^(-fl));
        end
    end

    % Save best slope and offsets
    new_coeffs(i,1) = best_m;
    new_coeffs(i,2) = best_q;

    error_line = error_line + best_error;
end % for i=1:num_intervals

end

