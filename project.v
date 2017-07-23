// main module
module project(CLOCK_50, LEDR, KEY, HEX0, HEX1, HEX2, HEX3, HEX5, SW, LEDG, GPIO,
  // The ports below are for the VGA output.  Do not change.
  VGA_CLK,               //  VGA Clock
  VGA_HS,              //  VGA H_SYNC
  VGA_VS,              //  VGA V_SYNC
  VGA_BLANK_N,            //  VGA BLANK
  VGA_SYNC_N,            //  VGA SYNC
  VGA_R,               //  VGA Red[9:0]
  VGA_G,               //  VGA Green[9:0]
  VGA_B               //  VGA Blue[9:0]
);
  // declearation of inputs and outputs
  // hex displays
  output [6:0] HEX0, HEX1, HEX2, HEX3, HEX5;
  // keys for control FSM
  input [1:0] KEY;
  // clock@50mhz
  input CLOCK_50;
  // red leds for first rail
  output [9:0] LEDR;
  // switch as reset signal
  input [0:0] SW;
  // connect external physical buttons to GPIO[0] and GPIO[1]
  input [1:0] GPIO;
  // green leds for second rail
  output [7:0] LEDG;

  // wire connected to first button
  wire push_key_1;
  assign push_key_1 = GPIO[0];
  // wire connected to second button
  wire push_key_2;
  assign push_key_2 = GPIO[1];
  // wire connected to red leds
  wire [9:0] led;
  // wire connected to 8hz pulse
  wire clk_8hz;
  // wire connected to signal if the rhythm is now shifting
  wire if_shift;
  // 8-bit wire as combo counter
  wire [7:0] combo;
  // 8-bit wire as score counter
  wire [7:0] score;
  // wire connected to accuracy
  wire [1:0] accuracy;
  // connect red leds to wire
  assign LEDR[9:0] = led[9:0];

  // Do not change the following outputs
  output      VGA_CLK;           //  VGA Clock
  output      VGA_HS;          //  VGA H_SYNC
  output      VGA_VS;          //  VGA V_SYNC
  output      VGA_BLANK_N;        //  VGA BLANK
  output      VGA_SYNC_N;        //  VGA SYNC
  output  [9:0]  VGA_R;           //  VGA Red[9:0]
  output  [9:0]  VGA_G;           //  VGA Green[9:0]
  output  [9:0]  VGA_B;           //  VGA Blue[9:0]
  wire [2:0] colour;
  wire [7:0] x;
  wire [6:0] y;

  // Create an Instance of a VGA controller - there can be only one!
  // Define the number of colours as well as the initial background
  // image file (.MIF) for the controller.

  // instiantiate the vga adapter
  vga_adapter VGA(
      .resetn(SW[0]),
      .clock(CLOCK_50),
      .colour(colour),
      .x(x),
      .y(y),
      .plot(1'b1),
      /* Signals for the DAC to drive the monitor. */
      .VGA_R(VGA_R),
      .VGA_G(VGA_G),
      .VGA_B(VGA_B),
      .VGA_HS(VGA_HS),
      .VGA_VS(VGA_VS),
      .VGA_BLANK(VGA_BLANK_N),
      .VGA_SYNC(VGA_SYNC_N),
      .VGA_CLK(VGA_CLK));
  defparam VGA.RESOLUTION = "160x120";
  defparam VGA.MONOCHROME = "FALSE";
  defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
  defparam VGA.BACKGROUND_IMAGE = "black.mif";

  // display lower digits of combo at hex0 display
  hex combo_lower(
    .hex_display(HEX0[6:0]),
    .signals(combo[3:0]));

  // display higher digits of combo at hex1 display
  hex combo_higher(
    .hex_display(HEX1[6:0]),
    .signals(combo[7:4]));

  // display lower digits of score at hex2 display
  hex score_lower(
    .hex_display(HEX2[6:0]),
    .signals(score[3:0]));

  // display higher digits of score at hex2 display
  hex score_higher(
    .hex_display(HEX3[6:0]),
    .signals(score[7:4]));

  // display accuracy grade of the user input (P, G, F, N/A)
  hex_accuracy grader(
    .hex(HEX5),
    .accuracy(accuracy));

  // rhythm maps
  localparam RHYTHM_MAP_KEY_1 = 142'b1111000100000001010100010000000101010000010001000001000001010000000100000100010000010000010100000001000000010000000100000001000000010000000000;
  localparam RHYTHM_MAP_KEY_2 = 142'b1111000101010001000000010101000100000001000000010000000100000001000000010000000100000001000000010000000100000001000000010000000100000000000000;

  // 8hz pulse
  clock_8hz watch (
    .clk(CLOCK_50),
    .out(clk_8hz));

  // fsm control module
  control donald_trump(
    .clk(CLOCK_50),
    .start(KEY[0]),
    .rst(SW[0]),
    .enable_shift(if_shift));

  // fsm datapath module
  datapath sweatshop(
    .clk_8(clk_8hz),
    .clk_50m(CLOCK_50),
    .load(KEY[0]),
    .rst(SW[0]),
    .button_1(push_key_1),
    .button_2(push_key_2),
    .is_start(if_shift),
    .init_rhythm_map_key_1(RHYTHM_MAP_KEY_1),
    .init_rhythm_map_key_2(RHYTHM_MAP_KEY_2),
    .rhythm_shifter_out_key_1(led[9:0]),
    .rhythm_shifter_out_key_2(LEDG[7:0]),
    .combo(combo[7:0]),
    .score(score[7:0]),
    .accuracy(accuracy),
    .x(x),
    .y(y),
    .colour(colour)
  );
endmodule

// start of control module
module control(clk, start, rst, enable_shift);
  // declearation of inputs and outputs
  input clk, start, rst;
  output enable_shift;

  reg [2:0] current_state, next_state;
  // two fsm states
  localparam WAIT_TO_START = 2'b00,
  GAMING = 2'b01;

  assign enable_shift = (current_state == GAMING) ? 1'b1 : 1'b0;
  // decide the next state depending on the start wire connected to key
  always @(*) begin: state_table
    case (current_state)
      WAIT_TO_START: next_state = start ? GAMING : WAIT_TO_START;
      GAMING: next_state = start ? WAIT_TO_START : GAMING;
      default: next_state = WAIT_TO_START;
    endcase
  end

  always @(posedge clk) begin
    if (!rst) begin
      // reset
      current_state <= WAIT_TO_START;
    end
    else begin
      current_state <= next_state;
    end
  end
endmodule

// start of datapath module
module datapath(clk_8, clk_50m, load, button_1, button_2, is_start, rst, init_rhythm_map_key_1, init_rhythm_map_key_2, rhythm_shifter_out_key_1, rhythm_shifter_out_key_2, combo, score, accuracy, x, y, colour);
  // declearation of inputs and outputs
  input clk_8, clk_50m, is_start, rst, load, button_1, button_2;
  input [190:0] init_rhythm_map_key_1, init_rhythm_map_key_2;
  reg [190:0] rhythm_shifter, rhythm_shifter_key_2;
  output wire [9:0] rhythm_shifter_out_key_1, rhythm_shifter_out_key_2;
  output reg [7:0] combo = 8'b0;
  output reg [7:0] score = 8'b0;
  output reg [1:0] accuracy = 2'b0;
  reg button_1_last_state, button_2_last_state = 1'b1;
  output reg [7:0] x = 8'b0;
  output reg [6:0] y = 7'b0;
  output reg [2:0] colour = 3'b0;
  // assign last digits of rhythm maps to output leds
  // red leds
  assign rhythm_shifter_out_key_1[9:0] = rhythm_shifter[11:2];
  // green leds
  assign rhythm_shifter_out_key_2[7:0] = rhythm_shifter_key_2[9:2];
  // increments
  reg [14:0] position = 15'b0;
  reg [6:0] x_pos = 7'b0;
  reg [6:0] y_pos = 7'b0;

  always @(posedge clk_50m) begin
    // if rst is pressed, reset the fsm
    if (!rst) begin
      // reset
      rhythm_shifter <= 191'd0;
      rhythm_shifter_key_2 <= 191'd0;
      score <= 8'b0;
      combo <= 8'b0;
    end else begin
      // if load botton is pressed, load the rhythm map
      if (!load) begin
        rhythm_shifter <= init_rhythm_map_key_1;
        rhythm_shifter_key_2 <= init_rhythm_map_key_2;
        score <= 8'b0;
        combo <= 8'b0;
      end else if (clk_8 == 1'b1) begin
        // otherwise start shifting
        rhythm_shifter <= rhythm_shifter >> 1;
        rhythm_shifter_key_2 <= rhythm_shifter_key_2 >> 1;
      end
    end

    // 00: n/a, 01: perfect, 10: good, 11: miss
    // if a button is pressed
    if (button_1 == 1'b0 && button_1_last_state == 1'b1) begin
    // good case
      if (rhythm_shifter[1] == 1'b1) begin
        rhythm_shifter[1] <= 1'b0;
        accuracy <= 2'b10;
        score <= score + 8'd1;
        combo <= combo + 8'd1;
        // perfect case
      end else if (rhythm_shifter[2] == 1'b1) begin
        rhythm_shifter[2] <= 1'b0;
        accuracy <= 2'b01;
        score <= score + 8'd2;
        combo <= combo + 8'd1;
        // perfect case
      end else if (rhythm_shifter[3] == 1'b1) begin
        rhythm_shifter[3] <= 1'b0;
        accuracy <= 2'b01;
        score <= score + 8'd2;
        combo <= combo + 8'd1;
        // good case
      end else if (rhythm_shifter[4] == 1'b1) begin
        rhythm_shifter[4] <= 1'b0;
        accuracy <= 2'b10;
        score <= score + 8'd1;
        combo <= combo + 8'd1;
        // miss case
      end else if (rhythm_shifter[5] == 1'b1) begin
        rhythm_shifter[5] <= 1'b0;
        accuracy <= 2'b11;
        combo <= 8'd0;
        // miss case
      end else if (rhythm_shifter[6] == 1'b1) begin
        rhythm_shifter[6] <= 1'b0;
        accuracy <= 2'b11;
        combo <= 8'd0;
      end
    end
    // button_2 is pressed
    if (button_2 == 1'b0 && button_2_last_state == 1'b1) begin
      // good case
      if (rhythm_shifter_key_2[1] == 1'b1) begin
        rhythm_shifter_key_2[1] <= 1'b0;
        accuracy <= 2'b10;
        score <= score + 8'd1;
        combo <= combo + 8'd1;
        // perfect case
      end else if (rhythm_shifter_key_2[2] == 1'b1) begin
        rhythm_shifter_key_2[2] <= 1'b0;
        accuracy <= 2'b01;
        score <= score + 8'd2;
        combo <= combo + 8'd1;
        // perfect case
      end else if (rhythm_shifter_key_2[3] == 1'b1) begin
        rhythm_shifter_key_2[3] <= 1'b0;
        accuracy <= 2'b01;
        score <= score + 8'd2;
        combo <= combo + 8'd1;
        // good case
      end else if (rhythm_shifter_key_2[4] == 1'b1) begin
        rhythm_shifter_key_2[4] <= 1'b0;
        accuracy <= 2'b10;
        score <= score + 8'd1;
        combo <= combo + 8'd1;
      end else if (rhythm_shifter_key_2[5] == 1'b1) begin
      // miss case
        rhythm_shifter_key_2[5] <= 1'b0;
        accuracy <= 2'b11;
        combo <= 8'd0;
      end else if (rhythm_shifter_key_2[6] == 1'b1) begin
      // miss case
        rhythm_shifter_key_2[6] <= 1'b0;
        accuracy <= 2'b11;
        combo <= 8'd0;
      end
    end
    // if the last digit of the rhythm_shifter is 1'b1, player must missed a note
    if ((rhythm_shifter[0] == 1'b1) || (rhythm_shifter_key_2[0] == 1'b1)) begin
      combo <= 1'b0;
      accuracy <= 2'b11;
    end

    // set the last states of buttons
    button_1_last_state <= button_1;
    button_2_last_state <= button_2;
  end

  // set te colors
  wire [15:0] shifter_out_color_r;
  wire [15:0] shifter_out_color_g;
  assign shifter_out_color_r = rhythm_shifter[15:0];
  assign shifter_out_color_g = rhythm_shifter_key_2[15:0];

  // set increments
  always @(posedge clk_50m) begin
    if (position == 15'b100000000000000) begin
      position <= 15'b0;
    end

    x_pos[6:0] <= position[13:7];
    y_pos[6:0] <= position[6:0];

    if (x_pos < 7'd8 && y_pos < 7'd8 && !rhythm_shifter[2] && !rhythm_shifter_key_2[2]) begin
      colour <= 3'b111;
    end else if ((y_pos < 7'd8) && (rhythm_shifter[x_pos / 8 + 7'd2]) && (rhythm_shifter_key_2[x_pos / 8 + 7'd2])) begin
      colour <= 3'b110;
    end else if ((y_pos < 7'd8) && (rhythm_shifter[x_pos / 8 + 7'd2])) begin
      colour <= 3'b100;
    end else if ((y_pos < 7'd8) && (rhythm_shifter_key_2[x_pos / 8 + 7'd2])) begin
      colour <= 3'b011;
    end else if ((y_pos < 7'd8) && (!rhythm_shifter[x_pos / 8 + 7'd2]) && !(rhythm_shifter_key_2[x_pos / 8 + 7'd2])) begin
      colour <= 3'b000;
    end else if ((accuracy == 2'b01) && (  // perfect
      (x_pos == 7'd54 && y_pos == 7'd55) ||
      (x_pos == 7'd55 && y_pos == 7'd55) ||
      (x_pos == 7'd56 && y_pos == 7'd55) ||
      (x_pos == 7'd57 && y_pos == 7'd55) ||
      (x_pos == 7'd58 && y_pos == 7'd55) ||
      (x_pos == 7'd61 && y_pos == 7'd55) ||
      (x_pos == 7'd62 && y_pos == 7'd55) ||
      (x_pos == 7'd63 && y_pos == 7'd55) ||
      (x_pos == 7'd64 && y_pos == 7'd55) ||
      (x_pos == 7'd65 && y_pos == 7'd55) ||
      (x_pos == 7'd66 && y_pos == 7'd55) ||
      (x_pos == 7'd69 && y_pos == 7'd55) ||
      (x_pos == 7'd70 && y_pos == 7'd55) ||
      (x_pos == 7'd71 && y_pos == 7'd55) ||
      (x_pos == 7'd72 && y_pos == 7'd55) ||
      (x_pos == 7'd73 && y_pos == 7'd55) ||
      (x_pos == 7'd74 && y_pos == 7'd55) ||
      (x_pos == 7'd77 && y_pos == 7'd55) ||
      (x_pos == 7'd78 && y_pos == 7'd55) ||
      (x_pos == 7'd79 && y_pos == 7'd55) ||
      (x_pos == 7'd80 && y_pos == 7'd55) ||
      (x_pos == 7'd81 && y_pos == 7'd55) ||
      (x_pos == 7'd82 && y_pos == 7'd55) ||
      (x_pos == 7'd84 && y_pos == 7'd55) ||
      (x_pos == 7'd85 && y_pos == 7'd55) ||
      (x_pos == 7'd86 && y_pos == 7'd55) ||
      (x_pos == 7'd87 && y_pos == 7'd55) ||
      (x_pos == 7'd88 && y_pos == 7'd55) ||
      (x_pos == 7'd89 && y_pos == 7'd55) ||
      (x_pos == 7'd92 && y_pos == 7'd55) ||
      (x_pos == 7'd93 && y_pos == 7'd55) ||
      (x_pos == 7'd94 && y_pos == 7'd55) ||
      (x_pos == 7'd95 && y_pos == 7'd55) ||
      (x_pos == 7'd96 && y_pos == 7'd55) ||
      (x_pos == 7'd97 && y_pos == 7'd55) ||
      (x_pos == 7'd99 && y_pos == 7'd55) ||
      (x_pos == 7'd100 && y_pos == 7'd55) ||
      (x_pos == 7'd101 && y_pos == 7'd55) ||
      (x_pos == 7'd102 && y_pos == 7'd55) ||
      (x_pos == 7'd103 && y_pos == 7'd55) ||
      (x_pos == 7'd104 && y_pos == 7'd55) ||
      (x_pos == 7'd105 && y_pos == 7'd55) ||
      (x_pos == 7'd53 && y_pos == 7'd56) ||
      (x_pos == 7'd54 && y_pos == 7'd56) ||
      (x_pos == 7'd55 && y_pos == 7'd56) ||
      (x_pos == 7'd56 && y_pos == 7'd56) ||
      (x_pos == 7'd57 && y_pos == 7'd56) ||
      (x_pos == 7'd58 && y_pos == 7'd56) ||
      (x_pos == 7'd59 && y_pos == 7'd56) ||
      (x_pos == 7'd61 && y_pos == 7'd56) ||
      (x_pos == 7'd62 && y_pos == 7'd56) ||
      (x_pos == 7'd63 && y_pos == 7'd56) ||
      (x_pos == 7'd64 && y_pos == 7'd56) ||
      (x_pos == 7'd65 && y_pos == 7'd56) ||
      (x_pos == 7'd66 && y_pos == 7'd56) ||
      (x_pos == 7'd68 && y_pos == 7'd56) ||
      (x_pos == 7'd69 && y_pos == 7'd56) ||
      (x_pos == 7'd70 && y_pos == 7'd56) ||
      (x_pos == 7'd71 && y_pos == 7'd56) ||
      (x_pos == 7'd72 && y_pos == 7'd56) ||
      (x_pos == 7'd73 && y_pos == 7'd56) ||
      (x_pos == 7'd74 && y_pos == 7'd56) ||
      (x_pos == 7'd76 && y_pos == 7'd56) ||
      (x_pos == 7'd77 && y_pos == 7'd56) ||
      (x_pos == 7'd78 && y_pos == 7'd56) ||
      (x_pos == 7'd79 && y_pos == 7'd56) ||
      (x_pos == 7'd80 && y_pos == 7'd56) ||
      (x_pos == 7'd81 && y_pos == 7'd56) ||
      (x_pos == 7'd82 && y_pos == 7'd56) ||
      (x_pos == 7'd84 && y_pos == 7'd56) ||
      (x_pos == 7'd85 && y_pos == 7'd56) ||
      (x_pos == 7'd86 && y_pos == 7'd56) ||
      (x_pos == 7'd87 && y_pos == 7'd56) ||
      (x_pos == 7'd88 && y_pos == 7'd56) ||
      (x_pos == 7'd89 && y_pos == 7'd56) ||
      (x_pos == 7'd91 && y_pos == 7'd56) ||
      (x_pos == 7'd92 && y_pos == 7'd56) ||
      (x_pos == 7'd93 && y_pos == 7'd56) ||
      (x_pos == 7'd94 && y_pos == 7'd56) ||
      (x_pos == 7'd95 && y_pos == 7'd56) ||
      (x_pos == 7'd96 && y_pos == 7'd56) ||
      (x_pos == 7'd97 && y_pos == 7'd56) ||
      (x_pos == 7'd99 && y_pos == 7'd56) ||
      (x_pos == 7'd100 && y_pos == 7'd56) ||
      (x_pos == 7'd101 && y_pos == 7'd56) ||
      (x_pos == 7'd102 && y_pos == 7'd56) ||
      (x_pos == 7'd103 && y_pos == 7'd56) ||
      (x_pos == 7'd104 && y_pos == 7'd56) ||
      (x_pos == 7'd105 && y_pos == 7'd56) ||
      (x_pos == 7'd53 && y_pos == 7'd57) ||
      (x_pos == 7'd54 && y_pos == 7'd57) ||
      (x_pos == 7'd55 && y_pos == 7'd57) ||
      (x_pos == 7'd58 && y_pos == 7'd57) ||
      (x_pos == 7'd59 && y_pos == 7'd57) ||
      (x_pos == 7'd61 && y_pos == 7'd57) ||
      (x_pos == 7'd62 && y_pos == 7'd57) ||
      (x_pos == 7'd68 && y_pos == 7'd57) ||
      (x_pos == 7'd69 && y_pos == 7'd57) ||
      (x_pos == 7'd70 && y_pos == 7'd57) ||
      (x_pos == 7'd73 && y_pos == 7'd57) ||
      (x_pos == 7'd74 && y_pos == 7'd57) ||
      (x_pos == 7'd76 && y_pos == 7'd57) ||
      (x_pos == 7'd77 && y_pos == 7'd57) ||
      (x_pos == 7'd78 && y_pos == 7'd57) ||
      (x_pos == 7'd84 && y_pos == 7'd57) ||
      (x_pos == 7'd85 && y_pos == 7'd57) ||
      (x_pos == 7'd91 && y_pos == 7'd57) ||
      (x_pos == 7'd92 && y_pos == 7'd57) ||
      (x_pos == 7'd93 && y_pos == 7'd57) ||
      (x_pos == 7'd101 && y_pos == 7'd57) ||
      (x_pos == 7'd102 && y_pos == 7'd57) ||
      (x_pos == 7'd103 && y_pos == 7'd57) ||
      (x_pos == 7'd53 && y_pos == 7'd58) ||
      (x_pos == 7'd54 && y_pos == 7'd58) ||
      (x_pos == 7'd55 && y_pos == 7'd58) ||
      (x_pos == 7'd58 && y_pos == 7'd58) ||
      (x_pos == 7'd59 && y_pos == 7'd58) ||
      (x_pos == 7'd61 && y_pos == 7'd58) ||
      (x_pos == 7'd62 && y_pos == 7'd58) ||
      (x_pos == 7'd68 && y_pos == 7'd58) ||
      (x_pos == 7'd69 && y_pos == 7'd58) ||
      (x_pos == 7'd70 && y_pos == 7'd58) ||
      (x_pos == 7'd73 && y_pos == 7'd58) ||
      (x_pos == 7'd74 && y_pos == 7'd58) ||
      (x_pos == 7'd76 && y_pos == 7'd58) ||
      (x_pos == 7'd77 && y_pos == 7'd58) ||
      (x_pos == 7'd78 && y_pos == 7'd58) ||
      (x_pos == 7'd84 && y_pos == 7'd58) ||
      (x_pos == 7'd85 && y_pos == 7'd58) ||
      (x_pos == 7'd91 && y_pos == 7'd58) ||
      (x_pos == 7'd92 && y_pos == 7'd58) ||
      (x_pos == 7'd93 && y_pos == 7'd58) ||
      (x_pos == 7'd101 && y_pos == 7'd58) ||
      (x_pos == 7'd102 && y_pos == 7'd58) ||
      (x_pos == 7'd103 && y_pos == 7'd58) ||
      (x_pos == 7'd53 && y_pos == 7'd59) ||
      (x_pos == 7'd54 && y_pos == 7'd59) ||
      (x_pos == 7'd55 && y_pos == 7'd59) ||
      (x_pos == 7'd56 && y_pos == 7'd59) ||
      (x_pos == 7'd57 && y_pos == 7'd59) ||
      (x_pos == 7'd58 && y_pos == 7'd59) ||
      (x_pos == 7'd59 && y_pos == 7'd59) ||
      (x_pos == 7'd61 && y_pos == 7'd59) ||
      (x_pos == 7'd62 && y_pos == 7'd59) ||
      (x_pos == 7'd63 && y_pos == 7'd59) ||
      (x_pos == 7'd64 && y_pos == 7'd59) ||
      (x_pos == 7'd65 && y_pos == 7'd59) ||
      (x_pos == 7'd66 && y_pos == 7'd59) ||
      (x_pos == 7'd68 && y_pos == 7'd59) ||
      (x_pos == 7'd69 && y_pos == 7'd59) ||
      (x_pos == 7'd70 && y_pos == 7'd59) ||
      (x_pos == 7'd71 && y_pos == 7'd59) ||
      (x_pos == 7'd72 && y_pos == 7'd59) ||
      (x_pos == 7'd73 && y_pos == 7'd59) ||
      (x_pos == 7'd74 && y_pos == 7'd59) ||
      (x_pos == 7'd76 && y_pos == 7'd59) ||
      (x_pos == 7'd77 && y_pos == 7'd59) ||
      (x_pos == 7'd78 && y_pos == 7'd59) ||
      (x_pos == 7'd79 && y_pos == 7'd59) ||
      (x_pos == 7'd80 && y_pos == 7'd59) ||
      (x_pos == 7'd81 && y_pos == 7'd59) ||
      (x_pos == 7'd82 && y_pos == 7'd59) ||
      (x_pos == 7'd84 && y_pos == 7'd59) ||
      (x_pos == 7'd85 && y_pos == 7'd59) ||
      (x_pos == 7'd86 && y_pos == 7'd59) ||
      (x_pos == 7'd87 && y_pos == 7'd59) ||
      (x_pos == 7'd88 && y_pos == 7'd59) ||
      (x_pos == 7'd89 && y_pos == 7'd59) ||
      (x_pos == 7'd91 && y_pos == 7'd59) ||
      (x_pos == 7'd92 && y_pos == 7'd59) ||
      (x_pos == 7'd93 && y_pos == 7'd59) ||
      (x_pos == 7'd101 && y_pos == 7'd59) ||
      (x_pos == 7'd102 && y_pos == 7'd59) ||
      (x_pos == 7'd103 && y_pos == 7'd59) ||
      (x_pos == 7'd53 && y_pos == 7'd60) ||
      (x_pos == 7'd54 && y_pos == 7'd60) ||
      (x_pos == 7'd55 && y_pos == 7'd60) ||
      (x_pos == 7'd56 && y_pos == 7'd60) ||
      (x_pos == 7'd57 && y_pos == 7'd60) ||
      (x_pos == 7'd58 && y_pos == 7'd60) ||
      (x_pos == 7'd61 && y_pos == 7'd60) ||
      (x_pos == 7'd62 && y_pos == 7'd60) ||
      (x_pos == 7'd63 && y_pos == 7'd60) ||
      (x_pos == 7'd64 && y_pos == 7'd60) ||
      (x_pos == 7'd65 && y_pos == 7'd60) ||
      (x_pos == 7'd66 && y_pos == 7'd60) ||
      (x_pos == 7'd68 && y_pos == 7'd60) ||
      (x_pos == 7'd69 && y_pos == 7'd60) ||
      (x_pos == 7'd70 && y_pos == 7'd60) ||
      (x_pos == 7'd71 && y_pos == 7'd60) ||
      (x_pos == 7'd72 && y_pos == 7'd60) ||
      (x_pos == 7'd73 && y_pos == 7'd60) ||
      (x_pos == 7'd74 && y_pos == 7'd60) ||
      (x_pos == 7'd76 && y_pos == 7'd60) ||
      (x_pos == 7'd77 && y_pos == 7'd60) ||
      (x_pos == 7'd78 && y_pos == 7'd60) ||
      (x_pos == 7'd79 && y_pos == 7'd60) ||
      (x_pos == 7'd80 && y_pos == 7'd60) ||
      (x_pos == 7'd81 && y_pos == 7'd60) ||
      (x_pos == 7'd82 && y_pos == 7'd60) ||
      (x_pos == 7'd84 && y_pos == 7'd60) ||
      (x_pos == 7'd85 && y_pos == 7'd60) ||
      (x_pos == 7'd86 && y_pos == 7'd60) ||
      (x_pos == 7'd87 && y_pos == 7'd60) ||
      (x_pos == 7'd88 && y_pos == 7'd60) ||
      (x_pos == 7'd89 && y_pos == 7'd60) ||
      (x_pos == 7'd91 && y_pos == 7'd60) ||
      (x_pos == 7'd92 && y_pos == 7'd60) ||
      (x_pos == 7'd93 && y_pos == 7'd60) ||
      (x_pos == 7'd101 && y_pos == 7'd60) ||
      (x_pos == 7'd102 && y_pos == 7'd60) ||
      (x_pos == 7'd103 && y_pos == 7'd60) ||
      (x_pos == 7'd53 && y_pos == 7'd61) ||
      (x_pos == 7'd54 && y_pos == 7'd61) ||
      (x_pos == 7'd55 && y_pos == 7'd61) ||
      (x_pos == 7'd61 && y_pos == 7'd61) ||
      (x_pos == 7'd62 && y_pos == 7'd61) ||
      (x_pos == 7'd68 && y_pos == 7'd61) ||
      (x_pos == 7'd69 && y_pos == 7'd61) ||
      (x_pos == 7'd70 && y_pos == 7'd61) ||
      (x_pos == 7'd71 && y_pos == 7'd61) ||
      (x_pos == 7'd72 && y_pos == 7'd61) ||
      (x_pos == 7'd73 && y_pos == 7'd61) ||
      (x_pos == 7'd76 && y_pos == 7'd61) ||
      (x_pos == 7'd77 && y_pos == 7'd61) ||
      (x_pos == 7'd78 && y_pos == 7'd61) ||
      (x_pos == 7'd84 && y_pos == 7'd61) ||
      (x_pos == 7'd85 && y_pos == 7'd61) ||
      (x_pos == 7'd91 && y_pos == 7'd61) ||
      (x_pos == 7'd92 && y_pos == 7'd61) ||
      (x_pos == 7'd93 && y_pos == 7'd61) ||
      (x_pos == 7'd101 && y_pos == 7'd61) ||
      (x_pos == 7'd102 && y_pos == 7'd61) ||
      (x_pos == 7'd103 && y_pos == 7'd61) ||
      (x_pos == 7'd53 && y_pos == 7'd62) ||
      (x_pos == 7'd54 && y_pos == 7'd62) ||
      (x_pos == 7'd55 && y_pos == 7'd62) ||
      (x_pos == 7'd61 && y_pos == 7'd62) ||
      (x_pos == 7'd62 && y_pos == 7'd62) ||
      (x_pos == 7'd68 && y_pos == 7'd62) ||
      (x_pos == 7'd69 && y_pos == 7'd62) ||
      (x_pos == 7'd70 && y_pos == 7'd62) ||
      (x_pos == 7'd72 && y_pos == 7'd62) ||
      (x_pos == 7'd73 && y_pos == 7'd62) ||
      (x_pos == 7'd76 && y_pos == 7'd62) ||
      (x_pos == 7'd77 && y_pos == 7'd62) ||
      (x_pos == 7'd78 && y_pos == 7'd62) ||
      (x_pos == 7'd84 && y_pos == 7'd62) ||
      (x_pos == 7'd85 && y_pos == 7'd62) ||
      (x_pos == 7'd91 && y_pos == 7'd62) ||
      (x_pos == 7'd92 && y_pos == 7'd62) ||
      (x_pos == 7'd93 && y_pos == 7'd62) ||
      (x_pos == 7'd101 && y_pos == 7'd62) ||
      (x_pos == 7'd102 && y_pos == 7'd62) ||
      (x_pos == 7'd103 && y_pos == 7'd62) ||
      (x_pos == 7'd53 && y_pos == 7'd63) ||
      (x_pos == 7'd54 && y_pos == 7'd63) ||
      (x_pos == 7'd55 && y_pos == 7'd63) ||
      (x_pos == 7'd61 && y_pos == 7'd63) ||
      (x_pos == 7'd62 && y_pos == 7'd63) ||
      (x_pos == 7'd63 && y_pos == 7'd63) ||
      (x_pos == 7'd64 && y_pos == 7'd63) ||
      (x_pos == 7'd65 && y_pos == 7'd63) ||
      (x_pos == 7'd66 && y_pos == 7'd63) ||
      (x_pos == 7'd68 && y_pos == 7'd63) ||
      (x_pos == 7'd69 && y_pos == 7'd63) ||
      (x_pos == 7'd70 && y_pos == 7'd63) ||
      (x_pos == 7'd72 && y_pos == 7'd63) ||
      (x_pos == 7'd73 && y_pos == 7'd63) ||
      (x_pos == 7'd74 && y_pos == 7'd63) ||
      (x_pos == 7'd76 && y_pos == 7'd63) ||
      (x_pos == 7'd77 && y_pos == 7'd63) ||
      (x_pos == 7'd78 && y_pos == 7'd63) ||
      (x_pos == 7'd84 && y_pos == 7'd63) ||
      (x_pos == 7'd85 && y_pos == 7'd63) ||
      (x_pos == 7'd86 && y_pos == 7'd63) ||
      (x_pos == 7'd87 && y_pos == 7'd63) ||
      (x_pos == 7'd88 && y_pos == 7'd63) ||
      (x_pos == 7'd89 && y_pos == 7'd63) ||
      (x_pos == 7'd91 && y_pos == 7'd63) ||
      (x_pos == 7'd92 && y_pos == 7'd63) ||
      (x_pos == 7'd93 && y_pos == 7'd63) ||
      (x_pos == 7'd94 && y_pos == 7'd63) ||
      (x_pos == 7'd95 && y_pos == 7'd63) ||
      (x_pos == 7'd96 && y_pos == 7'd63) ||
      (x_pos == 7'd97 && y_pos == 7'd63) ||
      (x_pos == 7'd101 && y_pos == 7'd63) ||
      (x_pos == 7'd102 && y_pos == 7'd63) ||
      (x_pos == 7'd103 && y_pos == 7'd63) ||
      (x_pos == 7'd53 && y_pos == 7'd64) ||
      (x_pos == 7'd54 && y_pos == 7'd64) ||
      (x_pos == 7'd61 && y_pos == 7'd64) ||
      (x_pos == 7'd62 && y_pos == 7'd64) ||
      (x_pos == 7'd63 && y_pos == 7'd64) ||
      (x_pos == 7'd64 && y_pos == 7'd64) ||
      (x_pos == 7'd65 && y_pos == 7'd64) ||
      (x_pos == 7'd66 && y_pos == 7'd64) ||
      (x_pos == 7'd68 && y_pos == 7'd64) ||
      (x_pos == 7'd69 && y_pos == 7'd64) ||
      (x_pos == 7'd70 && y_pos == 7'd64) ||
      (x_pos == 7'd73 && y_pos == 7'd64) ||
      (x_pos == 7'd74 && y_pos == 7'd64) ||
      (x_pos == 7'd76 && y_pos == 7'd64) ||
      (x_pos == 7'd77 && y_pos == 7'd64) ||
      (x_pos == 7'd84 && y_pos == 7'd64) ||
      (x_pos == 7'd85 && y_pos == 7'd64) ||
      (x_pos == 7'd86 && y_pos == 7'd64) ||
      (x_pos == 7'd87 && y_pos == 7'd64) ||
      (x_pos == 7'd88 && y_pos == 7'd64) ||
      (x_pos == 7'd89 && y_pos == 7'd64) ||
      (x_pos == 7'd92 && y_pos == 7'd64) ||
      (x_pos == 7'd93 && y_pos == 7'd64) ||
      (x_pos == 7'd94 && y_pos == 7'd64) ||
      (x_pos == 7'd95 && y_pos == 7'd64) ||
      (x_pos == 7'd96 && y_pos == 7'd64) ||
      (x_pos == 7'd97 && y_pos == 7'd64) ||
      (x_pos == 7'd101 && y_pos == 7'd64) ||
      (x_pos == 7'd102 && y_pos == 7'd64) ||
      (x_pos == 7'd103 && y_pos == 7'd64)
    )) begin
      colour <= 3'b100;
    end else if ((accuracy == 2'b10) && (  // good
      (x_pos == 7'd67 && y_pos == 7'd56) ||
      (x_pos == 7'd68 && y_pos == 7'd56) ||
      (x_pos == 7'd69 && y_pos == 7'd56) ||
      (x_pos == 7'd70 && y_pos == 7'd56) ||
      (x_pos == 7'd71 && y_pos == 7'd56) ||
      (x_pos == 7'd75 && y_pos == 7'd56) ||
      (x_pos == 7'd76 && y_pos == 7'd56) ||
      (x_pos == 7'd77 && y_pos == 7'd56) ||
      (x_pos == 7'd78 && y_pos == 7'd56) ||
      (x_pos == 7'd82 && y_pos == 7'd56) ||
      (x_pos == 7'd83 && y_pos == 7'd56) ||
      (x_pos == 7'd84 && y_pos == 7'd56) ||
      (x_pos == 7'd85 && y_pos == 7'd56) ||
      (x_pos == 7'd88 && y_pos == 7'd56) ||
      (x_pos == 7'd89 && y_pos == 7'd56) ||
      (x_pos == 7'd90 && y_pos == 7'd56) ||
      (x_pos == 7'd91 && y_pos == 7'd56) ||
      (x_pos == 7'd92 && y_pos == 7'd56) ||
      (x_pos == 7'd66 && y_pos == 7'd57) ||
      (x_pos == 7'd67 && y_pos == 7'd57) ||
      (x_pos == 7'd68 && y_pos == 7'd57) ||
      (x_pos == 7'd69 && y_pos == 7'd57) ||
      (x_pos == 7'd70 && y_pos == 7'd57) ||
      (x_pos == 7'd71 && y_pos == 7'd57) ||
      (x_pos == 7'd72 && y_pos == 7'd57) ||
      (x_pos == 7'd74 && y_pos == 7'd57) ||
      (x_pos == 7'd75 && y_pos == 7'd57) ||
      (x_pos == 7'd76 && y_pos == 7'd57) ||
      (x_pos == 7'd77 && y_pos == 7'd57) ||
      (x_pos == 7'd78 && y_pos == 7'd57) ||
      (x_pos == 7'd79 && y_pos == 7'd57) ||
      (x_pos == 7'd81 && y_pos == 7'd57) ||
      (x_pos == 7'd82 && y_pos == 7'd57) ||
      (x_pos == 7'd83 && y_pos == 7'd57) ||
      (x_pos == 7'd84 && y_pos == 7'd57) ||
      (x_pos == 7'd85 && y_pos == 7'd57) ||
      (x_pos == 7'd86 && y_pos == 7'd57) ||
      (x_pos == 7'd88 && y_pos == 7'd57) ||
      (x_pos == 7'd89 && y_pos == 7'd57) ||
      (x_pos == 7'd90 && y_pos == 7'd57) ||
      (x_pos == 7'd91 && y_pos == 7'd57) ||
      (x_pos == 7'd92 && y_pos == 7'd57) ||
      (x_pos == 7'd93 && y_pos == 7'd57) ||
      (x_pos == 7'd66 && y_pos == 7'd58) ||
      (x_pos == 7'd67 && y_pos == 7'd58) ||
      (x_pos == 7'd68 && y_pos == 7'd58) ||
      (x_pos == 7'd74 && y_pos == 7'd58) ||
      (x_pos == 7'd75 && y_pos == 7'd58) ||
      (x_pos == 7'd76 && y_pos == 7'd58) ||
      (x_pos == 7'd78 && y_pos == 7'd58) ||
      (x_pos == 7'd79 && y_pos == 7'd58) ||
      (x_pos == 7'd81 && y_pos == 7'd58) ||
      (x_pos == 7'd82 && y_pos == 7'd58) ||
      (x_pos == 7'd83 && y_pos == 7'd58) ||
      (x_pos == 7'd85 && y_pos == 7'd58) ||
      (x_pos == 7'd86 && y_pos == 7'd58) ||
      (x_pos == 7'd88 && y_pos == 7'd58) ||
      (x_pos == 7'd89 && y_pos == 7'd58) ||
      (x_pos == 7'd91 && y_pos == 7'd58) ||
      (x_pos == 7'd92 && y_pos == 7'd58) ||
      (x_pos == 7'd93 && y_pos == 7'd58) ||
      (x_pos == 7'd66 && y_pos == 7'd59) ||
      (x_pos == 7'd67 && y_pos == 7'd59) ||
      (x_pos == 7'd74 && y_pos == 7'd59) ||
      (x_pos == 7'd75 && y_pos == 7'd59) ||
      (x_pos == 7'd78 && y_pos == 7'd59) ||
      (x_pos == 7'd79 && y_pos == 7'd59) ||
      (x_pos == 7'd81 && y_pos == 7'd59) ||
      (x_pos == 7'd82 && y_pos == 7'd59) ||
      (x_pos == 7'd85 && y_pos == 7'd59) ||
      (x_pos == 7'd86 && y_pos == 7'd59) ||
      (x_pos == 7'd88 && y_pos == 7'd59) ||
      (x_pos == 7'd89 && y_pos == 7'd59) ||
      (x_pos == 7'd92 && y_pos == 7'd59) ||
      (x_pos == 7'd93 && y_pos == 7'd59) ||
      (x_pos == 7'd66 && y_pos == 7'd60) ||
      (x_pos == 7'd67 && y_pos == 7'd60) ||
      (x_pos == 7'd70 && y_pos == 7'd60) ||
      (x_pos == 7'd71 && y_pos == 7'd60) ||
      (x_pos == 7'd72 && y_pos == 7'd60) ||
      (x_pos == 7'd74 && y_pos == 7'd60) ||
      (x_pos == 7'd75 && y_pos == 7'd60) ||
      (x_pos == 7'd78 && y_pos == 7'd60) ||
      (x_pos == 7'd79 && y_pos == 7'd60) ||
      (x_pos == 7'd81 && y_pos == 7'd60) ||
      (x_pos == 7'd82 && y_pos == 7'd60) ||
      (x_pos == 7'd85 && y_pos == 7'd60) ||
      (x_pos == 7'd86 && y_pos == 7'd60) ||
      (x_pos == 7'd88 && y_pos == 7'd60) ||
      (x_pos == 7'd89 && y_pos == 7'd60) ||
      (x_pos == 7'd92 && y_pos == 7'd60) ||
      (x_pos == 7'd93 && y_pos == 7'd60) ||
      (x_pos == 7'd66 && y_pos == 7'd61) ||
      (x_pos == 7'd67 && y_pos == 7'd61) ||
      (x_pos == 7'd69 && y_pos == 7'd61) ||
      (x_pos == 7'd70 && y_pos == 7'd61) ||
      (x_pos == 7'd71 && y_pos == 7'd61) ||
      (x_pos == 7'd72 && y_pos == 7'd61) ||
      (x_pos == 7'd74 && y_pos == 7'd61) ||
      (x_pos == 7'd75 && y_pos == 7'd61) ||
      (x_pos == 7'd78 && y_pos == 7'd61) ||
      (x_pos == 7'd79 && y_pos == 7'd61) ||
      (x_pos == 7'd81 && y_pos == 7'd61) ||
      (x_pos == 7'd82 && y_pos == 7'd61) ||
      (x_pos == 7'd85 && y_pos == 7'd61) ||
      (x_pos == 7'd86 && y_pos == 7'd61) ||
      (x_pos == 7'd88 && y_pos == 7'd61) ||
      (x_pos == 7'd89 && y_pos == 7'd61) ||
      (x_pos == 7'd92 && y_pos == 7'd61) ||
      (x_pos == 7'd93 && y_pos == 7'd61) ||
      (x_pos == 7'd66 && y_pos == 7'd62) ||
      (x_pos == 7'd67 && y_pos == 7'd62) ||
      (x_pos == 7'd71 && y_pos == 7'd62) ||
      (x_pos == 7'd72 && y_pos == 7'd62) ||
      (x_pos == 7'd74 && y_pos == 7'd62) ||
      (x_pos == 7'd75 && y_pos == 7'd62) ||
      (x_pos == 7'd78 && y_pos == 7'd62) ||
      (x_pos == 7'd79 && y_pos == 7'd62) ||
      (x_pos == 7'd81 && y_pos == 7'd62) ||
      (x_pos == 7'd82 && y_pos == 7'd62) ||
      (x_pos == 7'd85 && y_pos == 7'd62) ||
      (x_pos == 7'd86 && y_pos == 7'd62) ||
      (x_pos == 7'd88 && y_pos == 7'd62) ||
      (x_pos == 7'd89 && y_pos == 7'd62) ||
      (x_pos == 7'd92 && y_pos == 7'd62) ||
      (x_pos == 7'd93 && y_pos == 7'd62) ||
      (x_pos == 7'd66 && y_pos == 7'd63) ||
      (x_pos == 7'd67 && y_pos == 7'd63) ||
      (x_pos == 7'd68 && y_pos == 7'd63) ||
      (x_pos == 7'd71 && y_pos == 7'd63) ||
      (x_pos == 7'd72 && y_pos == 7'd63) ||
      (x_pos == 7'd74 && y_pos == 7'd63) ||
      (x_pos == 7'd75 && y_pos == 7'd63) ||
      (x_pos == 7'd77 && y_pos == 7'd63) ||
      (x_pos == 7'd78 && y_pos == 7'd63) ||
      (x_pos == 7'd79 && y_pos == 7'd63) ||
      (x_pos == 7'd81 && y_pos == 7'd63) ||
      (x_pos == 7'd82 && y_pos == 7'd63) ||
      (x_pos == 7'd84 && y_pos == 7'd63) ||
      (x_pos == 7'd85 && y_pos == 7'd63) ||
      (x_pos == 7'd86 && y_pos == 7'd63) ||
      (x_pos == 7'd88 && y_pos == 7'd63) ||
      (x_pos == 7'd89 && y_pos == 7'd63) ||
      (x_pos == 7'd91 && y_pos == 7'd63) ||
      (x_pos == 7'd92 && y_pos == 7'd63) ||
      (x_pos == 7'd93 && y_pos == 7'd63) ||
      (x_pos == 7'd66 && y_pos == 7'd64) ||
      (x_pos == 7'd67 && y_pos == 7'd64) ||
      (x_pos == 7'd68 && y_pos == 7'd64) ||
      (x_pos == 7'd69 && y_pos == 7'd64) ||
      (x_pos == 7'd70 && y_pos == 7'd64) ||
      (x_pos == 7'd71 && y_pos == 7'd64) ||
      (x_pos == 7'd72 && y_pos == 7'd64) ||
      (x_pos == 7'd74 && y_pos == 7'd64) ||
      (x_pos == 7'd75 && y_pos == 7'd64) ||
      (x_pos == 7'd76 && y_pos == 7'd64) ||
      (x_pos == 7'd77 && y_pos == 7'd64) ||
      (x_pos == 7'd78 && y_pos == 7'd64) ||
      (x_pos == 7'd79 && y_pos == 7'd64) ||
      (x_pos == 7'd81 && y_pos == 7'd64) ||
      (x_pos == 7'd82 && y_pos == 7'd64) ||
      (x_pos == 7'd83 && y_pos == 7'd64) ||
      (x_pos == 7'd84 && y_pos == 7'd64) ||
      (x_pos == 7'd85 && y_pos == 7'd64) ||
      (x_pos == 7'd86 && y_pos == 7'd64) ||
      (x_pos == 7'd88 && y_pos == 7'd64) ||
      (x_pos == 7'd89 && y_pos == 7'd64) ||
      (x_pos == 7'd90 && y_pos == 7'd64) ||
      (x_pos == 7'd91 && y_pos == 7'd64) ||
      (x_pos == 7'd92 && y_pos == 7'd64) ||
      (x_pos == 7'd93 && y_pos == 7'd64) ||
      (x_pos == 7'd67 && y_pos == 7'd65) ||
      (x_pos == 7'd68 && y_pos == 7'd65) ||
      (x_pos == 7'd69 && y_pos == 7'd65) ||
      (x_pos == 7'd70 && y_pos == 7'd65) ||
      (x_pos == 7'd71 && y_pos == 7'd65) ||
      (x_pos == 7'd75 && y_pos == 7'd65) ||
      (x_pos == 7'd76 && y_pos == 7'd65) ||
      (x_pos == 7'd77 && y_pos == 7'd65) ||
      (x_pos == 7'd78 && y_pos == 7'd65) ||
      (x_pos == 7'd82 && y_pos == 7'd65) ||
      (x_pos == 7'd83 && y_pos == 7'd65) ||
      (x_pos == 7'd84 && y_pos == 7'd65) ||
      (x_pos == 7'd85 && y_pos == 7'd65) ||
      (x_pos == 7'd88 && y_pos == 7'd65) ||
      (x_pos == 7'd89 && y_pos == 7'd65) ||
      (x_pos == 7'd90 && y_pos == 7'd65) ||
      (x_pos == 7'd91 && y_pos == 7'd65) ||
      (x_pos == 7'd92 && y_pos == 7'd65)
    )) begin
      colour <= 3'b010;
    end else if ((accuracy == 2'b11) && (  // miss
      (x_pos == 7'd66 && y_pos == 7'd55) ||
      (x_pos == 7'd67 && y_pos == 7'd55) ||
      (x_pos == 7'd73 && y_pos == 7'd55) ||
      (x_pos == 7'd74 && y_pos == 7'd55) ||
      (x_pos == 7'd76 && y_pos == 7'd55) ||
      (x_pos == 7'd77 && y_pos == 7'd55) ||
      (x_pos == 7'd80 && y_pos == 7'd55) ||
      (x_pos == 7'd81 && y_pos == 7'd55) ||
      (x_pos == 7'd82 && y_pos == 7'd55) ||
      (x_pos == 7'd83 && y_pos == 7'd55) ||
      (x_pos == 7'd84 && y_pos == 7'd55) ||
      (x_pos == 7'd85 && y_pos == 7'd55) ||
      (x_pos == 7'd88 && y_pos == 7'd55) ||
      (x_pos == 7'd89 && y_pos == 7'd55) ||
      (x_pos == 7'd90 && y_pos == 7'd55) ||
      (x_pos == 7'd91 && y_pos == 7'd55) ||
      (x_pos == 7'd92 && y_pos == 7'd55) ||
      (x_pos == 7'd93 && y_pos == 7'd55) ||
      (x_pos == 7'd66 && y_pos == 7'd56) ||
      (x_pos == 7'd67 && y_pos == 7'd56) ||
      (x_pos == 7'd68 && y_pos == 7'd56) ||
      (x_pos == 7'd72 && y_pos == 7'd56) ||
      (x_pos == 7'd73 && y_pos == 7'd56) ||
      (x_pos == 7'd74 && y_pos == 7'd56) ||
      (x_pos == 7'd76 && y_pos == 7'd56) ||
      (x_pos == 7'd77 && y_pos == 7'd56) ||
      (x_pos == 7'd79 && y_pos == 7'd56) ||
      (x_pos == 7'd80 && y_pos == 7'd56) ||
      (x_pos == 7'd81 && y_pos == 7'd56) ||
      (x_pos == 7'd82 && y_pos == 7'd56) ||
      (x_pos == 7'd83 && y_pos == 7'd56) ||
      (x_pos == 7'd84 && y_pos == 7'd56) ||
      (x_pos == 7'd85 && y_pos == 7'd56) ||
      (x_pos == 7'd87 && y_pos == 7'd56) ||
      (x_pos == 7'd88 && y_pos == 7'd56) ||
      (x_pos == 7'd89 && y_pos == 7'd56) ||
      (x_pos == 7'd90 && y_pos == 7'd56) ||
      (x_pos == 7'd91 && y_pos == 7'd56) ||
      (x_pos == 7'd92 && y_pos == 7'd56) ||
      (x_pos == 7'd93 && y_pos == 7'd56) ||
      (x_pos == 7'd66 && y_pos == 7'd57) ||
      (x_pos == 7'd67 && y_pos == 7'd57) ||
      (x_pos == 7'd68 && y_pos == 7'd57) ||
      (x_pos == 7'd69 && y_pos == 7'd57) ||
      (x_pos == 7'd71 && y_pos == 7'd57) ||
      (x_pos == 7'd72 && y_pos == 7'd57) ||
      (x_pos == 7'd73 && y_pos == 7'd57) ||
      (x_pos == 7'd74 && y_pos == 7'd57) ||
      (x_pos == 7'd76 && y_pos == 7'd57) ||
      (x_pos == 7'd77 && y_pos == 7'd57) ||
      (x_pos == 7'd79 && y_pos == 7'd57) ||
      (x_pos == 7'd80 && y_pos == 7'd57) ||
      (x_pos == 7'd87 && y_pos == 7'd57) ||
      (x_pos == 7'd88 && y_pos == 7'd57) ||
      (x_pos == 7'd66 && y_pos == 7'd58) ||
      (x_pos == 7'd67 && y_pos == 7'd58) ||
      (x_pos == 7'd69 && y_pos == 7'd58) ||
      (x_pos == 7'd71 && y_pos == 7'd58) ||
      (x_pos == 7'd73 && y_pos == 7'd58) ||
      (x_pos == 7'd74 && y_pos == 7'd58) ||
      (x_pos == 7'd76 && y_pos == 7'd58) ||
      (x_pos == 7'd77 && y_pos == 7'd58) ||
      (x_pos == 7'd79 && y_pos == 7'd58) ||
      (x_pos == 7'd80 && y_pos == 7'd58) ||
      (x_pos == 7'd87 && y_pos == 7'd58) ||
      (x_pos == 7'd88 && y_pos == 7'd58) ||
      (x_pos == 7'd66 && y_pos == 7'd59) ||
      (x_pos == 7'd67 && y_pos == 7'd59) ||
      (x_pos == 7'd69 && y_pos == 7'd59) ||
      (x_pos == 7'd70 && y_pos == 7'd59) ||
      (x_pos == 7'd71 && y_pos == 7'd59) ||
      (x_pos == 7'd73 && y_pos == 7'd59) ||
      (x_pos == 7'd74 && y_pos == 7'd59) ||
      (x_pos == 7'd76 && y_pos == 7'd59) ||
      (x_pos == 7'd77 && y_pos == 7'd59) ||
      (x_pos == 7'd79 && y_pos == 7'd59) ||
      (x_pos == 7'd80 && y_pos == 7'd59) ||
      (x_pos == 7'd81 && y_pos == 7'd59) ||
      (x_pos == 7'd82 && y_pos == 7'd59) ||
      (x_pos == 7'd83 && y_pos == 7'd59) ||
      (x_pos == 7'd84 && y_pos == 7'd59) ||
      (x_pos == 7'd85 && y_pos == 7'd59) ||
      (x_pos == 7'd87 && y_pos == 7'd59) ||
      (x_pos == 7'd88 && y_pos == 7'd59) ||
      (x_pos == 7'd89 && y_pos == 7'd59) ||
      (x_pos == 7'd90 && y_pos == 7'd59) ||
      (x_pos == 7'd91 && y_pos == 7'd59) ||
      (x_pos == 7'd92 && y_pos == 7'd59) ||
      (x_pos == 7'd93 && y_pos == 7'd59) ||
      (x_pos == 7'd66 && y_pos == 7'd60) ||
      (x_pos == 7'd67 && y_pos == 7'd60) ||
      (x_pos == 7'd70 && y_pos == 7'd60) ||
      (x_pos == 7'd73 && y_pos == 7'd60) ||
      (x_pos == 7'd74 && y_pos == 7'd60) ||
      (x_pos == 7'd76 && y_pos == 7'd60) ||
      (x_pos == 7'd77 && y_pos == 7'd60) ||
      (x_pos == 7'd79 && y_pos == 7'd60) ||
      (x_pos == 7'd80 && y_pos == 7'd60) ||
      (x_pos == 7'd81 && y_pos == 7'd60) ||
      (x_pos == 7'd82 && y_pos == 7'd60) ||
      (x_pos == 7'd83 && y_pos == 7'd60) ||
      (x_pos == 7'd84 && y_pos == 7'd60) ||
      (x_pos == 7'd85 && y_pos == 7'd60) ||
      (x_pos == 7'd87 && y_pos == 7'd60) ||
      (x_pos == 7'd88 && y_pos == 7'd60) ||
      (x_pos == 7'd89 && y_pos == 7'd60) ||
      (x_pos == 7'd90 && y_pos == 7'd60) ||
      (x_pos == 7'd91 && y_pos == 7'd60) ||
      (x_pos == 7'd92 && y_pos == 7'd60) ||
      (x_pos == 7'd93 && y_pos == 7'd60) ||
      (x_pos == 7'd66 && y_pos == 7'd61) ||
      (x_pos == 7'd67 && y_pos == 7'd61) ||
      (x_pos == 7'd70 && y_pos == 7'd61) ||
      (x_pos == 7'd73 && y_pos == 7'd61) ||
      (x_pos == 7'd74 && y_pos == 7'd61) ||
      (x_pos == 7'd76 && y_pos == 7'd61) ||
      (x_pos == 7'd77 && y_pos == 7'd61) ||
      (x_pos == 7'd84 && y_pos == 7'd61) ||
      (x_pos == 7'd85 && y_pos == 7'd61) ||
      (x_pos == 7'd92 && y_pos == 7'd61) ||
      (x_pos == 7'd93 && y_pos == 7'd61) ||
      (x_pos == 7'd66 && y_pos == 7'd62) ||
      (x_pos == 7'd67 && y_pos == 7'd62) ||
      (x_pos == 7'd73 && y_pos == 7'd62) ||
      (x_pos == 7'd74 && y_pos == 7'd62) ||
      (x_pos == 7'd76 && y_pos == 7'd62) ||
      (x_pos == 7'd77 && y_pos == 7'd62) ||
      (x_pos == 7'd84 && y_pos == 7'd62) ||
      (x_pos == 7'd85 && y_pos == 7'd62) ||
      (x_pos == 7'd92 && y_pos == 7'd62) ||
      (x_pos == 7'd93 && y_pos == 7'd62) ||
      (x_pos == 7'd66 && y_pos == 7'd63) ||
      (x_pos == 7'd67 && y_pos == 7'd63) ||
      (x_pos == 7'd73 && y_pos == 7'd63) ||
      (x_pos == 7'd74 && y_pos == 7'd63) ||
      (x_pos == 7'd76 && y_pos == 7'd63) ||
      (x_pos == 7'd77 && y_pos == 7'd63) ||
      (x_pos == 7'd79 && y_pos == 7'd63) ||
      (x_pos == 7'd80 && y_pos == 7'd63) ||
      (x_pos == 7'd81 && y_pos == 7'd63) ||
      (x_pos == 7'd82 && y_pos == 7'd63) ||
      (x_pos == 7'd83 && y_pos == 7'd63) ||
      (x_pos == 7'd84 && y_pos == 7'd63) ||
      (x_pos == 7'd85 && y_pos == 7'd63) ||
      (x_pos == 7'd87 && y_pos == 7'd63) ||
      (x_pos == 7'd88 && y_pos == 7'd63) ||
      (x_pos == 7'd89 && y_pos == 7'd63) ||
      (x_pos == 7'd90 && y_pos == 7'd63) ||
      (x_pos == 7'd91 && y_pos == 7'd63) ||
      (x_pos == 7'd92 && y_pos == 7'd63) ||
      (x_pos == 7'd93 && y_pos == 7'd63) ||
      (x_pos == 7'd66 && y_pos == 7'd64) ||
      (x_pos == 7'd67 && y_pos == 7'd64) ||
      (x_pos == 7'd73 && y_pos == 7'd64) ||
      (x_pos == 7'd74 && y_pos == 7'd64) ||
      (x_pos == 7'd76 && y_pos == 7'd64) ||
      (x_pos == 7'd77 && y_pos == 7'd64) ||
      (x_pos == 7'd79 && y_pos == 7'd64) ||
      (x_pos == 7'd80 && y_pos == 7'd64) ||
      (x_pos == 7'd81 && y_pos == 7'd64) ||
      (x_pos == 7'd82 && y_pos == 7'd64) ||
      (x_pos == 7'd83 && y_pos == 7'd64) ||
      (x_pos == 7'd84 && y_pos == 7'd64) ||
      (x_pos == 7'd87 && y_pos == 7'd64) ||
      (x_pos == 7'd88 && y_pos == 7'd64) ||
      (x_pos == 7'd89 && y_pos == 7'd64) ||
      (x_pos == 7'd90 && y_pos == 7'd64) ||
      (x_pos == 7'd91 && y_pos == 7'd64) ||
      (x_pos == 7'd92 && y_pos == 7'd64)
    )) begin
      colour <= 3'b001;
    end else begin
      colour <= 3'b000;
    end

    x[6:0] <= x_pos[6:0];
    y[6:0] <= y_pos[6:0];

    position <= position + 1'b1;
  end
endmodule

module clock_8hz(clk, out);
  // 8 hz clock
  input clk;
  output reg out=1'b0;

  reg [22:0] counter=23'b0;
  always @(posedge clk) begin
    counter <= counter + 1'b1;
    if (counter[22:0]==23'b10111110101111000010000) begin
      out <= 1'b1;
      counter <= 23'b0;
    end else begin
      out <= 1'b0;
    end
  end
endmodule

module hex_accuracy(accuracy, hex);
  // hex display of P/G/F
  input [1:0] accuracy;
  output [6:0] hex;

  wire a, b;
  assign a = accuracy[1];
  assign b = accuracy[0];

  assign hex[0] = ~(a || b);
  assign hex[1] = ~(~a && b);
  assign hex[2] = ~(a && ~b);
  assign hex[3] = ~(a && ~b);
  assign hex[4] = ~(a || b);
  assign hex[5] = ~(a || b);
  assign hex[6] = ~(b);
endmodule

module hex0(m0, m1, m2, m3, hex0);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex0; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex0 = (~m3&~m2&~m1&m0) | (~m3&m2&~m1&~m0) | (m3&m2&~m1&m0) | (m3&~m2&m1&m0);
endmodule

module hex1(m0, m1, m2, m3, hex1);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex1; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex1 = (~m3&m2&~m1&m0) | (m3&m1&m0) | (m2&m1&~m0) | (m3&m2&~m0);
endmodule

module hex2(m0, m1, m2, m3, hex2);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex2; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex2 = (m3&m2&m1) | (m3&m2&~m0) | (~m3&~m2&m1&~m0);
endmodule

module hex3(m0, m1, m2, m3, hex3);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex3; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex3 = (m2&m1&m0) | (~m3&~m2&~m1&m0) | (~m3&m2&~m1&~m0) | (m3&~m2&m1&~m0);
endmodule

module hex4(m0, m1, m2, m3, hex4);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex4; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex4 = (~m3&m0) | (~m3&m2&~m1) | (~m2&~m1&m0);
endmodule

module hex5(m0, m1, m2, m3, hex5);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex5; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex5 = (m3&m2&~m1&m0) | (~m3&~m2&m0) | (~m3&~m2&m1) | (~m3&m1&m0);
endmodule

module hex6(m0, m1, m2, m3, hex6);
  input m0, m1, m2, m3; // Declaration of input switches
  output hex6; // Declaration of output hex segment

  // Assign corresponding boolean expresstion to the variable representing hex segment.
  // Note: the segment is lit up when value is set low.
  assign hex6 = (~m3&m2&m1&m0) | (m3&m2&~m1&~m0) | (~m3&~m2&~m1);
endmodule


module hex(hex_display, signals);
    input [3:0] signals; // Declaration of input signalsitches
    output [6:0] hex_display; // Declaration of 7 output hex segments

    // Bind input and output to signal switches and segments
    hex0(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex0(hex_display[0])
    );

    hex1(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex1(hex_display[1])
    );

    hex2(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex2(hex_display[2])
    );

    hex3(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex3(hex_display[3])
    );

    hex4(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex4(hex_display[4])
    );

    hex5(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex5(hex_display[5])
    );

    hex6(.m0(signals[0]),
        .m1(signals[1]),
        .m2(signals[2]),
        .m3(signals[3]),
        .hex6(hex_display[6])
    );
endmodule
