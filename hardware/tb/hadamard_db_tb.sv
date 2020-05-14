`timescale 1ns / 1ps

module hadamard_tb
#(
    BRAM_WIDTH = 32,
    WORD_BYTES = 4,
    ADDR_WIDTH = 12
)();
    logic executing; // Use this to differentiate between when we are loading from PS vs executing on PL
    
    logic mult_out_valid;
    
    logic clk;
    logic reset;
    logic [31:0] ps_control, pl_status;
    
    // Signals that are actually used by the BRAMs.
    logic [ADDR_WIDTH-1:0] addr_a, addr_b, addr_product;
    logic [BRAM_WIDTH-1:0] rddata_a, rddata_b, rddata_product;
    logic [BRAM_WIDTH-1:0] wrdata_a, wrdata_b, wrdata_product;
    logic [WORD_BYTES-1:0] we_a, we_b, we_product;
    
    // Signals that our simulated PS can use to interact with the BRAMs.
    logic [ADDR_WIDTH-1:0] ps_addr_a, ps_addr_b, ps_addr_product;
    logic [BRAM_WIDTH-1:0] ps_wrdata_a, ps_wrdata_b, ps_wrdata_product;
    logic [WORD_BYTES-1:0] ps_we_a, ps_we_b, ps_we_product;
    
    // Signals for the PL to use to interact with the BRAMs
    logic [ADDR_WIDTH-1:0] pl_addr_a, pl_addr_b, pl_addr_product;
    logic [BRAM_WIDTH-1:0] pl_wrdata_a, pl_wrdata_b, pl_wrdata_product;
    logic [WORD_BYTES-1:0] pl_we_a, pl_we_b, pl_we_product;
    
    // Start Multiplexers /////////////////////////////////////////////////////////
    assign addr_a = executing ? pl_addr_a : ps_addr_a;
    assign addr_b = executing ? pl_addr_b : ps_addr_b;
    assign addr_product = executing ? pl_addr_product : ps_addr_product;
    
    assign wrdata_a = executing ? pl_wrdata_a : ps_wrdata_a;
    assign wrdata_b = executing ? pl_wrdata_b : ps_wrdata_b;
    assign wrdata_product = executing ? pl_wrdata_product : ps_wrdata_product;

    assign we_a = executing ? pl_we_a : ps_we_a;
    assign we_b = executing ? pl_we_b : ps_we_b;
    assign we_product = executing ? pl_we_product : ps_we_product;
    // Stop Multiplexers //////////////////////////////////////////////////////////
    

    bram #(.BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH))
    a0 (
        .clk, .reset,
        .bram_addr(addr_a), .bram_rddata(rddata_a),
        .bram_wrdata(wrdata_a), .bram_we(we_a)
    );

    bram #(.BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH))
    b0 (
        .clk, .reset,
        .bram_addr(addr_b), .bram_rddata(rddata_b),
        .bram_wrdata(wrdata_b), .bram_we(we_b)
    );

    bram #(.BRAM_WIDTH(BRAM_WIDTH), .BRAM_SIZE(4096), .WORD_SIZE(WORD_BYTES), .ADDR_WIDTH(ADDR_WIDTH))
    product (
        .clk, .reset,
        .bram_addr(addr_product), .bram_rddata(rddata_product),
        .bram_wrdata(wrdata_product), .bram_we(we_product)
    );

    hadamard #(
        .BRAM_WIDTH(BRAM_WIDTH),
        .WORD_BYTES(WORD_BYTES),
        .ADDR_WIDTH(ADDR_WIDTH)
    )
    h0 (
        .clk, .reset,
        .ps_control, .pl_status,
        
        .bram_addr_a(pl_addr_a),
        .bram_rddata_a(rddata_a),
        .bram_wrdata_a(pl_wrdata_a),
        .bram_we_a(pl_we_a),
        
        .bram_addr_b(pl_addr_b),
        .bram_rddata_b(rddata_b),
        .bram_wrdata_b(pl_wrdata_b),
        .bram_we_b(pl_we_b),
        
        .bram_addr_product(pl_addr_product),
        .bram_rddata_product(rddata_product),
        .bram_wrdata_product(pl_wrdata_product),
        .bram_we_product(pl_we_product),
        .mult_out_valid(mult_out_valid)
    );
    
    always_comb begin
        if (mult_out_valid == 0)
            $display("Mult_out_valid = 0");
    end

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        executing = 0;

        ps_wrdata_a = 0;
        ps_wrdata_b = 0;
        ps_wrdata_product = 0;

        ps_addr_a = 0;
        ps_addr_b = 0;
        ps_addr_product = 0;
        
        ps_we_a = 0;
        ps_we_b = 0;
        ps_we_product = 0;

        ps_control = 0;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        #1; reset = 0;
        @(posedge clk);

        // fill bram a0
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
//            ps_wrdata_a = 2; // integer test
            ps_wrdata_a = 32'hc0000000; // floating point test
            ps_addr_a = i * 4;
            ps_we_a = 4'b1111;
            @(posedge clk);
        end
        
        ps_we_a = 0;
        
        // fill bram b0
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
//            ps_wrdata_b = 3; // integer test
            ps_wrdata_b = 32'h418c0000; // floating point test
            ps_addr_b = i * 4;
            ps_we_b = 4'b1111;
            @(posedge clk);
        end
        
        ps_we_b = 0;
        
        executing = 1;

        @(posedge clk);
        ps_control[0] = 1;
        @(posedge clk);
        @(posedge clk);
        ps_control[1] = 1;
        @(posedge clk);
        @(posedge clk);

        // wait enough cycles for computations to be done
        while (pl_status[0] == 0 || pl_status[1] == 0) begin
            @(posedge clk);
        end
        
        executing = 0;
        
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
            ps_addr_product = i * 4;
            @(posedge clk);
//            if (rddata_product != 6)
            if (rddata_product != 32'hc20c0000)
                $display("rddata_product[%d] = %x", i, rddata_product);
        end
        
        
        executing = 1;
        // Start 2nd test
        ps_control[0] = 0;
        @(posedge clk);
        @(posedge clk);
        ps_control[1] = 0;
        @(posedge clk);
        @(posedge clk);
        executing = 0;
        
        // fill bram a0
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
//            ps_wrdata_a = 2; // integer test
            ps_wrdata_a = 32'hc0490fdb; // floating point test
            ps_addr_a = i * 4;
            ps_we_a = 4'b1111;
            @(posedge clk);
        end
        
        ps_we_a = 0;
        
        // fill bram b0
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
//            ps_wrdata_b = 3; // integer test
            ps_wrdata_b = 32'h402df854; // floating point test
            ps_addr_b = i * 4;
            ps_we_b = 4'b1111;
            @(posedge clk);
        end
        
        ps_we_b = 0;
        
        executing = 1;
        
        @(posedge clk);
        ps_control[0] = 1;
        while (pl_status[0] == 0)
            @(posedge clk);
            
        ps_control[1] = 1;
        while (pl_status[1] == 0)
            @(posedge clk);
        @(posedge clk);
        
        executing = 0;
        
        for (int i=0; i < (2**ADDR_WIDTH)/WORD_BYTES; i=i+1) begin
            ps_addr_product = i * 4;
            @(posedge clk);
//            if (rddata_product != 6)
            if (rddata_product != 32'hc108a2c0)
                $display("rddata_product[%d] = %x", i, rddata_product);
        end
        
        $finish;
        
    end
endmodule
