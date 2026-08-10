import cache_pkg::data_cache_t;

typedef enum logic [1:0] {
    READ,
    WRITE,
    NOP
} op_t;

typedef struct packed {
    logic [3:0] tag;
    logic [2:0] index;
    logic       offset;
} addr_cpu_t;


module cache_controller (
    // General
    input  logic        clk,
    input  logic        rst_n,
    // CPU
    input  op_t         op,
    input  logic [7:0]  addr_cpu_in,
    input  logic [7:0]  data_cpu_in,
    output logic        data_ready,
    output logic [7:0]  data_cpu,
    // Cache (2-way)
    output logic        we_cache,
    output logic [2:0]  addr_cache,
    output data_cache_t data_cache_wr,
    output logic        way_select,
    input  data_cache_t data_cache1, // way 0
    input  data_cache_t data_cache2, // way 1
    // Main memory
    output logic        re_mem,
    output logic        we_mem,
    output logic [7:0]  addr_mem,
    output logic [15:0] data_mem_write,
    input  logic        valid_mem,
    input  logic [15:0] data_mem_read
);

    //------------------------------------------------------------------------------
    // Cache controller
    //
    // 2-way set-associative cache controller supporting:
    //   - Read hits and misses
    //   - Write hits and misses
    //   - Cache line refill from main memory
    //   - Write-through updates to main memory
    //   - Per-set replacement tracking
    //
    // The controller uses a multi-cycle FSM to handle memory accesses with
    // non-zero latency. On a read miss, the requested data is returned to the CPU
    // as soon as the memory response is available, while the cache refill is
    // completed in the following cycle.
    //
    // FSM states:
    //   IDLE         : Handle CPU requests and serve cache hits.
    //   FETCH        : Wait for the memory response after a read miss.
    //   READ_MEM     : Fetch the existing memory line for a write operation.
    //   WRITE_MEM    : Write the updated line back to memory.
    //   WRITE_CACHE  : Install the fetched or updated line into the cache.
    //------------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        FETCH,
        WRITE_CACHE,
        READ_MEM,
        WRITE_MEM
    } state_t;

    state_t state, next_state;

    addr_cpu_t   addr_cpu;
    data_cache_t cache0, cache1;

    assign addr_cpu = addr_cpu_in;
    assign cache0   = data_cache1;
    assign cache1   = data_cache2;

    logic hit0, hit1;

    // Registered one cycle earlier to match the cache read latency.
    addr_cpu_t addr_cpu_reg;
    assign hit0 = cache0.valid && (cache0.tag == addr_cpu_reg.tag);
    assign hit1 = cache1.valid && (cache1.tag == addr_cpu_reg.tag);

    // One replacement bit per cache set (identifies the way to replace on a miss)
    logic [7:0] lru_bits;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            addr_cpu_reg <= '0;
        else
            addr_cpu_reg <= addr_cpu; // Delay to match cache read latency
    end

    // CPU address captured when entering a memory access sequence
    // Preserved across the multi-cycle FSM operation
    addr_cpu_t   miss_addr;
    // Cache line to be written back to memory and/or installed in the cache
    logic [15:0] write_data_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end


    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (op == READ && !(hit0 || hit1))
                    next_state = FETCH;
                if (op == WRITE)
                    next_state = READ_MEM;
            end
            FETCH: begin
                if (valid_mem)
                    next_state = WRITE_CACHE;
            end
            WRITE_CACHE: begin
                next_state = IDLE;
            end
            READ_MEM: begin
                if (valid_mem)
                    next_state = WRITE_MEM;
            end
            WRITE_MEM: begin
                if (valid_mem)
                    next_state = WRITE_CACHE;
            end
            default: next_state = IDLE;
        endcase
    end


    // Capture transaction context across multi-cycle memory accesses
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miss_addr      <= '0;
            write_data_reg <= '0;
        end else begin
            if (state == IDLE && (next_state == FETCH || next_state == READ_MEM))
                miss_addr <= addr_cpu;
            if (state == FETCH && valid_mem)
                write_data_reg <= data_mem_read;
            if (state == READ_MEM && valid_mem)
                write_data_reg <= miss_addr.offset ? {data_cpu_in, data_mem_read[7:0]} : {data_mem_read[15:8], data_cpu_in};
        end
    end


    always_comb begin
        if (state == WRITE_CACHE)
            addr_cache = miss_addr.index;
        else
            addr_cache = addr_cpu.index;
    end

    always_comb begin
        addr_mem = (state == IDLE) ? addr_cpu_in : miss_addr;
    end

    // Preserve write-hit information until WRITE_CACHE
    logic write_hit;
    logic write_hit_way;

    // Capture the write-hit result for cache way selection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_hit     <= 1'b0;
            write_hit_way <= 1'b0;
        end else begin
            if (state == IDLE && op == WRITE) begin
                write_hit     <= hit0 || hit1;
                write_hit_way <= hit1;
            end
        end
    end

    always_comb begin
        data_ready     = 1'b0;
        data_cpu       = 8'h0;
        we_cache       = 1'b0;
        way_select     = 1'b0;
        re_mem         = 1'b0;
        we_mem         = 1'b0;
        data_mem_write = '0;
        data_cache_wr  = '0;

        case (state)
            // IDLE: serve cache hits directly
            IDLE: begin
                if (op == READ) begin
                    if (hit0) begin
                        data_cpu   = addr_cpu_reg.offset ? cache0.data1 : cache0.data2;
                        data_ready = 1'b1;
                    end else if (hit1) begin
                        data_cpu   = addr_cpu_reg.offset ? cache1.data1 : cache1.data2;
                        data_ready = 1'b1;
                    end
                end
            end

            // FETCH: wait for the memory response.
            FETCH: begin
                re_mem = 1'b1;
                if (valid_mem) begin
                    // The requested byte can be returned to the CPU immediately
                    // Cache refill is completed in the following WRITE_CACHE state
                    data_cpu   = miss_addr.offset ? data_mem_read[15:8] : data_mem_read[7:0];
                    data_ready = 1'b1;
                end
            end

            // READ_MEM: fetch the existing line before applying the CPU write
            READ_MEM: begin
                re_mem = 1'b1;
            end

            // WRITE_MEM: write the updated cache line back to memory
            WRITE_MEM: begin
                re_mem = 1'b0;
                we_mem = 1'b1;
                data_mem_write = write_data_reg;
                if (valid_mem) begin
                    data_ready = 1'b1;
                end
            end

            // WRITE_CACHE: install the updated line into the selected cache way
            WRITE_CACHE: begin
                we_cache              = 1'b1;
                // Select the hit way for a write hit; otherwise select the replacement way.
                way_select = write_hit ? write_hit_way : lru_bits[miss_addr.index];
                data_cache_wr.tag     = miss_addr.tag;
                data_cache_wr.valid   = 1'b1;
                data_cache_wr.data1   = write_data_reg[15:8];
                data_cache_wr.data2   = write_data_reg[7:0];
            end

            default: ;
        endcase
    end


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lru_bits <= '0;
        end else begin
            // Update the replacement bit after a cache hit
            // The non-accessed way becomes the replacement candidate
            if (state == IDLE && (op == READ || op == WRITE)) begin
                if (hit0)
                    lru_bits[addr_cpu_reg.index] <= 1'b1; // way1 becomes LRU
                else if (hit1)
                    lru_bits[addr_cpu_reg.index] <= 1'b0; // way0 becomes LRU
            end
            // After a cache refill, switch the replacement way.
            if (state == WRITE_CACHE) begin
                lru_bits[miss_addr.index] <= ~lru_bits[miss_addr.index];
            end
        end
    end

endmodule
