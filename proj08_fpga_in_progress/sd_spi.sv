`timescale 1ns / 1ps

//Makes init of the SD card in the 1-bit SPI mode
//and dumps some debug into RS232 (115200, 8 bits (LSB first), 1 stop, no parity, for example cu -l /dev/ttyUSB0 -s 115200)

//1. https://www.sdcard.org/downloads/pls/ :
//SD Specifications Part 1 Physical Layer Simplified Specification Version 9.10 December 1, 2023
//2. https://electronics.stackexchange.com/questions/602105/how-can-i-initialize-use-sd-cards-with-spi
//3. http://rjhcoding.com/avrc-sd-interface-3.php
//
//FPGA board specs https://digilent.com/reference/programmable-logic/nexys-video/reference-manual :
//"All of the SD pins on the FPGA are wired to support full SD speeds in native interface mode,
//as shown in Fig. 12. The SPI interface is also available, if needed".
//...but Nexys Video seems to support 3,3V only, which the most probably means max. speed 25MB/s
//
//## UART
//set_property -dict { PACKAGE_PIN AA19  IOSTANDARD LVCMOS33 } [get_ports { uart_rx_out }]; #IO_L15P_T2_DQS_RDWR_B_14 Sch=uart_rx_out
//## SD card
// set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { sd_cclk }]; #IO_L12P_T1_MRCC_14 Sch=sd_cclk
// #set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { sd_cd }]; #IO_L20N_T3_A07_D23_14 Sch=sd_cd
// set_property -dict { PACKAGE_PIN W20   IOSTANDARD LVCMOS33 } [get_ports { sd_cmd }]; #IO_L12N_T1_MRCC_14 Sch=sd_cmd
// set_property -dict { PACKAGE_PIN V19   IOSTANDARD LVCMOS33 } [get_ports { sd_data0 }]; #IO_L14N_T2_SRCC_14 Sch=sd_d[0]
// #set_property -dict { PACKAGE_PIN T21   IOSTANDARD LVCMOS33 } [get_ports { sd_d1 }]; #IO_L4P_T0_D04_14 Sch=sd_d[1]
// #set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { sd_d2 }]; #IO_L6N_T0_D08_VREF_14 Sch=sd_d[2]
// set_property -dict { PACKAGE_PIN U18   IOSTANDARD LVCMOS33 } [get_ports { sd_cs }]; #IO_L18N_T2_A11_D27_14 Sch=sd_d[3]
// set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { sd_reset }]; #IO_L11N_T1_SRCC_14 Sch=sd_reset
module x (
    input clk,
    output bit uart_rx_out,
    output bit sd_cclk,  //400 Hz (init) or 25 Mhz (later)
    output bit sd_cmd,  //cmd input
    input sd_data0,  //cmd & data output
    output bit sd_reset,
    output bit sd_cs
);

  // verilog_format:off
/* DEBUG info */ `define HARD_DEBUG(ARG, ARG2) \
/* DEBUG info */   //  if (reset_uart_buffer_available) uart_buffer_available = 0; \
/* DEBUG info */    uart_buffer[ARG] <= ARG2/16>=10? ARG2/16 + 65 - 10:ARG2/16+ 48; \
/* DEBUG info */    uart_buffer[ARG+1] <= ARG2%16>=10? ARG2%16 + 65 - 10:ARG2%16+ 48;
/* DEBUG info */ `define SAVE_CMD(ARG, ARG2) \
/* DEBUG info */    cmd[0:1]<= 2'b01; \
/* DEBUG info */    cmd[2:7]<= ARG; \
/* DEBUG info */    cmd[8:39]<= ARG2; \
/* DEBUG info */    cmd[40:46]<= 7'b0; \
/* DEBUG info */    cmd[47]<=1; \
/* DEBUG info */    calc_crc7<=1;
// verilog_format:on

  //uart
  reg [7:0] uart_buffer[0:200];
  reg [6:0] uart_buffer_index = 0;
  wire reset_uart_buffer_index;
  wire uart_buffer_full;

  uartx_tx_with_buffer uartx_tx_with_buffer (
      .clk(clk),
      .uart_buffer(uart_buffer),
      .uart_buffer_available(uart_buffer_index),
      .reset_uart_buffer_available(reset_uart_buffer_index),
      .uart_buffer_full(uart_buffer_full),
      .tx(uart_rx_out)
  );

  parameter CLK_DIVIDER_400kHz = 100000000 / 400000;  //100 Mhz / 400 Khz
  parameter CLK_DIVIDER_25Mhz = 100000000 / 25000000;  //100 Mhz / 25 Mhz

  parameter STATE_WAIT_INIT = 1;
  parameter STATE_INIT_OK = 3;
  parameter STATE_INIT_ERROR = 4;
  parameter STATE_WAIT_START = 5;
  parameter STATE_WAIT_SEND_CMD = 6;
  parameter STATE_WAIT_GET_RESPONSE = 7;
  parameter STATE_WAIT_GET_BLOCK = 8;
  parameter STATE_WAIT_END = 9;
  parameter STATE_SEND_CMD0 = 10;  //reset command
  parameter STATE_GET_CMD0_RESPONSE = 11;
  parameter STATE_SEND_CMD8 = 12;  //interface condition
  parameter STATE_GET_CMD8_RESPONSE = 14;
  parameter STATE_SEND_CMD16 = 15;  //set block len
  parameter STATE_GET_CMD16_RESPONSE = 16;
  parameter STATE_SEND_CMD17 = 17;  //read single block
  parameter STATE_GET_CMD17_RESPONSE = 18;
  parameter STATE_SEND_ACMD41 = 19;  //send operation condition
  parameter STATE_GET_ACMD41_RESPONSE = 20;
  parameter STATE_SEND_CMD55 = 21;
  parameter STATE_GET_CMD55_RESPONSE = 22;
  parameter STATE_SEND_CMD58 = 23;  //read OCR
  parameter STATE_GET_CMD58_RESPONSE = 24;
  parameter STATE_SEND_CMD58_2 = 25;  //read OCR
  parameter STATE_GET_CMD58_2_RESPONSE = 26;

  reg [0:47] cmd, resp;
  reg [0:7] crc7;
  reg [0:511+16] read_block;
  reg [10:0] cmd_bits, resp_bits, resp_bits_to_receive, read_block_bits;
  reg flag = 1,
      sd_cclk_prev,
      sd_sdsc,
      calc_crc7,
      temp_crc7,           
      resp_started,
      read_block_available,
      read_block_started,
      debug_not_processed;
  reg [20:0] clk_divider, clk_counter, timeout_counter, retry_counter;
  reg [8:0] state, next_state;
  reg [7:0] debug, debug_bits;

  always @(posedge clk) begin
    if (state == 0) begin
      sd_cclk <= 0;
    end else if (clk_counter == clk_divider - 1) begin
      clk_counter <= 0;
      sd_cclk <= ~sd_cclk;
      sd_cclk_prev <= sd_cclk;
    end else begin
      clk_counter <= clk_counter + 1;
    end
  end

  always @(posedge clk) begin
    case (state)
      0: begin
        clk_divider <= CLK_DIVIDER_400kHz;
        state <= STATE_WAIT_INIT;
        flag <= 0;
        uart_buffer[0] <= "a";
        uart_buffer[1] <= "a";
        uart_buffer_index <= 2;
        sd_cmd <= 1;
        sd_cs <= 1;
        sd_reset <= 0;
        calc_crc7 <= 0;
        read_block_available <= 0;
        timeout_counter <= 0;
      end
      STATE_WAIT_INIT: begin
        if (timeout_counter == 1000000) begin
          state <= STATE_SEND_CMD0;
          sd_cs <= 0;
        end
        timeout_counter <= timeout_counter + 1;
      end
      STATE_SEND_CMD0: begin  //reset cmd
        //cmd <= 48'h40_00_00_00_00_95;
        cmd <= 48'h40_00_00_00_00_01;
        calc_crc7 <= 1;
        resp_bits_to_receive <= 8;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD0_RESPONSE;
      end
      STATE_GET_CMD0_RESPONSE: begin
        state <= retry_counter == 10 ? STATE_INIT_ERROR: ((resp[0:7] != 1 /* not idle */ || resp_bits  > resp_bits_to_receive) ? 
          STATE_SEND_CMD0 : STATE_SEND_CMD8);
        retry_counter <= retry_counter + 1;
      end
      STATE_SEND_CMD8: begin  //interface condition
        cmd <= 48'h48_00_00_01_AA_87;  //1 = support for 2.7-3.6 V, AA = check pattern
        resp_bits_to_receive <= 40;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD8_RESPONSE;
      end
      STATE_GET_CMD8_RESPONSE: begin
        state <= (resp[0:7] == 5 /*illegal command*/ || (resp[0:7] == 1 /*idle */ && resp[24:31]==1 /*Voltage supported*/ && resp[32:39]==8'hAA))?
           STATE_SEND_CMD58:STATE_INIT_ERROR;
      end
      STATE_SEND_CMD58: begin
        cmd <= 48'h7A_00_00_00_00_FD;
        resp_bits_to_receive <= 40;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD58_RESPONSE;
      end
      STATE_GET_CMD58_RESPONSE: begin
        sd_sdsc <= resp[38];  //0 = sdsc, 1 = sdhc || sdxc
        state <= resp[0:7] == 1 ? STATE_SEND_CMD55 : STATE_INIT_ERROR;
      end
      STATE_SEND_CMD55: begin
        cmd <= 48'h77_00_00_00_00_65;
        resp_bits_to_receive <= 8;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD55_RESPONSE;
        timeout_counter <= 0;
      end
      STATE_GET_CMD55_RESPONSE: begin
        if (timeout_counter == 100000) begin
          state <= STATE_SEND_ACMD41;
        end
        timeout_counter <= timeout_counter + 1;
      end
      STATE_SEND_ACMD41: begin
        cmd <= 48'h69_40_00_00_00_77;  //HCS = 1 -> support SDHC/SDXC cards
        //cmd <= 48'h69_00_00_00_00_01;
        // calc_crc7 <= 1;
        resp_bits_to_receive <= 8;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_ACMD41_RESPONSE;
      end
      STATE_GET_ACMD41_RESPONSE: begin
        if (resp[0:7] != 0) begin
          retry_counter <= retry_counter + 1;
          state <= retry_counter == 20 ? STATE_INIT_ERROR : STATE_SEND_CMD55;
        end else begin
          state <= STATE_SEND_CMD58_2;
        end
      end
      STATE_SEND_CMD58_2: begin
        cmd <= 48'h7A_00_00_00_00_FD;
        resp_bits_to_receive <= 40;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD58_2_RESPONSE;
      end
      STATE_GET_CMD58_2_RESPONSE: begin
        clk_divider <= CLK_DIVIDER_25Mhz;
        state <= STATE_SEND_CMD16;
      end
      STATE_SEND_CMD16: begin
        `SAVE_CMD(6'd16, 32'd512);
        resp_bits_to_receive <= 8;
        state <= STATE_WAIT_START;
        next_state <= STATE_SEND_CMD17;
      end
      STATE_SEND_CMD17: begin  //read single block
        `SAVE_CMD(6'd17, 32'b0);//with this we can address max. 2 GB cards, needs to support 2 addressing schemes       
        resp_bits_to_receive <= 8;
        read_block_available <= 1;
        state <= STATE_WAIT_START;
        next_state <= STATE_GET_CMD17_RESPONSE;
      end
      STATE_GET_CMD17_RESPONSE: begin
        if (read_block_bits != 600) begin
          uart_buffer[uart_buffer_index] <= "y";
          `HARD_DEBUG(uart_buffer_index + 1, read_block[0:7]);
          `HARD_DEBUG(uart_buffer_index + 3, read_block[8:15]);
          `HARD_DEBUG(uart_buffer_index + 5, read_block[16:23]);
          `HARD_DEBUG(uart_buffer_index + 7, read_block[24:31]);
          `HARD_DEBUG(uart_buffer_index + 9, read_block[32:39]);
          uart_buffer_index <= uart_buffer_index + 11;
        end
        state <= STATE_INIT_OK;
      end
      STATE_WAIT_START: begin
        cmd_bits <= 0;
        read_block_bits <= 0;
        resp_bits <= 0;
        resp_started <= 0;
        read_block_started <= 0;
        timeout_counter <= 0;
        uart_buffer[uart_buffer_index] <= "s";
        uart_buffer_index <= uart_buffer_index + 1;
        state <= STATE_WAIT_SEND_CMD;
        debug_bits <= 0;
        debug_not_processed <= 0;
        temp_crc7 <= cmd[40];
      end
      STATE_WAIT_SEND_CMD: begin
        if (clk_counter == 0 && sd_cclk_prev == 0) begin
          if (calc_crc7 && cmd_bits < 40) begin
            //Generator polynomial x^7 + x^3 + 1
            temp_crc7 <= cmd[41];
            cmd[40]   <= cmd[41];
            cmd[41]   <= cmd[42];
            cmd[42]   <= cmd[43];
            cmd[43]   <= cmd[44] ^ (cmd[cmd_bits] ^ temp_crc7);
            cmd[44]   <= cmd[45];
            cmd[45]   <= cmd[46];
            cmd[46]   <= cmd[cmd_bits] ^ temp_crc7;
          end
          sd_cmd <= cmd[cmd_bits];
          debug[7-debug_bits] <= cmd[cmd_bits];
          debug_bits <= debug_bits == 7 ? 0 : debug_bits + 1;
          debug_not_processed <= 1;
          if (cmd_bits == 48 - 1) begin
            state <= STATE_WAIT_GET_RESPONSE;
          end
          cmd_bits <= cmd_bits + 1;
        end else if (debug_bits == 0 && debug_not_processed) begin
          `HARD_DEBUG(uart_buffer_index, debug);
          uart_buffer_index   <= uart_buffer_index + 2;
          debug_not_processed <= 0;
        end
      end
      STATE_WAIT_GET_RESPONSE: begin
        if (clk_counter == 0 && sd_cclk_prev == 0) begin
          sd_cmd <= 1;
          if (!sd_data0 || resp_started) begin
            resp_started <= 1;
            resp[resp_bits] <= sd_data0;
            if (resp_bits == resp_bits_to_receive - 1) begin
              state <= read_block_available ? STATE_WAIT_GET_BLOCK : STATE_WAIT_END;
            end
            resp_bits <= resp_bits + 1;
          end else begin
            timeout_counter <= timeout_counter + 1;
            if (timeout_counter == 100) begin
              resp = {0};
              uart_buffer[uart_buffer_index] <= "e";
              uart_buffer_index <= uart_buffer_index + 1;
              resp_bits <= resp_bits_to_receive + 1;
              read_block_bits <= 600;
              state <= STATE_WAIT_END;
            end
          end
        end else if (debug_bits == 0 && debug_not_processed) begin
          `HARD_DEBUG(uart_buffer_index, debug);
          uart_buffer_index   <= uart_buffer_index + 2;
          debug_not_processed <= 0;
        end
      end
      STATE_WAIT_GET_BLOCK: begin
        if (clk_counter == 0 && sd_cclk_prev == 0) begin
          if (!read_block_started && read_block_bits == 8) begin
            if (read_block[0:7] != 8'hFE) begin
              timeout_counter <= timeout_counter + 1;
              if (timeout_counter == 1000) begin
                uart_buffer[uart_buffer_index] <= "E";
                uart_buffer_index <= uart_buffer_index + 1;
                read_block_bits <= 600;
                state <= STATE_WAIT_END;
              end
            end else begin
              read_block_started <= 1;
            end
            read_block_bits <= 0;
          end else begin
            read_block[read_block_bits] <= sd_data0;
            read_block_bits <= read_block_bits + 1;
            if (read_block_bits == 511) state <= STATE_WAIT_END;
          end
        end
      end
      STATE_WAIT_END: begin
        if (clk_counter == 0 && sd_cclk_prev == 0) begin
          uart_buffer[uart_buffer_index] <= "r";
          `HARD_DEBUG(uart_buffer_index + 1, resp[0:7]);
          `HARD_DEBUG(uart_buffer_index + 3, resp[8:15]);
          `HARD_DEBUG(uart_buffer_index + 5, resp[16:23]);
          uart_buffer_index <= uart_buffer_index + 7;
          state <= next_state;
          calc_crc7 <= 0;
        end
      end
    endcase
  end
endmodule

module uartx_tx_with_buffer (
    input clk,
    input [7:0] uart_buffer[0:200],
    input [6:0] uart_buffer_available,
    output bit reset_uart_buffer_available,
    output bit uart_buffer_full,
    output bit tx
);

  bit [7:0] input_data;
  bit [6:0] uart_buffer_processed = 0;
  bit [3:0] uart_buffer_state = 0;
  bit start;
  bit [7:0] uart_buffer_available_old;
  wire complete;

  assign reset_uart_buffer_available = uart_buffer_available_old != 0 && uart_buffer_available_old == uart_buffer_processed && uart_buffer_state == 2 && complete?1:0;
  assign uart_buffer_full = uart_buffer_available_old == 199 ? 1 : 0;
  assign start = uart_buffer_state == 1;

  uart_tx uart_tx (
      .clk(clk),
      .start(start),
      .input_data(input_data),
      .complete(complete),
      .uarttx(tx)
  );

  always @(negedge clk) begin
    uart_buffer_available_old <= uart_buffer_available;
    if (uart_buffer_state == 0) begin
      if (uart_buffer_available_old > 0 && uart_buffer_processed < uart_buffer_available_old) begin
        input_data <= uart_buffer[uart_buffer_processed];
        uart_buffer_state <= uart_buffer_state + 1;
        uart_buffer_processed <= uart_buffer_processed + 1;
      end else if (uart_buffer_processed > uart_buffer_available_old) begin
        uart_buffer_processed <= 0;
      end
    end else if (uart_buffer_state == 1) begin
      if (!complete) uart_buffer_state <= uart_buffer_state + 1;
    end else if (uart_buffer_state == 2) begin
      if (complete) uart_buffer_state <= 0;
    end
  end
endmodule


//115200, 8 bits (LSB first), 1 stop, no parity
//values on tx: ...1, 0 (start bit), (8 data bits), 1 (stop bit), 1... 
//(we make some delay in the end before next seq; every bit is sent CLK_PER_BIT cycles)
module uart_tx (
    input clk,
    input start,
    input [7:0] input_data,
    output bit complete,
    output bit uarttx
);

  parameter CLK_PER_BIT = 100000000 / 115200;  //100 Mhz / transmission speed in bits per second

  parameter STATE_IDLE = 0;  //1
  parameter STATE_START_BIT = 1;  //0
  parameter STATE_DATA_BIT_0 = 2;
  //...
  parameter STATE_DATA_BIT_7 = 9;
  parameter STATE_STOP_BIT = 10;  //1

  bit [ 6:0] uart_tx_state = STATE_IDLE;
  bit [10:0] counter = CLK_PER_BIT;

  assign uarttx = uart_tx_state == STATE_IDLE || uart_tx_state == STATE_STOP_BIT ? 1:(uart_tx_state == STATE_START_BIT ? 0:input_data[uart_tx_state-STATE_DATA_BIT_0]);
  assign complete = uart_tx_state == STATE_IDLE;

  always @(posedge clk) begin
    if (uart_tx_state == STATE_IDLE) begin
      uart_tx_state <= start ? STATE_START_BIT : STATE_IDLE;
    end else begin
      uart_tx_state <= counter == 0 ? (uart_tx_state== STATE_STOP_BIT? STATE_IDLE : uart_tx_state + 1) : uart_tx_state;
      counter <= counter == 0 ? CLK_PER_BIT : counter - 1;
    end
  end
endmodule
