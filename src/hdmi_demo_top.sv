`define GW_IDE
module hdmi_demo_top
(
  input clk,
  input resetn,

  output reg [5:0] led,    // 6 LEDS pin

  // HDMI
  output [2:0] tmds_p,
  output [2:0] tmds_n,
  output tmds_clock_p,
  output tmds_clock_n

);

wire clk_pixel_x5;
wire clk_pixel;
wire clk_audio;

Gowin_rPLL u_pll (
  .clkin(clk),
  .clkout(clk_pixel_x5),
  .lock(pll_lock)
);

Gowin_CLKDIV u_div_5 (
    .clkout(clk_pixel),
    .hclkin(clk_pixel_x5),
    .resetn(pll_lock)
);

Reset_Sync u_Reset_Sync (
  .resetn(sys_resetn),
  .ext_reset(resetn & pll_lock),
  .clk(clk_pixel)
);
 

logic [10:0] counter = 1'd0;
always_ff @(posedge clk_pixel)
begin
    counter <= counter == 11'd1546 ? 1'd0 : counter + 1'd1;
end
assign clk_audio = clk_pixel && counter == 11'd1546;

localparam AUDIO_BIT_WIDTH = 16;
localparam AUDIO_RATE = 48000;
localparam WAVE_RATE = 480;

logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word;
logic [AUDIO_BIT_WIDTH-1:0] audio_sample_word_dampened; // This is to avoid giving you a heart attack -- it'll be really loud if it uses the full dynamic range.
assign audio_sample_word_dampened = audio_sample_word >> 9;

sawtooth #(.BIT_WIDTH(AUDIO_BIT_WIDTH), .SAMPLE_RATE(AUDIO_RATE), .WAVE_RATE(WAVE_RATE)) sawtooth (.clk_audio(clk_audio), .level(audio_sample_word));

wire [2:0] tmds_x;
wire tmds_clock_x;

logic [23:0] rgb;
logic [9:0] cx, cy;
//logic [2:0] tmds;
//logic tmds_clock;
hdmi #(.VIDEO_ID_CODE(1),
    .VIDEO_REFRESH_RATE(60.0),
    .AUDIO_RATE(AUDIO_RATE),
    .DVI_OUTPUT(0),
    .AUDIO_BIT_WIDTH(AUDIO_BIT_WIDTH))
    hdmi(.clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .reset(!sys_resetn),
    //.clk_audio(clk_audio),
    .rgb(rgb),
    //.audio_sample_word('{audio_sample_word_dampened, audio_sample_word_dampened}),
    .tmds(tmds_x),
    .tmds_clock(tmds_clock_x),
    .cx(cx),
    .cy(cy));

/*
ELVDS_OBUF tmds [2:0] (
  .O(tmds_p),
  .OB(tmds_n),
  .I(tmds_x)
);

ELVDS_OBUF tmds_clock(
  .O(tmds_clock_p),
  .OB(tmds_clock_n),
  .I(tmds_clock_x)
);
*/

ELVDS_OBUF tmds_bufds[3:0] (
    .I ({tmds_clock_x, tmds_x}),
    .O ({tmds_clock_p, tmds_p}),
    .OB({tmds_clock_n, tmds_n})
);


logic [7:0] character = 8'h30;
logic [5:0] prevcy = 6'd0;
always @(posedge clk_pixel)
begin
    if (cy == 10'd0)
    begin
        character <= 8'h30;
        prevcy <= 6'd0;
    end
    else if (prevcy != cy[9:4])
    begin
        character <= character + 8'h01;
        prevcy <= cy[9:4];
    end
end

console console(.clk_pixel(clk_pixel), .codepoint(character), .attribute({cx[9], cy[8:6], cx[8:5]}), .cx(cx), .cy(cy), .rgb(rgb));
endmodule

module Reset_Sync (
 input clk,
 input ext_reset,
 output resetn
);

 reg [3:0] reset_cnt = 0;
 
 always @(posedge clk or negedge ext_reset) begin
     if (~ext_reset)
         reset_cnt <= 4'b0;
     else
         reset_cnt <= reset_cnt + !resetn;
 end
 
 assign resetn = &reset_cnt;

endmodule