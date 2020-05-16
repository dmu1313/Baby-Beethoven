
module sigmoid_rom
(
    input [2:0] index,
    output [31:0] slope,
    output [31:0] intercept
);
// y = 0.22183988893975287 * x + 0.5                      // y = 0x3e6329ff * x + 0x3f000000
// y = 0.12735067392619948 * x + 0.6181115187669417       // y = 0x3e026837 * x + 0x3f1e3c8e
// y = 0.05282978731820247 * x + 0.785783513634935        // y = 0x3d58640c * x + 0x3f49291c
// y = 0.015079586551381086 * x + 0.9179092163188098      // y = 0x3c77105f * x + 0x3f6afc19
// y = 1                                                  // y = 0 * x + 0x3f800000
    localparam logic [0:4][31:0] piecewise_slope =
    {
        32'h3e6329ff,
        32'h3e026837,
        32'h3d58640c,
        32'h3c77105f,
        32'h00000000
    };

    localparam logic [0:4][31:0] piecewise_intercept =
    {
        32'h3f000000,
        32'h3f1e3c8e,
        32'h3f49291c,
        32'h3f6afc19,
        32'h3f800000
    };
    assign slope = piecewise_slope[index];
    assign intercept = piecewise_intercept[index];
endmodule

module tanh_rom
(
    input [2:0] index,
    output [31:0] intercept,
    output [31:0] slope
);
// y = 0.8468652698497164 * x + 0.0
// y = 0.3599990683434388 * x + 0.3651496511297082
// y = 0.06936917673867304 * x + 0.8010944885368568
// y = 0.0035775465308388477 * x + 0.9820214716084009
// y = 1
    localparam logic [0:4][31:0] piecewise_slope =
    {
        32'h3f58cc2a,
        32'h3eb851cc,
        32'h3d8e116d,
        32'h3b6a7545,
        32'h00000000
    };
    localparam logic [0:4][31:0] piecewise_intercept =
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



// ps_control[0] = 1, means sigmoid
// ps_control[1] = 1, means tanh
module activation
#(
    ADDR_WIDTH = 12,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    NUM_WORDS = 512
)
(
    input clk,
    input reset,
    
    input  [31:0] ps_control,
    output [31:0] pl_status,
    
    output [ADDR_WIDTH-1:0] bram_addr_in,
    input  [BRAM_WIDTH-1:0] bram_rddata_in,
    output [BRAM_WIDTH-1:0] bram_wrdata_in,
    output [WORD_BYTES-1:0] bram_we_in,
    
    output [ADDR_WIDTH-1:0] bram_addr_out,
    input  [BRAM_WIDTH-1:0] bram_rddata_out,
    output [BRAM_WIDTH-1:0] bram_wrdata_out,
    output [WORD_BYTES-1:0] bram_we_out
);
    logic done;
    logic inc;
    logic clear;

    logic is_sigmoid;
    assign is_sigmoid = (ps_control[0] == 1) ? 1 : 0;

    assign bram_we_in = 0;
    assign bram_wrdata_in = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;

    activation_datapath #(.NUM_WORDS(NUM_WORDS)) d(
        .clk,
        .reset,
        
        .bram_addr_in,
        .bram_rddata_in,
                
        .bram_addr_out,
        .bram_wrdata_out,
        
        .done,
        .inc,
        .clear,
        .is_sigmoid
    );
    
    activation_control c(
        .clk,
        .reset,
        
        .ps_control,
        .pl_status,
        
        .bram_we_out,
        
        .done,
        .inc,
        .clear
    );
endmodule

