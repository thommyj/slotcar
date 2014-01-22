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

entity spi is
   port( 
         clk            : in  std_logic;
			rst            : in  std_logic;
			SS_async       : in  std_logic;
			SCLK_async     : in  std_logic;
			MOSI_async     : in  std_logic;
			MISO_async     : out std_logic;
			data_out       : buffer std_logic_vector(7 downto 0);
			data_in        : in  std_logic_vector(7 downto 0);
			data_out_valid : buffer std_logic
--			data_in_valid  : in std_logic
       );
end entity spi;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of spi is

   --
   -- Define all local signals (like static data) here
   --
	signal data_to_send : std_logic_vector(7 downto 0) := (others => '0');
	signal SCLK_saved   : std_logic;
	signal SCLK_delayed : std_logic := '0';
	signal SCLK 	     : std_logic := '0';
	signal receive_cnt  : integer := 0;
	
begin

	--
	-- remove metastabilty on SCLK
	--
	process(clk,rst)
   begin
		if rst = '1' then
			SCLK <= '0';
			SCLK_delayed <= '0';
		elsif rising_edge(clk) then
			SCLK <= SCLK_delayed;
			SCLK_delayed <= SCLK_async;
		end if;
	end process;
	
	
	--
	-- shift in values from RPI when up flank is detected on SCLK
	-- shift out values to RPI when down flank is detected on SCLK
	--
	process(clk,rst)
	begin
		if rst = '1' then
				SCLK_saved   <= '0';
				receive_cnt  <= 0;
		elsif rising_edge(clk) then
		   if(receive_cnt = 8) then
			   receive_cnt <= 0;
		   end if;
			
			if(SCLK_saved = '0' and SCLK = '1') then -- Sample Time (Up Flank)
				if(SS_async = '0') then
					data_out(0) <= MOSI_async;
					data_out(7 downto 1) <= data_out(6 downto 0);
					receive_cnt <= receive_cnt + 1;
				end if;
			elsif(SCLK_saved = '1' and SCLK = '0') then -- (Down Flank)	
				if(SS_async = '0') then
					MISO_async <= data_to_send(7-receive_cnt);
				end if;
		   elsif(receive_cnt = 0) then
				MISO_async <= data_to_send(7);	
			end if;
			
			SCLK_saved <= SCLK;
	   end if; 
   end process;
	
	
	--
	-- clock new data in from decoder when valid is high
	--
	--process(clk,rst)
	--begin	
		--if rst='1' then
			--data_to_send <= x"F0";
		--elsif rising_edge(clk) then
	    --  if(data_out_valid = '1') then
					data_to_send <= data_in;
		   --end if;
		--end if;
	--end process;
	
	data_out_valid <= '1' when receive_cnt=8 else
                     '0'; 
   
end architecture syn;

-- *** EOF ***
