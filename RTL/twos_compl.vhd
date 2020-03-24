-------------------------------------------------------
--! @file twos_compl.vhd
--! @brief Module to calculate 2's compliment
--! @details 
--! @author Guido Baccelli
--! @version 1.0
--! @date 11/01/2019
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
-- Title      : Module to calculate 2's compliment
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : twos_compl.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 11/01/2019
-- Last update: 11/01/2019
-- Platform   : SiLago
-- Standard   : VHDL'08
-- Supervisor : Dimitrios Stathiss
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Contact    : Dimitrios Stathis <stathis@kth.se>
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 11/01/2019  1.0      Guido Baccelli          Created
-- 2020-03-15  1.1      Dimitrios Stathis       Minor fixes and clean up for the
--                                              public GIT
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
--! Package for CGRA Types and Constants
--USE work.top_consts_types_package.ALL;

--! This module performs 2's complement with saturation

--! After 2's complement computation, saturation is needed because 
--! the representation interval for 2's complement signed numbers is not symmetric: 
--! the lowest number -2^(Nb-1) can be represented on 'Nb' bits, but its 2's complement
--! 2^(Nb-1) cannot. In case of -2^(Nb-1), the 2's complement is saturated to 2^(Nb-1)-1.
ENTITY twos_compl IS
    GENERIC (Nb : INTEGER := 16); --! Number of bits
    PORT (
        d_in  : IN signed(Nb - 1 DOWNTO 0); --! Input data
        d_out : OUT signed(Nb - 1 DOWNTO 0) --! Output data
    );
END ENTITY;

--! @brief Behavioral description with combinatorial process
ARCHITECTURE bhv OF twos_compl IS

    CONSTANT max_num_out : INTEGER := 2 ** (Nb - 1) - 1; --! Biggest positive number on 'Nb' bits
    CONSTANT min_num_out : INTEGER := - 2 ** (Nb - 1);   --! Smallest negative number on 'Nb' bits 

BEGIN

    twoscompl : PROCESS (d_in)
    BEGIN
        IF d_in = min_num_out THEN
            d_out <= to_signed(max_num_out, d_out'length);
        ELSE
            d_out <= - d_in;
        END IF;
    END PROCESS;
END ARCHITECTURE;