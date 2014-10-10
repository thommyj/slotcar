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

entity rxuart is
   port( 
         clk                      : in   std_logic;
			rst                      : in   std_logic;
			parallell_data_out       : buffer  std_logic_vector(7 downto 0);
			parallell_data_out_valid : out  std_logic;
			uart_data_in_ext			 : in   std_logic
       );
end entity rxuart;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of rxuart is

	type clkstate_type is (BAUDRATE_CLK_ON, BAUDRATE_CLK_OFF);
   signal uart_clk_re  : std_logic;
	signal clkstate : clkstate_type;
	signal start_baudrate_clk : std_logic;
	
	signal uart_data_in_meta : std_logic_vector(1 downto 0);
	signal uart_data_in : std_logic;
	
	
begin

	--
	-- metastability
	--
	process (clk,rst)
	begin
		if rst = '1' then
			uart_data_in_meta <= "11";
		elsif rising_edge(clk) then
			uart_data_in_meta <= uart_data_in_meta(0) & uart_data_in_ext;
		end if;
	end process;
	uart_data_in <= uart_data_in_meta(1);
	
	--
	--sync in to middle of startbit
	--
	process (clk,rst)
		variable zero_cnt : integer := 0;
	begin
		if rst = '1' then
			zero_cnt := 0;
		elsif rising_edge(clk) then
			if uart_data_in = '0' then
				zero_cnt := zero_cnt + 1;
			else
				zero_cnt := 0;
			end if;
			
			if zero_cnt = 1302 then
				start_baudrate_clk <= '1';
			else
				start_baudrate_clk <= '0';
			end if;
		end if;
	end process;	

	--
	--produce a pulse in middle of each bit
	--
	process(clk,rst)
		variable uart_clk_cnt : integer := 0;
		variable uart_bit_cnt : integer := 0;
   begin
		if rst = '1' then
			uart_clk_re <= '0';
			clkstate <= BAUDRATE_CLK_OFF;
			uart_clk_cnt := 0;
			uart_bit_cnt := 0;
		elsif rising_edge(clk) then
			parallell_data_out_valid <= '0';
			case clkstate is
				when BAUDRATE_CLK_OFF =>
					if start_baudrate_clk = '1' then
						clkstate <= BAUDRATE_CLK_ON;
					end if;
					uart_clk_cnt := 0;
					uart_bit_cnt := 0;
					uart_clk_re <= '0';

				when BAUDRATE_CLK_ON =>
					--50M/(19200)=2604.16
					--TODO: fix average frequency
					if(uart_clk_cnt = 2604) then
						if uart_bit_cnt /= 8 then
							uart_clk_re <= '1';
						end if;
						uart_bit_cnt := uart_bit_cnt + 1;
						uart_clk_cnt := 0;
					else
						uart_clk_re <= '0';
						uart_clk_cnt := uart_clk_cnt + 1;
					end if;
					
					if uart_bit_cnt = 9 then
						clkstate <= BAUDRATE_CLK_OFF;
						parallell_data_out_valid <= '1';
					end if;
			end case;
		end if;
	end process;
	
	--
	-- sample uart data
	--
	process(clk,rst)
	begin
		if rst = '1' then
			parallell_data_out <= (others => '0');
		elsif rising_edge(clk) then
			if uart_clk_re = '1' then
				parallell_data_out <= parallell_data_out(6 downto 0) & uart_data_in;
			end if;	
		end if; 
	end process;
	
	
end architecture syn;

-- *** EOF ***
