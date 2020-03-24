-------------------------------------------------------
--! @file ann_pkg.vhd
--! @brief Package containing all types and constants for NACU, used for synthesis
--! @details 
--! @author Guido Baccelli
--! @version 1.1
--! @date 20/08/2019
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
-- Title      : NACU package
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : ann_pkg.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 20/08/2019
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
-- 20/08/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Clean up and prepare for public Git
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

--! Package containing all types and constants for ann_unit
PACKAGE ann_pkg IS

    CONSTANT synth_div    : std_logic := '1';                      --! Synthesis option
    CONSTANT div_pipe_num : NATURAL   := 5;                        --! Synthesis option
    CONSTANT Nb           : NATURAL   := 16;                       --! Bitwidth
    CONSTANT ib           : NATURAL   := 4;                        --! Number of integer bits (for fixed-point data)
    CONSTANT fb           : NATURAL   := 11;                       --! Number of fractional bits (for fixed-point data)
    CONSTANT Nb_div       : NATURAL   := 2 * Nb;                   --! Number of bits for the divider
    CONSTANT Nb_add       : NATURAL   := 2 * Nb;                   --! Number of bits for the adders
    CONSTANT Nb_m_cut     : NATURAL   := 2 * Nb - fb;              --! Number of relevant bits to extract from multiplier output
    CONSTANT Nb_opc       : NATURAL   := 3;                        --! Number of bits for opcode
    CONSTANT IDLE         : INTEGER   := 0;                        --! Opcode idle state
    CONSTANT MAC          : INTEGER   := 1;                        --! Opcode Multiply-Add-Accumulate
    CONSTANT SIGM         : INTEGER   := 2;                        --! Opcode Sigmoid 
    CONSTANT TANHYP       : INTEGER   := 3;                        --! Opcode Hyperbolic Tangent
    CONSTANT EXPON        : INTEGER   := 4;                        --! Opcode Exponential
    CONSTANT SM           : INTEGER   := 5;                        --! Opcode Softmax division

    SUBTYPE opc_range IS NATURAL RANGE Nb_opc - 1 DOWNTO 0;        --! Opcode bit range
    SUBTYPE in_range IS NATURAL RANGE Nb - 1 DOWNTO 0;             --! Input bit range
    SUBTYPE sq_mode_range IS NATURAL RANGE 1 DOWNTO 0;             --! Squash mode bit range
    SUBTYPE mult_out_range IS NATURAL RANGE Nb_m_cut - 1 DOWNTO 0; --! Multiplier output bit range
    SUBTYPE add_in_range IS NATURAL RANGE Nb_add - 1 DOWNTO 0;     --! Adder input bit range
    SUBTYPE add_out_range IS NATURAL RANGE Nb_add DOWNTO 0;        --! Adder output bit range
    SUBTYPE div_range IS NATURAL RANGE 2 * Nb - 1 DOWNTO 0;        --! Divider input/output bit range

    FUNCTION log2c (n : INTEGER) RETURN INTEGER;                   --! Function: base 2 logarithm and ceiling

END PACKAGE ann_pkg;

--! @brief The package includes the 'log2c' function implementation.
PACKAGE BODY ann_pkg IS

    --! Computes ceil(log2(n))
    FUNCTION log2c (n : INTEGER) RETURN INTEGER IS
        VARIABLE m, p     : INTEGER;
    BEGIN
        m := 0;
        p := 1;
        FOR i IN 0 TO n LOOP
            IF p < n THEN
                m := m + 1;
                p := p * 2;
            ELSE
                EXIT;
            END IF;
        END LOOP;
        RETURN m;
    END log2c;

END PACKAGE BODY ann_pkg;