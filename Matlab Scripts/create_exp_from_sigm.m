function [exp_lin_interp] = create_exp_from_sigm(sigm_linear_interp, wl, fl)
% CREATE_EXP_FROM_SIGM: Uses sigmoid curve to build Exponential curve 
%   INPUTS:
%   sigm_linear_interp = Full Sigmoid curve
%   wl = bitwidth
%   fl = number of fractional bits of fixed-point format
%
%   OUTPUTS:
%   exp_linear_interp = Tanh curve built from sigmoid
%
%   Exponential curve is directly built from sigmoid, Following equation
%   Exp = (1/Sigmoid(-x))-1

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

max_num = 2^(wl-fl-1) - 2^(-fl); % Maximum number that can be represented in fixed-point

% Flip sigmoid curve to obtain Sigmoid(-x)
sigm_for_exp = fliplr(sigm_linear_interp(2:end));
sigm_for_exp = [sigm_for_exp(1) sigm_for_exp];

exp_lin_interp = 1./(sigm_for_exp)-1; % Use Sigmoid(-x) inside equation to get Exponential
exp_lin_interp(exp_lin_interp > max_num) = max_num; % Saturate Exponential 
exp_lin_interp = 2^(-fl)*floor(exp_lin_interp/2^(-fl)); % Discretize exponential on fixed-point format with truncation
end

