function [best_q] = lut_sigmoid(partition, wl, fl)
% LUT_SIGMOID: Derives Sigmoid LUT from uniform partition on fixed-point format 
%   INPUTS:
%   partition = set of partition points
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%   fl_end = biggest fl considered 
%   frac_len = number of fractional bits of fixed-point format
%   OUTPUTS:
%   best_q = set of outputs, each one associated to a partition interval
%
%   For each partition interval, the function generates a range of offsets to explore and
%   identifies the value yielding the lowest error for LUT. The function gives
%   out the set of offsets associated to each interval

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

min_num = -2^(wl-fl-1); % Minimum number that can be represented in fixed-point
max_num = 2^(wl-fl-1) - 2^(-fl); % Maximum number that can be represented in fixed-point
input = min_num:2^(-fl):max_num; % Quantized input in fixed-point format
    
sigm = @(x) 1./(1+exp(-x)); % Sigmoid function

Ni = length(partition)-1; % Number of intervals
mult_factor = 10; % Number of points to evaluate around the central offset
best_q = zeros(Ni,1); % Initialize output

% For each interval
for i=1:Ni
    % Identify active interval inside 'input'
    range = (input >= partition(i) & input < partition(i+1));
    % Last interval includes rightmost point
    if i == Ni
        range = (input >= partition(i) & input <= partition(i+1));
    end
    
    input_range_pos = input(range); % Extract positive interval
    input_range_neg = -fliplr(input_range_pos); % Extract negative interval
    center_idx = floor(length(input_range_pos)/2); % Take central point inside active interval
    center_idx(center_idx == 0) = 1;
    output_range_pos = sigm(input_range_pos); % Compute Sigmoid on positive interval
    output_range_neg = sigm(input_range_neg); % Compute Sigmoid on negative interval

    q_bound = sigm(input_range_pos(center_idx)); % Compute Sigmoid on central point
    % Generate range of offsets to explore around the central output
    q_range =  fixed_point_floor(q_bound-2^(-fl)*floor(mult_factor/2), fl):2^(-fl):fixed_point_floor(q_bound+2^(-fl)*floor(mult_factor/2),fl);

    error = zeros(1,length(q_range)); % Initialize error vector

    % For each offset value inside the offset range
    for j=1:length(q_range)
        test_output_pos = q_range(j)*ones(1,length(input_range_pos)); % Generate LUT sigmoid output on positive interval
        test_output_neg = (1-q_range(j))*ones(1,length(input_range_neg)); % Generate LUT sigmoid output on negative interval
        error(j) = sum(abs(test_output_pos-output_range_pos)) + sum(abs(test_output_neg-output_range_neg)); % Compute total error over both intervals
    end

    % Identify offset which gives minimum error
    [~, min_err_idx] = min(error);
    % Take best offset
    best_q(i) = q_range(min_err_idx);

end

end
