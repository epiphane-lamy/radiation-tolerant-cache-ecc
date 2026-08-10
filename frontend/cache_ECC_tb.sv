import cache_pkg::*;

//------------------------------------------------------------------------------
// Testbench: cache_ECC_tb
//
// Description:
//   Integration testbench for the cache_ECC top-level module.
//
//   The cache_ECC module integrates the complete cache datapath, including:
//     - Cache controller
//     - ECC encoder/decoder
//     - Cache SRAM
//     - Main memory interface
//
//   This testbench verifies the behavior of the complete system from the
//   CPU interface to the main memory interface.
//
// Tests performed:
//   - Read hit on both cache line offsets
//   - Read miss and cache line refill from main memory
//   - Read hit after a cache refill
//   - Write hit with cache and main memory update
//   - Write miss with cache line fetch, data merge and write-back
//
// The main memory is modeled inside the testbench with a fixed response
// latency (MEM_LATENCY cycles).
//
// Note:
//   This is an integration-level testbench. It verifies the complete
//   cache_ECC system rather than testing each submodule independently.
//------------------------------------------------------------------------------

module cache_ECC_tb;
    // General
    logic        clk;
    logic        rst_n;
    // CPU
    op_t         op;
    logic [7:0]  addr_cpu_in;
    logic [7:0] data_cpu_in;
    logic        data_ready;
    logic [7:0] data_cpu;
    // Main memory
    logic        re_mem;
    logic        we_mem;
    logic [7:0]  addr_mem;
    logic [15:0] data_mem_write;
    logic        valid_mem;
    logic [15:0] data_mem_read;

    cache_ECC cache_ECC_u (
        .clk            (clk),
        .rst_n          (rst_n),
        .op             (op),
        .addr_cpu_in    (addr_cpu_in),
        .data_cpu_in    (data_cpu_in),
        .data_ready     (data_ready),
        .data_cpu       (data_cpu),
        .re_mem         (re_mem),
        .we_mem         (we_mem),
        .addr_mem       (addr_mem),
        .data_mem_write (data_mem_write),
        .valid_mem      (valid_mem),
        .data_mem_read  (data_mem_read)
    );


    // period 10 ns
    always #5 clk = ~clk;

    logic        re_mem_prev;
    int          mem_cnt;
    logic        we_mem_prev;


    // Memory model with fixed-latency response
    localparam int MEM_LATENCY = 3;
    logic [15:0] mem_array [0:255];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_mem     <= 0;
            data_mem_read <= '0;
            re_mem_prev   <= 0;
            we_mem_prev   <= 0;
            mem_cnt       <= 0;
        end else begin
            valid_mem   <= 0;
            re_mem_prev <= re_mem;
            we_mem_prev <= we_mem;

            if (re_mem && !re_mem_prev)
                mem_cnt <= MEM_LATENCY;

            if (we_mem && !we_mem_prev)
                mem_cnt <= MEM_LATENCY;

            if (mem_cnt > 0) begin
                mem_cnt <= mem_cnt - 1;
                if (mem_cnt == 1) begin
                    valid_mem <= 1;
                    if (re_mem)
                        data_mem_read <= mem_array[addr_mem];
                    if (we_mem)
                        mem_array[addr_mem] <= data_mem_write;
                end
            end
        end
    end

    // print task
    task display_state(input string label);
    $display("[%0t] %-22s | state=%-12s data_ready=%b data_cpu=%02h we_cache=%b re_mem=%b we_mem=%b valid_mem=%b lru=%08b way_sel=%b",
        $time, label, cache_ECC_u.cache_controller_u.state.name(),
        data_ready, data_cpu, cache_ECC_u.cache_controller_u.we_cache, re_mem, we_mem, valid_mem,
        cache_ECC_u.cache_controller_u.lru_bits,
        cache_ECC_u.cache_controller_u.way_select);
