-------------------------------------------------------
--! @file mac_pkg.vhd
--! @brief Package for MAC
--! @details Package file with MAC unit behavior model for NACU testbench
--! @author Guido Baccelli
--! @version 1.1
--! @date 23/08/2019
--! @bug NONE
--! @todo NONE
--! @copyright  GNU Public License [GPL-3.0].
-------------------------------------------------------
---------------- Copyright (c) notice -----------------------------------------
--
-- The VHDL code, the logic and concepts described in this file constitute
-- the intellectual property of the authors listed below, who are affiliated
-- to KTH(Kungliga Tekniska Högskolan), School of ICT, Kista.
-- Any unauthorised use, copy or distribution is strictly prohibited.
-- Any authorised use, copy or distribution should carry this copyright notice
-- unaltered.
-------------------------------------------------------------------------------
-- Title      : Package for MAC
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : mac_pkg.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 23/08/2019
-- Last update: 2020-03-15
-- Platform   : SiLago
-- Standard   : VHDL'08
-- Supervisor : Dimitrios Stathis
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Contact    : Dimitrios Stathis <stathis@kth.se>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 23/08/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Prepare for git and Clean-up
-------------------------------------------------------------------------------

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
--                                                                         #
--This file is part of SiLago.                                             #
--                                                                         #
--    SiLago platform source code is distributed freely: you can           #
--    redistribute it and/or modify it under the terms of the GNU          #
--    General Public License as published by the Free Software Foundation, #
--    either version 3 of the License, or (at your option) any             #
--    later version.                                                       #
--                                                                         #
--    SiLago is distributed in the hope that it will be useful,            #
--    but WITHOUT ANY WARRANTY; without even the implied warranty of       #
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
--    GNU General Public License for more details.                         #
--                                                                         #
--    You should have received a copy of the GNU General Public License    #
--    along with SiLago.  If not, see <https://www.gnu.org/licenses/>.     #
--                                                                         #
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

--! Standard ieee library
LIBRARY ieee;
--! Default working library
LIBRARY work;
--! Standard logic package
USE ieee.std_logic_1164.ALL;
--! Standard numeric package for signed and unsigned
USE ieee.numeric_std.ALL;
--! Package for math with real numbers
USE ieee.math_real.ALL;
--! Package with ann_unit types and constants
USE work.ann_pkg.ALL;

--! Package file with MAC behavior model for testbench

--! The only content is the 'mac_int' function that emulates behavior of MAC operation inside 'NACU'
PACKAGE mac_pkg IS

    FUNCTION mac_int(
        a     : INTEGER;
        b     : INTEGER;
        acc   : INTEGER;
        nbits : INTEGER;
        frac  : INTEGER
    ) RETURN INTEGER;

END PACKAGE mac_pkg;

--! @brief Contains body of function 'mac_int'
--! @details The function 'mac_int' (and the testbench) interpret input and output data words
--! as integer values instead of fixed-point values. This makes the model easier to describe.
PACKAGE BODY mac_pkg IS

    FUNCTION mac_int(
        a     : INTEGER; --! First multiplication input
        b     : INTEGER; --! Second multiplication input
        acc   : INTEGER; --! Accumulator register value
        nbits : INTEGER; --! Number of bits
        frac  : INTEGER  --! Number of fractional bits
    )
        RETURN INTEGER IS --! Return value is the updated accumulator register
        VARIABLE prod, prod_cut, sum, sum_sat : INTEGER;
        CONSTANT frac_range                   : INTEGER := 2 ** (frac);
        CONSTANT max_num_out                  : INTEGER := 2 ** (nbits - 1) - 1;
        CONSTANT min_num_out                  : INTEGER := - 2 ** (nbits - 1);
    BEGIN
        --! Multiplication
        prod     := a * b;
        --! Strips the last 'frac' fractional bits off of the multiplication output
        prod_cut := INTEGER(floor(real(prod)/real(frac_range)));
        --! Accumulation
        sum      := prod_cut + acc;

        --! Saturation max
        IF sum > max_num_out THEN
            sum_sat := max_num_out;
            --! Saturation min
        ELSIF sum < min_num_out THEN
            sum_sat := min_num_out;
        ELSE
            sum_sat := sum;
        END IF;
        RETURN INTEGER(sum_sat);
    END;

END PACKAGE BODY mac_pkg;