module activation_datapath
#(
    FP_WIDTH = 32,
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12,
    NUM_WORDS = 512
)
(
    input clk,
    input reset,
    
    output [ADDR_WIDTH-1:0] bram_addr_in,
    input  [BRAM_WIDTH-1:0] bram_rddata_in,

    output [ADDR_WIDTH-1:0] bram_addr_out,
    output [BRAM_WIDTH-1:0] bram_wrdata_out,
    
    output done,
    input inc,
    input clear,
    input is_sigmoid
);
    localparam logic [31:0] sig_flip = 32'h3f800000; // 1.0
    localparam logic [31:0] tanh_flip = 32'h00000000; // 0.0

    localparam NUM_LINES = 5;
    localparam logic [0:NUM_LINES-1][31:0] sigmoid_bounds =
        { 32'h00000000,     // 0
          32'h3fa00000,     // 1.25
          32'h40100000,     // 2.25
          32'h40600000,     // 3.5
          32'h40a00000      // 5
        };
    localparam logic [0:NUM_LINES-1][31:0] tanh_bounds =
        { 32'h00000000,     // 0
          32'h3f400000,     // 0.75
          32'h3fc00000,     // 1.5
          32'h40300000,     // 2.75
          32'h40a00000      // 5
        };        
    logic [0:NUM_LINES-1][31:0] bounds;
    logic [0:NUM_LINES-1][31:0] comparison_results;
    logic [2:0] sel_piecewise;

    logic [31:0] slope, tanh_slope, sig_slope;
    logic [31:0] intercept, tanh_intercept, sig_intercept;
    logic [31:0] abs_out;
    logic [31:0] mult_out;
    logic [31:0] adder_out;
    logic [31:0] sub_out;
    logic [31:0] is_negative;
    logic [31:0] final_result;

    logic [ADDR_WIDTH-1:0]  counter;
    logic [ADDR_WIDTH-1:0] wr_addr;
    
    assign done = counter == ((NUM_WORDS-1) * 4);
    assign bram_addr_in = counter;
    assign bram_addr_out = wr_addr;
    assign bram_wrdata_out = final_result;

    fp_abs abs (
        .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(bram_rddata_in),              // input wire [31 : 0] s_axis_a_tdata
        .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(abs_out)    // output wire [31 : 0] m_axis_result_tdata
    );

    // We know that the absolute value of the input has to be >= 0. Instead, use this to determine if the
    // original input was >= 0.
    fp_comp comp_0(
        .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(bram_rddata_in),              // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(bounds[0]),              // input wire [31 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(comparison_results[0])    // output wire [31 : 0] m_axis_result_tdata
    );

    generate
        genvar i;
        for (i = 1; i < NUM_LINES; i++) begin
            assign bounds[i] = (is_sigmoid) ? sigmoid_bounds[i] : tanh_bounds[i];

            fp_comp comp(
                .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
                .s_axis_a_tdata(abs_out),              // input wire [31 : 0] s_axis_a_tdata
                .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
                .s_axis_b_tdata(bounds[i]),              // input wire [31 : 0] s_axis_b_tdata
                .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
                .m_axis_result_tdata(comparison_results[i])    // output wire [31 : 0] m_axis_result_tdata
            );
        end
    endgenerate
    
    always_comb begin
        if (comparison_results[4][0]) begin
            sel_piecewise = 4;
        end
        else if (comparison_results[3][0]) begin
            sel_piecewise = 3;
        end
        else if (comparison_results[2][0]) begin
            sel_piecewise = 2;
        end
        else if (comparison_results[1][0]) begin
            sel_piecewise = 1;
        end
        else begin
            sel_piecewise = 0;
        end
    end

    sigmoid_rom sig_rom (
        .index(sel_piecewise),
        .slope(sig_slope),
        .intercept(sig_intercept)
    );
    tanh_rom t_rom(
        .index(sel_piecewise),
        .slope(tanh_slope),
        .intercept(tanh_intercept)
    );

    assign slope = (is_sigmoid) ? sig_slope : tanh_slope;
    assign intercept = (is_sigmoid) ? sig_intercept : tanh_intercept;

    act_fp_mult fp_mult (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(slope),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(abs_out),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(mult_out)    // output wire [31 : 0] m_axis_result_tdata
    );

    act_fp_add fp_add (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(mult_out),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(intercept),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(adder_out)    // output wire [31 : 0] m_axis_result_tdata
    );

    // 1 - sig(x)
    // 0 - tanh(x)
    logic [31:0] sub_a_in;
    assign sub_a_in = (is_sigmoid) ? sig_flip : tanh_flip;

    fp_sub sub (
        .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
        .s_axis_a_tdata(sub_a_in),              // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
        .s_axis_b_tdata(adder_out),              // input wire [31 : 0] s_axis_b_tdata
        .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
        .m_axis_result_tdata(sub_out)    // output wire [31 : 0] m_axis_result_tdata
    );

    // If input >= 0
    assign final_result = (comparison_results[0][0] == 1) ? adder_out : sub_out;

    always_ff @(posedge clk) begin
        if (reset)
            wr_addr <= 0;
        else
            wr_addr <= counter;
    
        if (clear)
            counter <= 0;
        else if (inc)
            counter <= counter + 4;
    end
endmodule

typedef enum bit[2:0] {
    WAIT_TO_START   = 0,
    START_A         = 1,
    LOOP_A          = 2,
    DONE_A          = 3,
    WAIT_FOR_ACK    = 4
} activation_states;

module activation_control
#(
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)
(
    input clk,
    input reset,
    
    input  [31:0] ps_control,
    output [31:0] pl_status,
    
    output [WORD_BYTES-1:0] bram_we_out,
    
    input  done,    
    output inc,
    output clear
);
    logic [2:0] state;
    logic [2:0] next_state;
    
    assign pl_status[0] = (state == WAIT_FOR_ACK);
    assign inc = state == START_A || state == LOOP_A;
    assign clear = state == WAIT_TO_START;
    
    assign bram_we_out = (state == LOOP_A || state == DONE_A) ? 4'b1111 : 4'b0000;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= WAIT_TO_START;
        end
        else begin
            state <= next_state;
        end
    end

    always_comb begin
        if (state == WAIT_TO_START) begin
            if (ps_control[0] == 1 || ps_control[1] == 1) begin
                next_state = START_A;
            end
            else begin
                next_state = WAIT_TO_START;
            end
        end
        
        else if (state == START_A) begin
            next_state = LOOP_A;
        end
        else if (state == LOOP_A) begin
            if (done)
                next_state = DONE_A;
            else
                next_state = LOOP_A;
        end
        else if (state == DONE_A) begin
            next_state = WAIT_FOR_ACK;
        end
        else if (state == WAIT_FOR_ACK) begin
            if (ps_control == 0)
                next_state = WAIT_TO_START;
            else
                next_state = WAIT_FOR_ACK;
        end
        else begin
            next_state = WAIT_TO_START;
        end
    end
endmodule