endtask


    // Macro : wait before reading outputs
    `define SAMPLE @(posedge clk); @(negedge clk);


    // write memory task
    task write_memory(input logic [7:0] data_cpu, input logic [7:0] addr_cpu, input logic [15:0] data_mem);
        $display("\n=== write_memory : addr=%02b data=%02h ===\n", addr_cpu, data_cpu);
        
        while (cache_ECC_u.cache_controller_u.state != cache_ECC_u.cache_controller_u.IDLE)
            `SAMPLE;

        op          = WRITE;
        addr_cpu_in = addr_cpu;
        data_cpu_in = data_cpu;
        mem_array[addr_cpu] = data_mem;

        `SAMPLE

        begin
            int timeout; timeout = 0;
            while (!data_ready && cache_ECC_u.cache_controller_u.state != cache_ECC_u.cache_controller_u.IDLE && timeout < 40) begin
                `SAMPLE;
                timeout++;
            end
        end

        op          = READ; 
        `SAMPLE;
    endtask
    


    initial begin
        clk         = 0;
        rst_n       = 0;
        op          = READ;
        addr_cpu_in = '0;
        
        // Hold reset for two clock cycles before starting the test sequence
        @(posedge clk); @(posedge clk); #1;
        rst_n = 1;
    

        // ==========================================================================================
        // TEST 1: Read hit - Way 0
        // ==========================================================================================
        $display("\n=== TEST 1: READ HIT way0 ===");
        
        op          = READ;
        addr_cpu_in = 8'hFF; 
        `SAMPLE

        write_memory(8'hDD, 8'b10100000, 16'hCCDD);
        
        addr_cpu_in = 8'b10100000; // (tag=1010, index=000, offset=0)
        op          = READ;
        
        `SAMPLE
        `SAMPLE
        
        display_state("hit way0 offset 0");
        assert (data_ready == 1)          else $error("TEST_1 FAIL: data_ready != 1");
        assert (data_cpu   == 8'hDD)      else $error("TEST_1 FAIL: data_cpu != DD");
        $display("  data_cpu=%02h (attendu DD) %s", data_cpu, data_cpu == 8'hDD ? "PASS" : "FAIL");


        // ==========================================================================================
        // TEST 2: Read hit - Way 1
        // ==========================================================================================
        $display("\n=== TEST 2: READ HIT way1 ===");
        
        addr_cpu_in = 8'b10100001; 
        op          = READ;

        `SAMPLE
        
        display_state("hit way1 offset 1");
        assert (data_ready == 1)          else $error("TEST_2 FAIL: data_ready != 1");
        assert (data_cpu   == 8'hCC)      else $error("TEST_2 FAIL: data_cpu != CC");
        $display("  data_cpu=%02h (attendu CC) %s", data_cpu, data_cpu == 8'hCC ? "PASS" : "FAIL");

        
        
        // ==========================================================================================
        // TEST 3: Read miss - memory fetch and cache refill
        // ==========================================================================================
        $display("\n=== TEST 3: READ MISS ===");
        
        mem_array[8'b10110000] = 16'hBABE;
        
        @(negedge clk);
        addr_cpu_in = 8'b10110000; // (tag=1011, index=000, offset=0)
        op          = READ;
        
        @(posedge clk);
        #1;
        display_state("Cycle 1: SRAM update");

        @(posedge clk);
        #1;
        display_state("Cycle 2: controller should be in FETCH state");

        
        // Wait for the memory response
        begin
            int timeout;
            timeout = 0;
            while (!data_ready && timeout < 20) begin
                `SAMPLE
                display_state("FETCH");
                timeout++;
            end
        end

        assert (data_ready == 1)        else $error("TEST_3 FAIL: memory response not received");
        assert (data_cpu == 8'hBE)   else $error("TEST_3 FAIL: data_cpu expected=BE");
        $display("  data_cpu=%02h (attendu BE) %s", data_cpu, data_cpu == 8'hBE ? "PASS" : "FAIL");

        // Verify cache refill
        `SAMPLE
        display_state("WRITE_CACHE");
        // Verify controller returns to IDLE
        `SAMPLE
        display_state("after WRITE_CACHE");
        assert (cache_ECC_u.cache_controller_u.state == cache_ECC_u.cache_controller_u.IDLE) else $error("TEST_3 FAIL: expected IDLE state");


        op          = NOP;
        addr_cpu_in = 8'hFF; 
        `SAMPLE
        
        // ==========================================================================================
        // TEST 4: Read hit after miss
        // ==========================================================================================
        $display("\n=== TEST 4: HIT after MISS ===");
        
        addr_cpu_in  = 8'b10110000; 
        op           = READ;
        
        `SAMPLE
        `SAMPLE
        
        display_state("hit apres miss");
        assert (data_ready == 1)        else $error("TEST_4 FAIL: data_ready != 1");
        assert (data_cpu == 8'hBE)      else $error("TEST_4 FAIL: data_cpu expected=BE");
        $display("  data_cpu=%02h (attendu BE) %s", data_cpu, data_cpu == 8'hBE ? "PASS" : "FAIL");


        // ==========================================================================================
        // TEST 5: Write hit
        //   addr=10100000 (tag=1010, index=000, offset=0)
        //   way0: tag=1010, valid=1, data=CCDD -> hit
        //   CPU write data=EF (offset=0)
        //   expected after write :
        //     - memory[0xA0] = CCEF
        //     - cache way0    = CCEF
        //     - data_ready asserted after the memory write acknowledgement
        // ==========================================================================================
        
        $display("\n=== TEST 5 : WRITE HIT ===");
        `SAMPLE
        
        write_memory(8'hCC, 8'b10100000, 16'hDDCC);
        `SAMPLE
        
        op          = WRITE;
        addr_cpu_in = 8'b10100000; // tag=1010, index=000, offset=0
        data_cpu_in = 8'hEF;
        mem_array[8'b10100000] = 16'hCCDD; // Keep memory consistent with the cache line

        `SAMPLE
        display_state("write detected (IDLE)");
        assert (data_ready == 0) else $error("TEST_5 FAIL: data_ready asserted too early");

        // Wait until the controller starts the memory write phase
        begin
            int timeout; timeout = 0;
            while (cache_ECC_u.cache_controller_u.state != cache_ECC_u.cache_controller_u.WRITE_MEM && timeout < 20) begin
                `SAMPLE display_state("READ_MEM"); timeout++;
            end
        end

        // Wait for the memory write acknowledgement
        begin
            int timeout; timeout = 0;
            while (!data_ready && timeout < 20) begin
                `SAMPLE display_state("WRITE_MEM"); timeout++;
            end
        end

        assert (data_ready == 1) else $error("TEST_5 FAIL: data_ready not asserted after memory write");
        $display("  data_ready=%b (expected 1) %s", data_ready, data_ready == 1 ? "PASS" : "FAIL");
        `SAMPLE

        // Verify the updated cache line
        display_state("WRITE_CACHE");

        assert ({cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2} == 16'hCCEF)
            else $error("TEST_5 FAIL: expected cache data = 16'hCCEF, got %04h", {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2});
        $display("  cache_wr.data=%04h (expected CCEF) %s",
            {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2}, {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2} == 16'hCCEF ? "PASS" : "FAIL");

        op          = READ; 
        addr_cpu_in = 8'h00;

        // Verify that the backing memory was updated
        `SAMPLE
        display_state("IDLE");
        assert (mem_array[8'b10100000] == 16'hCCEF)
            else $error("TEST_5 FAIL: expected memory = 16'hCCEF, got %04h", mem_array[8'b10100000]);
        $display("  mem[0xA0]=%04h (expected CCEF) %s",
            mem_array[8'b10100000], mem_array[8'b10100000] == 16'hCCEF ? "PASS" : "FAIL");

        
        // ==========================================================================================
        // TEST 6: Write miss
        //   addr=11000011 (tag=1100, index=001, offset=1)
        //   way0: tag=0000, valid=1, data=DEAD -> miss
        //   way1: tag=0001, valid=1, data=BEEF -> miss
        //   initial memory[0xC3] = 5678
        //   CPU write data=CA (offset=1)
        //   Expected behavior:
        //     - Read the existing cache line from memory
        //     - Merge the CPU write into the fetched line
        //     - Write the updated line back to memory
        //     - Install the updated line in the cache
        //   expected results:
        //     - memory[0xC3] = CA78
        //     - cache way0    = CA78
        //     - data_ready asserted after the memory write acknowledgement
        // ==========================================================================================

        $display("\n=== TEST 6: WRITE MISS ===");
        `SAMPLE
        write_memory(8'hAD, 8'b10100000, 16'hDEAD);
        `SAMPLE
        op          = WRITE;
        addr_cpu_in = 8'b11000011; // tag=1100, index=001, offset=1
        data_cpu_in = 8'hCA;
        mem_array[8'b11000011] = 16'h5678;

        `SAMPLE
        display_state("write miss detected");
        assert (data_ready == 0) else $error("TEST_6 FAIL: data_ready asserted too early");

        // Wait until the controller starts the memory write phase.
        begin
            int timeout; timeout = 0;
            while (cache_ECC_u.cache_controller_u.state != cache_ECC_u.cache_controller_u.WRITE_MEM && timeout < 20) begin
                `SAMPLE
                display_state("READ_MEM");
                timeout++;
            end
        end
        
        // Wait for the memory write acknowledgement
        begin
            int timeout; timeout = 0;
            while (!data_ready && timeout < 20) begin
                `SAMPLE
                display_state("WRITE_MEM");
                timeout++;
            end
        end

        assert (data_ready == 1) else $error("TEST_6 FAIL: data_ready not asserted after memory write");
        $display("  data_ready=%b (expected 1) %s", data_ready, data_ready == 1 ? "PASS" : "FAIL");

        // Verify the updated cache line.
        `SAMPLE
        display_state("WRITE_CACHE");
        assert ({cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2} == 16'hCA78)
            else $error("TEST_6 FAIL: expected cache data = 16'hCA78, got %04h", {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2});
        $display("  cache_wr.data=%04h (expected CA78) %s",
            {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2}, {cache_ECC_u.cache_controller_u.data_cache_wr.data1, cache_ECC_u.cache_controller_u.data_cache_wr.data2} == 16'hCA78 ? "PASS" : "FAIL");

        // Verify that the backing memory was updated
        `SAMPLE
        display_state("IDLE");
        assert (mem_array[8'b11000011] == 16'hCA78)
            else $error("TEST_6 FAIL: expected memory = 16'hCA78, got %04h", mem_array[8'b11000011]);
        $display("  mem[0xC3]=%04h (expected CA78) %s",
            mem_array[8'b11000011], mem_array[8'b11000011] == 16'hCA78 ? "PASS" : "FAIL");


        $display("\n=== Simulation completed ===");
        $finish;
    end

endmodule
