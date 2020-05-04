

module bram
#(
    // These are default values for a 4K BRAM
    BRAM_WIDTH      = 32,   // Read/Write width
    BRAM_SIZE       = 4096, // In bytes
    WORD_SIZE       = 4,    // Number of bytes in a word
    ADDR_WIDTH = 12
)
(
    input                           clk,
    input                           reset,
    input [ADDR_WIDTH-1:0]          bram_addr,
    output logic [BRAM_WIDTH-1:0]   bram_rddata,
    input [BRAM_WIDTH-1:0]          bram_wrdata,
    input [WORD_SIZE-1:0]           bram_we
);
    localparam NUM_WORDS = BRAM_SIZE / WORD_SIZE;
    logic [BRAM_WIDTH-1:0] mem [NUM_WORDS];

    initial begin
        integer i;
        for (i=0; i < NUM_WORDS; i=i+1) begin
            mem[i] = 0;
        end
    end

    always @(posedge clk) begin
        bram_rddata <= mem[bram_addr[ADDR_WIDTH-1:2]];
        if (bram_we == 4'b1111)
            mem[bram_addr[ADDR_WIDTH-1:2]] <= bram_wrdata;
        else if (bram_we != 0)
            $display("ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");
    end

endmodule

/*

module weight_memory_sim(
    input         clk,
    input         reset,
    input        [15:0] bram_addr_w,
    output logic [31:0] bram_rddata_w,
    input        [31:0] bram_wrdata_w,
    input         [3:0] bram_we_w
);
    logic [31:0] mem [(128*128)-1:0];
    
    initial begin
        integer i;
        for (i=0; i<(2**14)-1; i=i+1) begin
            mem[i] = 0;
        end
    $readmemh("/home/home5/dmu/Desktop/C/weights.txt", mem); 
    end

    always @(posedge clk) begin
        bram_rddata_w <= mem[bram_addr_w[15:2]];
        if (bram_we_w == 4'hf)
            mem[bram_addr_w[15:2]] <= bram_wrdata_w;
        else if (bram_we_w != 0)
            $display("ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");              
    end
endmodule

module xy_memory_sim(
    input         clk,
    input         reset,
    input        [11:0] bram_addr_xy,
    output logic [31:0] bram_rddata_xy,
    input        [31:0] bram_wrdata_xy,
    input         [3:0] bram_we_xy
);
    logic [31:0] mem [1023:0];

    initial begin
        integer i;
        for (i=0; i<(2**10)-1; i=i+1) begin
            mem[i] = 0;
        end
        
        $readmemh("/home/home5/dmu/Desktop/C/test_vector15.txt", mem);
    end

    always @(posedge clk) begin
        bram_rddata_xy <= mem[bram_addr_xy[11:2]];
        if (bram_we_xy == 4'hf)
            mem[bram_addr_xy[11:2]] <= bram_wrdata_xy;
        else if (bram_we_xy != 0)
            $display("xy_mem ERROR: Memory simulation model only implemented we = 0 and we=4'hf. Simulation will be incorrect.");              
    end

endmodule

*/
