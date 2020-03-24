-------------------------------------------------------
--! @file adder_nbits.vhd
--! @brief This module is an adder with generic bit width
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
-- Title      : adder_nbits
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : adder_nbits.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 09/01/2019
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
-- 09/01/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Clean up and prepared for git
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
--~
--! Standard ieee library, default work library
LIBRARY ieee, work;
--! Standard logic package
USE ieee.std_logic_1164.ALL;
--! Standard numeric package for signed
USE ieee.numeric_std.ALL;

--! This module is a signed adder with generic bit width

--! This module adds two 'Nb' bit operands and yields the results on 'Nb+1' bits 
ENTITY adder_nbits IS
    GENERIC (
        Nb : INTEGER := 32 --! Number of bits
    );
    PORT (
        a      : IN signed(Nb - 1 DOWNTO 0); --! First operand
        b      : IN signed(Nb - 1 DOWNTO 0); --! Second operand
        output : OUT signed(Nb DOWNTO 0)     --! Result
    );
END ENTITY;

--! @brief Behavioral description of adder with a combinatorial process (can be replaced with the instantiation of DW for synposys or similar IP)
--! @details This module adds two 'Nb' bit operands and yields the results on 'Nb+1' bits
ARCHITECTURE bhv OF adder_nbits IS
BEGIN
    --! Addition process
    add_proc : PROCESS (a, b)
        VARIABLE a_ext, b_ext : signed(Nb DOWNTO 0);
    BEGIN
        --! Operand resized on one more bit
        a_ext := resize(a, output'length);
        --! Operand resized on one more bit
        b_ext := resize(b, output'length);
        output <= a_ext + b_ext;
    END PROCESS;
END ARCHITECTURE;