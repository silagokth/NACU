-------------------------------------------------------
--! @file Saturation_Unit.vhd
--! @brief Saturation Unit
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
-- Title      : Saturation Unit
-- Project    : SiLago
-------------------------------------------------------------------------------
-- File       : Saturation_Unit.vhd
-- Author     : Guido Baccelli
-- Company    : KTH
-- Created    : 11/01/2019
-- Last update: 11/01/2019
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
-- 11/01/2019  1.0      Guido Baccelli          Created
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

--! This module saturates the input to the max/min representable numbers in output
ENTITY Saturation_Unit IS
    GENERIC (
        Nb_in  : INTEGER; --! Input bitwidth
        Nb_out : INTEGER  --! Saturation makes sense only if Nb_out < Nb_in
    );
    PORT (
        d_in  : IN signed(Nb_in - 1 DOWNTO 0);  --! Input data
        d_out : OUT signed(Nb_out - 1 DOWNTO 0) --! Output data
    );
END ENTITY;

--! @brief Behavioral description with combinatorial process
ARCHITECTURE bhv OF Saturation_Unit IS

    CONSTANT max_num_out : INTEGER := (2 ** (Nb_out - 1) - 1); --! Max representable number on 'Nb_out' bits
    CONSTANT min_num_out : INTEGER := - 2 ** (Nb_out - 1);     --! Min representable number on 'Nb_out' bits

BEGIN

    --! Saturation process
    sat_proc : PROCESS (d_in)
    BEGIN
        IF d_in > max_num_out THEN
            d_out <= to_signed(max_num_out, d_out'length);
        ELSIF d_in < min_num_out THEN
            d_out <= to_signed(min_num_out, d_out'length);
        ELSE
            d_out <= d_in(Nb_out - 1 DOWNTO 0);
        END IF;
    END PROCESS;
END ARCHITECTURE;