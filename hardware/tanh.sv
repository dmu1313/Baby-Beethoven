
module tanh
#(
    FLOAT_WIDTH = 31,
    LOG_FLOAT_WIDTH = 5
)
(
    input clk,
    input [FLOAT_WIDTH-1:0] x,

    output [FLOAT_WIDTH-1:0] y
);

    // ROM

    

    



endmodule


module tanh_params_rom
(
    input clk,
    input reset,
    input [2:0] index,
    output [31:0] intercept
    output [31:0] slope,
);
// y = 0.8468652698497164 * x + 0.0
// y = 0.3599990683434388 * x + 0.3651496511297082
// y = 0.06936917673867304 * x + 0.8010944885368568
// y = 0.0035775465308388477 * x + 0.9820214716084009
// y = 1
    localparam logic [0:3][31:0] piecewise_slope =
    {
        32'h3f58cc2a,
        32'h3eb851cc,
        32'h3d8e116d,
        32'h3b6a7545,
        32'h00000000
    };
    localparam logic [0:3][31:0] piecewise_intercept =
    {
        32'h00000000,
        32'h3ebaf4e5,
        32'h3f4d1487,
        32'h3f7b65c2,
        32'h3f800000
    };
    assign slope = piecewise_slope[index];
    assign intercept = piecewise_intercept[index];
endmodule
