function [output] = fixed_point(input, nb, frac_len)
% FIXED_POINT_FLOOR: Quantizes real numbers on fixed-point with rounding-to-nearest and saturation
%   INPUTS:
%   input = number to discretize
%   nb = bitwidth
%   frac_len = number of fractional bits of fixed-point format

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

output = sfi(input, nb, frac_len);
output = double(output);
end

