--*****************************************************************************
--*  Copyright (c) 2012 by Michael Fischer. All rights reserved.
--*
--*  Redistribution and use in source and binary forms, with or without 
--*  modification, are permitted provided that the following conditions 
--*  are met:
--*  
--*  1. Redistributions of source code must retain the above copyright 
--*     notice, this list of conditions and the following disclaimer.
--*  2. Redistributions in binary form must reproduce the above copyright
--*     notice, this list of conditions and the following disclaimer in the 
--*     documentation and/or other materials provided with the distribution.
--*  3. Neither the name of the author nor the names of its contributors may 
--*     be used to endorse or promote products derived from this software 
--*     without specific prior written permiSS_asyncion.
--*
--*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
--*  "AS IS" AND ANY EXPRESS_async OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
--*  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS_async 
--*  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
--*  THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
--*  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
--*  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS_async 
--*  OF USE, DATA, OR PROFITS; OR BUSINESS_async INTERRUPTION) HOWEVER CAUSED 
--*  AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
--*  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
--*  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSS_asyncIBILITY OF 
--*  SUCH DAMAGE.
--*
--*****************************************************************************
--*  History:
--*
--*  14.07.2011  mifi  First Version
--*****************************************************************************


--*****************************************************************************
--*  DEFINE: Library                                                          *
--*****************************************************************************
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_arith.all;


--*****************************************************************************
--*  DEFINE: Entity                                                           *
--*****************************************************************************

entity uart_halfduplex is
   port( 
         clk                      : in   std_logic;
			rst                      : in   std_logic;
			parallell_data_out       : out  std_logic_vector(7 downto 0);
			parallell_data_out_valid : out  std_logic;
			uart_data_in				 : in   std_logic;
			
			parallell_data_in        : in  std_logic_vector(7 downto 0);
			parallell_data_in_valid  : in  std_logic;
			parallell_data_in_sent   : out std_logic;
			uart_data_out				 : out std_logic;
			
			rts							 : out std_logic
       );
end entity uart_halfduplex;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of uart_halfduplex is


	component txuart is
   port( 
         clk                      : in  std_logic;
			rst                      : in  std_logic;
			parallell_data_in        : in  std_logic_vector(7 downto 0);
			parallell_data_in_valid  : in  std_logic;
			parallell_data_in_sent   : out std_logic;
			uart_data_out				 : out std_logic;
			busy							 : out std_logic
       );
	end component;
	
	component rxuart is
   port( 
         clk                      : in   std_logic;
			rst                      : in   std_logic;
			parallell_data_out       : out  std_logic_vector(7 downto 0);
			parallell_data_out_valid : out  std_logic;
			uart_data_in_ext			 : in   std_logic
       );
	end component;
	
begin

	inst_txuart : txuart
		port map( 
						clk                      => clk,
						rst                      => rst,
						parallell_data_in        => parallell_data_in,
						parallell_data_in_valid  => parallell_data_in_valid,
						parallell_data_in_sent   => parallell_data_in_sent,
						uart_data_out				 => uart_data_out,
						busy							 => rts
       );
		 
	inst_rxuart : rxuart
		port map(
						clk                      => clk,
						rst                      => rst,
						parallell_data_out       => parallell_data_out,
						parallell_data_out_valid => parallell_data_out_valid,
						uart_data_in_ext			 => uart_data_in
       );

	
end architecture syn;

-- *** EOF ***
