
module sigmoid
#(
    FLOAT_WIDTH = 32,
    LOG_FLOAT_WIDTH = 5,
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

    assign bram_we_in = 0;
    assign bram_wrdata_in = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;

    sig_datapath #(.NUM_WORDS(NUM_WORDS)) d(
        .clk,
        .reset,
        
        .bram_addr_in,
        .bram_rddata_in,
                
        .bram_addr_out,
        .bram_wrdata_out,
        
        .done,
        .inc,
        .clear
    );
    
    sig_control c(
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

module sigmoid_rom
(
    input [1:0] index,
    output [31:0] slope,
    output [31:0] intercept
);
    // y = 0.2117163174624291 * x + 0.5
    // y = 0.08999976708585981 * x + 0.6825748255648539
    // y = 0.02036651112664095 * x + 0.8914745934425106
    // y = 1
    localparam logic [0:3][31:0] piecewise_slope =
    {
        32'h3e58cc2a,
        32'h3db851cc,
        32'h3ca6d7ab,
        32'h00000000
    };

    localparam logic [0:3][31:0] piecewise_intercept =
    {
        32'h3f000000,
        32'h3f2ebd39,
        32'h3f6437ae,
        32'h3f800000
    };
    assign slope = piecewise_slope[index];
    assign intercept = piecewise_intercept[index];
endmodule

module sigmoid_datapath
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
    input clear
);
    // 0   <= y <= 1.5
    // 1.5  < y <= 3
    // 3    < y <= 5
    // 5    < y
    localparam NUM_LINES = 4;
    localparam logic [0:3][31:0] piecewise_bounds =
        { 32'h00000000,     // 0
          32'h3fc00000,     // 1.5
          32'h40400000,     // 3
          32'h40a00000      // 5
        };
    logic [0:3] comparison_results;
    logic [1:0] sel_piecewise;
    logic [31:0] slope;
    logic [31:0] intercept;
    logic [31:0] mult_out;
    logic [31:0] y_out;

    logic [ADDR_WIDTH-1:0]  counter;
    logic [ADDR_WIDTH-1:0] wr_addr;
    
    assign done = counter == ((NUM_WORDS-1) * 4);
    assign bram_addr_in = counter;
    assign bram_addr_out = wr_addr;
    assign bram_wrdata_out = y_out;

    generate
        genvar i;
        for (i = 0; i < NUM_LINES; i++) begin
            sig_fp_comp comp(
                .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
                .s_axis_a_tdata(bram_rddata_in),              // input wire [31 : 0] s_axis_a_tdata
                .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
                .s_axis_b_tdata(piecewise_bounds[i]),              // input wire [31 : 0] s_axis_b_tdata
                .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
                .m_axis_result_tdata(comparison_results[i])    // output wire [31 : 0] m_axis_result_tdata
            );
        end
    endgenerate
    
    always_comb begin
        if (comparison_results[3]) begin
            sel_piecewise = 3;
        end
        else if (comparison_results[2]) begin
            sel_piecewise = 2;
        end
        else if (comparison_results[1]) begin
            sel_piecewise = 1;
        end
        else
            sel_piecewise = 0;
        end
    end

    sigmoid_rom sig_rom (
        .index(sel_piecewise),
        .slope(slope),
        .intercept(intercept)
    );

    sig_fp_mult fp_mult (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(slope),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(bram_rddata_in),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(mult_out)    // output wire [31 : 0] m_axis_result_tdata
    );

    sig_fp_add fp_add (
      .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
      .s_axis_a_tdata(mult_out),              // input wire [31 : 0] s_axis_a_tdata
      .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
      .s_axis_b_tdata(intercept),              // input wire [31 : 0] s_axis_b_tdata
      .m_axis_result_tvalid(),  // output wire m_axis_result_tvalid
      .m_axis_result_tdata(y_out)    // output wire [31 : 0] m_axis_result_tdata
    );

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
} sigmoid_states;

module sigmoid_control
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
    output clear,
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
            if (ps_control[0] == 1) begin
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
            if (doneA)
                next_state = DONE_A;
            else
                next_state = LOOP_A;
        end
        else if (state == DONE_A) begin
            next_state = WAIT_FOR_ACK;
        end
        else if (state == WAIT_FOR_ACK) begin
            if (ps_control[0] == 0)
                next_state = WAIT_TO_START;
            else
                next_state = WAIT_FOR_ACK;
        end
        else begin
            next_state = WAIT_TO_START;
        end
    end
endmodule
