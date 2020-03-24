function tanh_linear_interp = create_tanh_from_sigm(new_coeffs, input, partition, wl, fl)
% CREATE_TANH_FROM_SIGM: Uses sigmoid curve to build Tanh curve 
%   INPUTS:
%   new_coeffs = set of slopes and offsets for Sigmoid
%   input = Range of input values
%   partition = set of partition points
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%
%   OUTPUTS:
%   tanh_linear_interp = Tanh curve built from sigmoid
%
%   Tanh curve is directly built by adjusting slopes and offsets from sigmoid, according to equation
%   Tanh = 2Sigmoid(2x)-1

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
n_intervals = length(partition)-1; % Number of partition intervals

tanh_linear_interp = []; % Initialize Tanh curve

new_coeffs_tanh(:,1) = 2*new_coeffs(:,1); % for tahn, slope 'm' becomes '2*m'
new_coeffs_tanh(:,2) = 2*new_coeffs(:,2)-1; % for tanh, offset 'q' becomes '2*q-1'

input_tanh = 2*input; % Tanh = 2Sigmoid(2x)-1, so sigmoid input is mult. by 2

% Build Tanh curve from new Tanh coefficients
for i=1:n_intervals
    range_pos = (input_tanh >= partition(i) & input_tanh < partition(i+1));
    if i == n_intervals
    range_pos = (input_tanh >= partition(i) & input_tanh <= partition(i+1));
    end
    input_range_pos = input_tanh(range_pos);
    input_range_neg = -fliplr(input_range_pos);
    if i == 1
        input_range_neg(end) = [];
    elseif i == n_intervals
        input_range_neg = [min_num input_range_neg];
    end

    y_pos = fixed_point_floor(new_coeffs_tanh(i,1)*input_range_pos + new_coeffs_tanh(i,2), fl);
    y_neg = fixed_point_floor(new_coeffs_tanh(i,1)*input_range_neg - new_coeffs_tanh(i,2), fl);
    tanh_linear_interp = [y_neg tanh_linear_interp y_pos];
end

% Fill sides of Tanh with saturated values, only for formats that reach saturation
if fl <= 11
    range_pos = (input_tanh > partition(end));
    input_range_pos = input_tanh(range_pos);
    tanh_linear_interp = [-1*ones(1,length(input_range_pos)) tanh_linear_interp ones(1, length(input_range_pos))];
end

end

