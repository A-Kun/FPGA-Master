module project(CLOCK_50, LEDR, KEY, HEX0, HEX1, HEX2, HEX3, HEX5, SW, LEDG, GPIO,
  The ports below are for the VGA output.  Do not change.
  VGA_CLK,               //  VGA Clock
  VGA_HS,              //  VGA H_SYNC
  VGA_VS,              //  VGA V_SYNC
  VGA_BLANK_N,            //  VGA BLANK
  VGA_SYNC_N,            //  VGA SYNC
  VGA_R,               //  VGA Red[9:0]
  VGA_G,               //  VGA Green[9:0]
  VGA_B               //  VGA Blue[9:0]
  );
  output [6:0] HEX0, HEX1, HEX2, HEX3, HEX5;
  input [1:0] KEY;
  input CLOCK_50;
  output [9:0] LEDR;
  input [0:0] SW;

  input [0:0] GPIO;
  output [0:0] LEDG;

  wire push_key;
  assign push_key = GPIO[0];

  assign LEDG[0] = GPIO[0];

  wire [9:0] led;
  wire clk_8hz;
  wire if_shift;

  wire [7:0] combo;
  wire [7:0] score;

  wire [1:0] accuracy;

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

  // wire [3:0] counter;
  // DisplayCounter dc(
  //   .clear(KEY[0]),
  //   .enable(clk_4hz),
  //   .count(counter[3:0]));

  hex combo_lower(
    .hex_display(HEX0[6:0]),
    .signals(combo[3:0]));

  hex combo_higher(
    .hex_display(HEX1[6:0]),
    .signals(combo[7:4]));

  hex score_lower(
    .hex_display(HEX2[6:0]),
    .signals(score[3:0]));

  hex score_higher(
    .hex_display(HEX3[6:0]),
    .signals(score[7:4]));

  hex_accuracy teaching_assistant(
    .hex(HEX5),
    .accuracy(accuracy));

  // just for test, have no meaning at all
  localparam RHYTHM_MAP=191'b0000000100010000000001000001000000100101100000000000000001100001000000100000000000010000000100000001000000000000000000000001000100001000010000000001100000000000010100000000010000000001000001;

  clock_8hz apple_watch (
    .clk(CLOCK_50),
    .out(clk_8hz));

  control richard_pancer(
    .clk(CLOCK_50),
    .start(KEY[0]),
    .rst(SW[0]),
    .enable_shift(if_shift));

  datapath sweatshop(
    .clk_8(clk_8hz),
    .clk_50m(CLOCK_50),
    .load(KEY[0]),
    .rst(SW[0]),
    .button(push_key),
    .is_start(if_shift),
    .init_rhythm_map(RHYTHM_MAP),
    .rhythm_shifter_out(led[9:0]),
    .combo(combo[7:0]),
    .score(score[7:0]),
    .accuracy(accuracy),
    .x(x),
    .y(y),
    .colour(colour)
  );
endmodule

module control(clk, start, rst, enable_shift);
  input clk, start, rst;
  output enable_shift;

  reg [2:0] current_state, next_state;

  localparam WAIT_TO_START = 2'b00,
  GAMING = 2'b01;

  assign enable_shift = (current_state == GAMING) ? 1'b1 : 1'b0;

  always @ (*)
  begin: state_table
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
    else
      begin
        current_state <= next_state;
      end
  end
endmodule

