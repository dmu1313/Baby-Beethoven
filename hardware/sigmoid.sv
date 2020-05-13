
module sigmoid
#(
    FLOAT_WIDTH = 31,
    LOG_FLOAT_WIDTH = 5
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
    logic doneA, doneB;
    logic incA, incB;
    logic clearA, clearB;
    logic first_half;
    
    assign bram_we_a = 0;
    assign bram_wrdata_a = 32'bxxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx_xxxx;

    had_datapath d(
        .clk,
        .reset,
        
        .bram_addr_a,
        .bram_rddata_a,
                
        .bram_addr_product,
        .bram_wrdata_product,
        
        .doneA,
        .doneB,
        .first_half,
            
        .incA,
        .incB,
        .clearA,
        .clearB,
        
        .mult_out_valid
    );
    
    had_control c(
        .clk,
        .reset,
        
        .ps_control,
        .pl_status,
        
        .bram_we_product,
        
        .doneA,
        .doneB,
        .first_half,
        
        .incA,
        .incB,
        .clearA,
        .clearB
    );
endmodule

module sigmoid_params_rom
(
    input clk,
    input reset,
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
    ADDR_WIDTH = 12
)
(
    input clk,
    input reset,
    
    output [ADDR_WIDTH-1:0] bram_addr_in,
    input  [BRAM_WIDTH-1:0] bram_rddata_in,

    output [ADDR_WIDTH-1:0] bram_addr_out,
    output [BRAM_WIDTH-1:0] bram_wrdata_out,
    
    output doneA,
    output doneB,
    input first_half,
    
    input incA,
    input incB,
    input clearA,
    input clearB,
    
    output mult_out_valid
);
    localparam NUM_LINES = 4;
    localparam logic [0:3][31:0] piecewise_bounds =
        { 32'h00000000,
          32'h3fc00000,
          32'h40400000,
          32'h40a00000
        };
    logic [0:3] comparison_results;
    logic [1:0] sel_piecewise;
    
    logic [ADDR_WIDTH-1:0]  counterA;
    logic [ADDR_WIDTH-1:0]  counterB;
    logic [ADDR_WIDTH-1:0]  addr;
    logic [FP_WIDTH-1:0]    mult_out;
//    logic mult_out_valid;
    logic [ADDR_WIDTH-1:0] wr_addr;
    
    assign doneA = counterA == 2044;
    assign doneB = counterB == 4092;
    
    assign addr = first_half ? counterA : counterB;
    assign bram_addr_a = addr;
    assign bram_addr_b = addr;

    assign bram_addr_product = wr_addr;
    assign bram_wrdata_product = mult_out;

    generate
        genvar i;
        for (i = 0; i < NUM_LINES; i++) begin
            sig_fp_comp comp(
                .s_axis_a_tvalid(1),            // input wire s_axis_a_tvalid
                .s_axis_a_tdata(bram_rddata_in),              // input wire [31 : 0] s_axis_a_tdata
                .s_axis_b_tvalid(1),            // input wire s_axis_b_tvalid
                .s_axis_b_tdata(piecewise_bounds[i]),              // input wire [31 : 0] s_axis_b_tdata
                .m_axis_result_tvalid(mult_out_valid),  // output wire m_axis_result_tvalid
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

    always_ff @(posedge clk) begin
        if (reset)
            wr_addr <= 0;
        else
            wr_addr <= addr;
    
        if (clearA)
            counterA <= 0;
        else if (incA)
            counterA <= counterA + 4;
        
        if (clearB)
            counterB <= 2048;
        else if (incB)
            counterB <= counterB + 4;
    end

endmodule

typedef enum bit[3:0] {
    WAIT_TO_START   = 0,
    START_A         = 1,
    LOOP_A          = 2,
    DONE_A          = 3,
    START_B         = 4,
    LOOP_B          = 5,
    DONE_B          = 6
} hadamard_states;

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
    
    output [WORD_BYTES-1:0] bram_we_product,
    
    input  doneA,
    input  doneB,
    output first_half,
    
    output incA,
    output incB,
    output clearA,
    output clearB
);
    logic [3:0] state;
    logic [3:0] next_state;
    logic completedA, completedB;
    
    assign pl_status[0] = completedA;
    assign pl_status[1] = completedB;
    
    assign incA = state == START_A || state == LOOP_A;
    assign incB = state == START_B || state == LOOP_B;
    
    assign clearA = state == WAIT_TO_START;
    assign clearB = state == WAIT_TO_START;

    assign first_half = (state == START_A || state == LOOP_A || state == DONE_A) ? 1 : 0;
    
    assign bram_we_product = (state == LOOP_A || state == DONE_A || state == LOOP_B || state == DONE_B) ? 4'b1111 : 4'b0000;

    always_ff @(posedge clk) begin
        if (reset)
            completedA <= 0;
        else if (state == DONE_A)
            completedA <= 1;
        else if (completedA == 1 && ps_control[0] == 0)
            completedA <= 0;
            
        if (reset)
            completedB <= 0;
        else if (state == DONE_B)
            completedB <= 1;
        else if (completedB == 1 && ps_control[1] == 0)
            completedB <= 0;
    end

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
            if (ps_control[0] && completedA == 0)
                next_state = START_A;
            else if (ps_control[1] && completedB == 0)
                next_state = START_B;
            else
                next_state = WAIT_TO_START;
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
            next_state = WAIT_TO_START;
        end
        
        else if (state == START_B) begin
            next_state = LOOP_B;
        end
        else if (state == LOOP_B) begin
            if (doneB)
                next_state = DONE_B;
            else
                next_state = LOOP_B;
        end
        else if (state == DONE_B) begin
            next_state = WAIT_TO_START;
        end        
    end
endmodule
