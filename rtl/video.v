
module video(

  input clk_vid,
  input  [1:0] rotate,
  input        half_size,

  output ce_pxl,

  output hsync,
  output vsync,
  output hblank,
  output vblank,
  output reg [7:0] red,
  output reg [7:0] green,
  output reg [7:0] blue,

  output [18:0] addr,
  input [15:0] din

);

reg [9:0] hcount = 10'd0;
reg [9:0] vcount = 10'd0;

// Timing for 640 x 480 @ 60 Hz (25.175 MHz)
wire rot_90   = (rotate == 2'd1);
wire rot_270  = (rotate == 2'd3);
wire portrait = rot_90 | rot_270;

wire [9:0] H_ACTIVE = portrait ? 10'd480 : 10'd640;
wire [9:0] V_ACTIVE = portrait ? 10'd640 : 10'd480;

wire [9:0] H_FP     = 10'd16;
wire [9:0] H_SYNC   = 10'd96;
wire [9:0] H_BP     = 10'd48;

wire [9:0] V_FP     = 10'd10;
wire [9:0] V_SYNC   = 10'd2;
wire [9:0] V_BP     = 10'd33;

wire [9:0] H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;
wire [9:0] V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

wire [9:0] IMG_W    = H_ACTIVE >> 1;
wire [9:0] IMG_H    = V_ACTIVE >> 1;
wire [9:0] X_OFF    = H_ACTIVE >> 2;
wire [9:0] Y_OFF    = V_ACTIVE >> 2;

wire in_half_window =
  (hcount >= X_OFF) && (hcount < (X_OFF + IMG_W)) &&
  (vcount >= Y_OFF) && (vcount < (Y_OFF + IMG_H));

wire draw_pixel = !hblank && !vblank && (!half_size || in_half_window);

wire [9:0] dst_x = half_size ? ((hcount - X_OFF) << 1) : hcount;
wire [9:0] dst_y = half_size ? ((vcount - Y_OFF) << 1) : vcount;

// ---------------------------------------------------------------------------
// Sync / blank
// ---------------------------------------------------------------------------

assign hblank = (hcount >= H_ACTIVE);
assign vblank = (vcount >= V_ACTIVE);

assign hsync  = ~((hcount >= (H_ACTIVE + H_FP)) &&
                  (hcount <  (H_ACTIVE + H_FP + H_SYNC)));

assign vsync  = ~((vcount >= (V_ACTIVE + V_FP)) &&
                  (vcount <  (V_ACTIVE + V_FP + V_SYNC)));

assign ce_pxl = hcount[0];

reg [9:0] src_x;
reg [9:0] src_y;

always @(*) begin
  src_x = 10'd0;
  src_y = 10'd0;

  if (draw_pixel) begin
    case (rotate)
      2'd1: begin
        // 90 CW
        src_x = dst_y;
        src_y = 10'd479 - dst_x;
      end

      2'd2: begin
        // 180
        src_x = 10'd639 - dst_x;
        src_y = 10'd479 - dst_y;
      end

      2'd3: begin
        // 270 CCW
        src_x = 10'd639 - dst_y;
        src_y = dst_x;
      end

      default: begin
        // None
        src_x = dst_x;
        src_y = dst_y;
      end
    endcase
  end
end

assign addr = draw_pixel ? (src_y * 10'd640 + src_x) : 19'd0;

always @(posedge clk_vid) begin
  if (draw_pixel)
    { red, green, blue } <= { { din[7:5], 5'd0 }, { din[4:2], 5'd0 }, { din[1:0], 6'd0 } };
  else
    { red, green, blue } <= 24'd0;
end

always @(posedge clk_vid) begin
  if (hcount == (H_TOTAL - 10'd1)) begin
    hcount <= 10'd0;

    if (vcount == (V_TOTAL - 10'd1))
      vcount <= 10'd0;
    else
      vcount <= vcount + 10'd1;
  end
  else begin
    hcount <= hcount + 10'd1;
  end
end


endmodule