module datapath(clk_8, clk_50m, load, button, is_start, rst, init_rhythm_map, rhythm_shifter_out, combo, score, accuracy, x, y, colour);
  input clk_8, clk_50m, is_start, rst, load, button;
  input [190:0] init_rhythm_map;
  reg [190:0] rhythm_shifter;
  output wire [9:0] rhythm_shifter_out;
  output reg [7:0] combo = 8'b0;
  output reg [7:0] score = 8'b0;
  output reg [1:0] accuracy = 2'b0;
  reg button_last_state = 1'b1;
  output reg [7:0] x = 8'b0;
  output reg [6:0] y = 7'b0;
  output reg [2:0] colour = 3'b0;

  assign rhythm_shifter_out[9:0] = rhythm_shifter[11:2];

  reg [14:0] position = 15'b0;
  reg [6:0] x_pos = 3'b0;
  reg [6:0] y_pos = 3'b0;

  always @(posedge clk_50m) begin
    if (!rst) begin
      // reset
      rhythm_shifter <= 191'd0;
      score <= 8'b0;
      combo <= 8'b0;
    end
    else begin
      if (!load) begin
        rhythm_shifter <= init_rhythm_map;
        score <= 8'b0;
        combo <= 8'b0;
      end
      else if (clk_8 == 1'b1) begin
        rhythm_shifter <= rhythm_shifter >> 1;
      end
    end

// 00: n/a, 01: perfect, 10: good, 11: miss
  if (button == 1'b0 && button_last_state == 1'b1) begin
    if (rhythm_shifter[1] == 1'b1) begin
      rhythm_shifter[1] <= 1'b0;
      accuracy <= 2'b10;
      score <= score + 8'd1;
      combo <= combo + 8'd1;
    end else if (rhythm_shifter[2] == 1'b1) begin
      rhythm_shifter[2] <= 1'b0;
      accuracy <= 2'b01;
      score <= score + 8'd2;
      combo <= combo + 8'd1;
    end else if (rhythm_shifter[3] == 1'b1) begin
      rhythm_shifter[3] <= 1'b0;
      accuracy <= 2'b10;
      score <= score + 8'd1;
      combo <= combo + 8'd1;
    end else begin
      accuracy <= 2'b00;
    end
  end

  if (rhythm_shifter[0] == 1'b1) begin
    combo <= 1'b0;
    accuracy <= 2'b11;
  end

  button_last_state <= button;
end

  always @(posedge clk_50m) begin
    if (position == 15'b100000000000000) begin
      position <= 15'b0;
    end

    if (x_pos < 7'd8 && y_pos < 7'd8 && !rhythm_shifter[1]) begin
      colour <= 3'b100;
    end
    else if ((y_pos < 7'd8) && (rhythm_shifter[x_pos + 1'b1])) begin  // TODO: Map rhythm_shifter to VGA
        colour <= 3'b111;
    end
    else if ((y_pos < 7'd8) && (!rhythm_shifter[x_pos + 1'b1])) begin  // TODO: Map rhythm_shifter to VGA
        colour <= 3'b000;
    end
    else if ((accuracy == 2'b01) && (  // perfect  // TODO: Map bitmap to pixels
      (x_pos == 3'd1 && y_pos != 3'd0) ||
      (x_pos == 3'd2) ||
      (x_pos == 3'd3 && y_pos == 3'd0) ||
      (x_pos == 3'd3 && y_pos == 3'd1) ||
      (x_pos == 3'd3 && y_pos == 3'd4) ||
      (x_pos == 3'd3 && y_pos == 3'd5) ||
      (x_pos == 3'd4 && y_pos == 3'd0) ||
      (x_pos == 3'd4 && y_pos == 3'd1) ||
      (x_pos == 3'd4 && y_pos == 3'd4) ||
      (x_pos == 3'd4 && y_pos == 3'd5) ||
      (x_pos == 3'd5 && y_pos == 3'd0) ||
      (x_pos == 3'd5 && y_pos == 3'd1) ||
      (x_pos == 3'd5 && y_pos == 3'd2) ||
      (x_pos == 3'd5 && y_pos == 3'd3) ||
      (x_pos == 3'd5 && y_pos == 3'd4) ||
      (x_pos == 3'd5 && y_pos == 3'd5) ||
      (x_pos == 3'd6 && y_pos == 3'd1) ||
      (x_pos == 3'd6 && y_pos == 3'd2) ||
      (x_pos == 3'd6 && y_pos == 3'd3) ||
      (x_pos == 3'd6 && y_pos == 3'd4)
    )) begin
      colour <= 3'b100;
    end
    else if ((accuracy == 2'b10) && (  // good  // TODO: Map bitmap to pixels
      (x_pos == 3'd1 && y_pos == 3'd1) ||
      (x_pos == 3'd1 && y_pos == 3'd2) ||
      (x_pos == 3'd1 && y_pos == 3'd3) ||
      (x_pos == 3'd1 && y_pos == 3'd4) ||
      (x_pos == 3'd1 && y_pos == 3'd5) ||
      (x_pos == 3'd1 && y_pos == 3'd6) ||
      (x_pos == 3'd2 && y_pos == 3'd0) ||
      (x_pos == 3'd2 && y_pos == 3'd7) ||
      (x_pos == 3'd3 && y_pos == 3'd0) ||
      (x_pos == 3'd3 && y_pos == 3'd7) ||
      (x_pos == 3'd4 && y_pos == 3'd0) ||
      (x_pos == 3'd4 && y_pos == 3'd4) ||
      (x_pos == 3'd4 && y_pos == 3'd7) ||
      (x_pos == 3'd5 && y_pos == 3'd0) ||
      (x_pos == 3'd5 && y_pos == 3'd4) ||
      (x_pos == 3'd5 && y_pos == 3'd5) ||
      (x_pos == 3'd5 && y_pos == 3'd6) ||
      (x_pos == 3'd6 && y_pos == 3'd4)
    )) begin
      colour <= 3'b010;
    end
    else if ((accuracy == 2'b11) && (  // miss  // TODO: Map bitmap to pixels
      (x_pos == 3'd1) ||
      (x_pos == 3'd2) ||
      (x_pos == 3'd3 && y_pos == 3'd0) ||
      (x_pos == 3'd3 && y_pos == 3'd1) ||
      (x_pos == 3'd3 && y_pos == 3'd3) ||
      (x_pos == 3'd3 && y_pos == 3'd4) ||
      (x_pos == 3'd4 && y_pos == 3'd0) ||
      (x_pos == 3'd4 && y_pos == 3'd1) ||
      (x_pos == 3'd4 && y_pos == 3'd3) ||
      (x_pos == 3'd4 && y_pos == 3'd4) ||
      (x_pos == 3'd5 && y_pos == 3'd0) ||
      (x_pos == 3'd5 && y_pos == 3'd1) ||
      (x_pos == 3'd5 && y_pos == 3'd3) ||
      (x_pos == 3'd5 && y_pos == 3'd4) ||
      (x_pos == 3'd6 && y_pos == 3'd0) ||
      (x_pos == 3'd6 && y_pos == 3'd1) ||
      (x_pos == 3'd6 && y_pos == 3'd3) ||
      (x_pos == 3'd6 && y_pos == 3'd4)
    )) begin
      colour <= 3'b001;
    end
    else begin
      colour <= 3'b000;
    end

    x_pos[6:0] <= position[13:7];
    y_pos[6:0] <= position[6:0];

    position <= position + 1'b1;
  end
endmodule

module clock_8hz(clk, out);
  input clk;
  output reg out=1'b0;

  reg [22:0] counter=23'b0;
  always @(posedge clk) begin
    counter <= counter + 1'b1;
    if (counter[22:0]==23'b10111110101111000010000) begin
      out <= 1'b1;
      counter <= 23'b0;
    end
    else begin
      out <= 1'b0;
    end
  end
endmodule

module hex_accuracy(accuracy, hex);
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
