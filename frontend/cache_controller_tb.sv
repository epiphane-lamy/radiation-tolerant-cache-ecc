import cache_pkg::*;

module cache_controller_tb;

    logic        clk;
    logic        rst_n;
    op_t         op;
    logic [7:0]  addr_cpu_in;
    logic [7:0] data_cpu_in;
    logic        data_ready;
    logic [7:0] data_cpu;

    logic        we_cache;
    logic [2:0]  addr_cache;
    data_cache_t data_cache_wr;
    logic        way_select;
    logic [20:0] data_cache1;
    logic [20:0] data_cache2;

    logic        re_mem;
    logic        we_mem;
    logic [7:0]  addr_mem;
    logic [15:0] data_mem_write;
    logic        valid_mem;
    logic [15:0] data_mem_read;

    // DUT
    cache_controller dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .op             (op),
        .addr_cpu_in    (addr_cpu_in),
        .data_cpu_in    (data_cpu_in),
        .data_ready     (data_ready),
        .data_cpu       (data_cpu),
        .we_cache       (we_cache),
        .addr_cache     (addr_cache),
        .data_cache_wr  (data_cache_wr),
        .way_select     (way_select),
        .data_cache1    (data_cache1),
        .data_cache2    (data_cache2),
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

    localparam int MEM_LATENCY = 3;
    logic [15:0] mem_array [0:255];

    // Memory model with fixed-latency response
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
        $display("[%0t] %-22s | state=%-12s data_ready=%b data_cpu=%02h we_cache=%b re_mem=%b we_mem=%b valid_mem=%b",
            $time, label, dut.state.name(),
            data_ready, data_cpu, we_cache, re_mem, we_mem, valid_mem);
    endtask


    // Macro : wait before reading outputs
    `define SAMPLE @(posedge clk); @(negedge clk);


    initial begin
        clk         = 0;
        rst_n       = 0;
        op          = READ;
        addr_cpu_in = '0;
        data_cache1 = '0;
        data_cache2 = '0;

        // Hold reset for two clock cycles before starting the test sequence
        @(posedge clk); @(posedge clk); #1;
        rst_n = 1;


        // TEST 1: Read hit - Way 0-------------------------------------------------------------------------------------
        $display("\n=== TEST 1: READ HIT way0 ===");
        op          = READ;
        addr_cpu_in = 8'b10100000; // (tag=1010, index=000, offset=0)
        data_cache1 = {4'b1010, 1'b1, 8'hCC, 8'hDD};
        data_cache2 = {4'b1111, 1'b1, 8'h56, 8'h78};

        `SAMPLE
        display_state("hit way0");
        assert (data_ready == 1)          else $error("TEST_1 FAIL: data_ready != 1");
        assert (data_cpu   == 8'hDD)   else $error("TEST_1 FAIL: data_cpu != DD");
        $display("  data_cpu=%02h (expected DD) %s", data_cpu, data_cpu == 8'hDD ? "PASS" : "FAIL");

        // TEST 2 : Read hit - Way 1---------------------------------------------------------------------------------------
        $display("\n=== TEST 2 : READ HIT way1 ===");
        addr_cpu_in = 8'b11110011; // (tag=1111, index=001, offset=1)
        data_cache1 = {4'b0000, 1'b1, 8'hBE, 8'hEF};
        data_cache2 = {4'b1111, 1'b1, 8'h12, 8'h34};

        `SAMPLE
        display_state("hit way1");
        assert (data_ready == 1)          else $error("TEST_2 FAIL: data_ready != 1");
        assert (data_cpu   == 8'h12)   else $error("TEST_2 FAIL: data_cpu != 12");
        $display("  data_cpu=%02h (expected 12) %s", data_cpu, data_cpu == 8'h12 ? "PASS" : "FAIL");


        // TEST 3: Read miss - memory fetch and cache refill--------------------------------------------------
        $display("\n=== TEST 3: READ MISS ===");
        addr_cpu_in  = 8'b10110100; // (tag=1011, index=010, offset=0)
        data_cache1  = {4'b0001, 1'b1, 8'hBE, 8'hEF};
        data_cache2  = {4'b0010, 1'b1, 8'h56, 8'h78};
        mem_array[8'b10110100] = 16'hBABE;

        `SAMPLE
        display_state("miss detected (IDLE)");
        assert (data_ready == 0) else $error("TEST_3 FAIL: data_ready != 0");

        
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
        $display("  data_cpu=%02h (expected BE) %s", data_cpu, data_cpu == 8'hBE ? "PASS" : "FAIL");

        // Verify cache refill
        `SAMPLE
        display_state("WRITE_CACHE");
        assert (we_cache == 1) else $error("TEST3 FAIL: cache write not asserted");
        $display("  we_cache=%b way=%b tag=%04b data1=%04h data=%04h", we_cache, way_select, dut.data_cache_wr.tag, dut.data_cache_wr.data1, dut.data_cache_wr.data2);

        // Verify controller returns to IDLE
        `SAMPLE
        display_state("after WRITE_CACHE");
        assert (dut.state == dut.IDLE) else $error("TEST_3 FAIL: expected IDLE state");


        // TEST 4:  Read hit after miss--------------------------------------------------------------------------------
        $display("\n=== TEST 4: HIT after MISS ===");
        data_cache1 = {4'b1011, 1'b1, 8'hBA, 8'hBE};
        data_cache2 = {4'b0010, 1'b1, 8'h56, 8'h78};

        `SAMPLE
        display_state("hit after miss");
        assert (data_ready == 1)        else $error("TEST_4 FAIL: data_ready != 1");
        assert (data_cpu == 8'hBE)   else $error("TEST_4 FAIL: data_cpu expected=BE");
        $display("  data_cpu=%02h (expected BE) %s", data_cpu, data_cpu == 8'hBE ? "PASS" : "FAIL");



        // ────────────────────────────────────────────────────────
        // TEST 5: Write hit
        //   addr=10100000 (tag=1010, index=000, offset=0)
        //   way0: tag=1010, valid=1, data=CCDD -> hit
        //   CPU write data=EF (offset=0)
        //   expected after write :
        //     - memory[0xA0] = CCEF
        //     - cache way0    = CCEF
        //     - data_ready asserted after the memory write acknowledgement
        // ────────────────────────────────────────────────────────
        $display("\n=== TEST 5: WRITE HIT ===");
        op          = WRITE;
        addr_cpu_in = 8'b10100000;
        data_cpu_in = 8'hEF;
        data_cache1 = {4'b1010, 1'b1, 16'hCCDD}; // way0: hit
        data_cache2 = {4'b1111, 1'b1, 16'h5678};
        mem_array[8'b10100000] = 16'hCCDD; // Keep memory consistent with the cache line

        `SAMPLE
        display_state("write detected (IDLE)");
        assert (data_ready == 0) else $error("TEST_5 FAIL: data_ready asserted too early");

        // Wait until the controller starts the memory write phase
        begin
            int timeout; timeout = 0;
            while (dut.state != dut.WRITE_MEM && timeout < 20) begin
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

        // Verify the updated cache line
        `SAMPLE
        display_state("WRITE_CACHE");
        assert (we_cache == 1) else $error("TEST_5 FAIL: we_cache != 1");
        assert ({dut.data_cache_wr.data1, dut.data_cache_wr.data2} == 16'hCCEF)
            else $error("TEST_5 FAIL: expected cache data = 16'hCCEF, got %04h", {dut.data_cache_wr.data1, dut.data_cache_wr.data2});
        $display("  cache_wr.data=%04h (expected CCEF) %s",
            {dut.data_cache_wr.data1, dut.data_cache_wr.data2}, {dut.data_cache_wr.data1, dut.data_cache_wr.data2} == 16'hCCEF ? "PASS" : "FAIL");

        // Verify that the backing memory was updated
        `SAMPLE
        display_state("IDLE");
        assert (mem_array[8'b10100000] == 16'hCCEF)
            else $error("TEST_5 FAIL: expected memory = 16'hCCEF, got %04h", mem_array[8'b10100000]);
        $display("  mem[0xA0]=%04h (expected CCEF) %s",
            mem_array[8'b10100000], mem_array[8'b10100000] == 16'hCCEF ? "PASS" : "FAIL");

        // ────────────────────────────────────────────────────────
        // TEST 6: Write miss
        //   addr=11000010 (tag=1100, index=001, offset=1)
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
        // ────────────────────────────────────────────────────────
        $display("\n=== TEST 6: WRITE MISS ===");
        op          = WRITE;
        addr_cpu_in = 8'b11000011;
        data_cpu_in = 8'hCA;
        data_cache1 = {4'b0000, 1'b1, 8'hDE, 8'hAD}; // way0: miss
        data_cache2 = {4'b0001, 1'b1, 8'hBE, 8'hEF}; // way1: miss
        mem_array[8'b11000011] = 16'h5678;

        `SAMPLE
        display_state("write miss detected");
        assert (data_ready == 0) else $error("TEST_6 FAIL: data_ready asserted too early");

        // Wait until the controller starts the memory write phase.
        begin
            int timeout; timeout = 0;
            while (dut.state != dut.WRITE_MEM && timeout < 20) begin
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
        assert (we_cache == 1) else $error("TEST_6 FAIL: we_cache != 1");
        assert ({dut.data_cache_wr.data1, dut.data_cache_wr.data2} == 16'hCA78)
            else $error("TEST_6 FAIL: expected cache data = 16'hCA78, got %04h", {dut.data_cache_wr.data1, dut.data_cache_wr.data2});
        $display("  cache_wr.data=%04h (expected CA78) %s",
            {dut.data_cache_wr.data1, dut.data_cache_wr.data2}, {dut.data_cache_wr.data1, dut.data_cache_wr.data2} == 16'hCA78 ? "PASS" : "FAIL");

        // Verify that the backing memory was updated
        `SAMPLE
        display_state("IDLE");
        assert (mem_array[8'b11000011] == 16'hCA78)
            else $error("TEST_6 FAIL: expected memory = 16'hCA78, got %04h", mem_array[8'b11000011]);
        $display("  mem[0xC3]=%04h (expected CA78) %s",
            mem_array[8'b11000011], mem_array[8'b11000011] == 16'hCA78 ? "PASS" : "FAIL");





        $display("\n=== Simulation completed successfully ===");
        $finish;
    end

endmodule