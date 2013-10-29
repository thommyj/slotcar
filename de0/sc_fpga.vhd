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

entity sc_fpga is
   port( 
	      --
         -- Input clock 
         --
         CLOCK_50      : in  std_logic;
			LED_GREEN     : out std_logic_vector(7 downto 0);
         KEY           : in  std_logic_vector(1 downto 0);
         SW            : in  std_logic_vector(3 downto 0);
			RPI           : in  std_logic_vector(3 downto 0);
			SS_async      : in  std_logic;
			SCLK_async    : in  std_logic;
			MOSI_async    : in  std_logic;
			MISO_async    : out std_logic;
			SS_out        : out std_logic;
			SCLK_out      : out std_logic;
			MOSI_out      : out std_logic;
			MISO_out      : out std_logic
			
       );
end entity sc_fpga;

--*****************************************************************************
--*  DEFINE: Architecture                                                     *
--****************************************************************************

architecture syn of sc_fpga is

   --
   -- Define all components which are included here
   --
	component pll
     port ( 
            inclk0   : in  std_logic  := '0';
            c0       : out std_logic ;
            locked   : out std_logic 
          );
   end component pll;

   --
   -- Define all local signals (like static data) here
   --
   signal el_clk       : std_logic;
   signal pll_locked   : std_logic;
   signal counter_data : std_logic_vector(31 downto 0) := (others => '0');  
	signal saved_sw     : std_logic_vector(3 downto 0) := (others => '0');
   signal SPI_signals  : std_logic_vector(7 downto 0) := (others => '0');
	signal last_SCLK    : std_logic;
	
	signal sreg  		  : std_logic_vector(7 downto 0) := (others => '0');
	signal SCLK_delayed : std_logic := '0';
	signal SCLK 	     : std_logic := '0';
begin

   inst_pll : pll
      port map ( 
                 inclk0 => CLOCK_50,
                 c0     => el_clk,
                 locked => pll_locked
               );

					
	process(el_clk)
		
   begin	
		if rising_edge(el_clk) then
			SCLK <= SCLK_delayed;
			SCLK_delayed <= SCLK_async;
		end if;
	end process;
	
	
	process(el_clk)
		
   begin	
		if rising_edge(el_clk) then
			if(SW = saved_sw) then
				counter_data <= std_logic_vector(unsigned(counter_data) + 1);
			else
				counter_data <= (others => '0');
			end if;
			
			
			if(last_SCLK = '0' and SCLK = '1') then -- Sample Time (Up Flank)
				if(SS_async = '0') then
					sreg(7) <= MOSI_async;
					sreg(6 downto 0) <= sreg(7 downto 1);
				end if;
			elsif(last_SCLK = '1' and SCLK = '0') then -- (Down Flank)	
				if(SS_async = '0') then
					MISO_async <= sreg(0);--MOSI_async;	
				end if;
			end if;
			
			last_SCLK <= SCLK;
			saved_sw <= SW;  
	   end if; 
   end process;
	
	--loop all data back to master
--	MISO <= MOSI_async;
  
   --collect all SPI signals in one array
   SPI_signals(0) <= SS_async;
	SPI_signals(1) <= MOSI_async;
	
	
	SPI_signals(2) <= MOSI_async;  --just loopback at the moment
	SPI_signals(3) <= SCLK_async;
	
	--forward SPI signals to JP0
	SS_out   <= SS_async;
	MOSI_out <= MOSI_async;
	SCLK_out <= SCLK_async;
	MISO_out <= MOSI_async; --just loopback at the moment
	
   LED_GREEN <= counter_data(21 downto 14) when saved_sw="0000" else
                SPI_signals                when saved_sw="1111" else
                (others => counter_data(14));
   
end architecture syn;

-- *** EOF ***
