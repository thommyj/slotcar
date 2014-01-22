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


--*****************************************************************************
--*  DEFINE: Entity                                                           *
--*****************************************************************************

entity registerfile is
   port( 
         clk				: in  std_logic;
			rst				: in	std_logic;
			
			writer_data		: in  std_logic_vector(7 downto 0);
			writer_address	: in  std_logic_vector(7 downto 0);
			writer_enable	: in  std_logic;
			
			reader_data   : out std_logic_vector(7 downto 0);
			reader_address: in  std_logic_vector(7 downto 0)
       );
end entity registerfile;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of registerfile is

   --
   -- Define all local signals (like static data) here
   --
	type registers_type is array(0 to 255) of std_logic_vector(7 downto 0); --9 + 14 bytes??
	signal registers : registers_type;
	
begin
					
process(clk,rst)
begin
	if(rst = '1') then 
		registers <= (others=> (others=>'0'));
	elsif rising_edge(clk) then
		
		--if write request from writer
		if (writer_enable = '1') then
			if(to_integer(unsigned(writer_address)) < 23) then
				registers(to_integer(unsigned(writer_address))) <= writer_data;
			end if;
			
			--if reader request same address as writer is write to,
			--shortcut data
			--if(reader_address = writer_address) then
			--	reader_data <= writer_data;
			--end if;
		end if;
	end if;
end process;

reader_data <= registers(to_integer(unsigned(reader_address)));

end architecture syn;
-- *** EOF ***
