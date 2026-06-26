module Master_Spi (
    input  logic       clk,
    input  logic       reset,

    // Interface TB
    input  logic       start,
    input  logic [1:0] reg_id,
    output logic       ready,

    // Interface SPI
    output logic       sclk,
    output logic       mosi,
    input  logic       miso,
    output logic [3:0] se,

    // Interface RAM
    output logic [7:0] ram_data_i,
    output logic [7:0] ram_addr,
    output logic       ram_we
);

    typedef enum logic [2:0] {
        ST_IDLE, ST_SPI_LOW, ST_SPI_HIGH, ST_MEM_WRITE, ST_MEM_UPDATE
    } state_t;

    state_t state;
    logic [7:0] shift_rx;
    logic [2:0] bit_cnt;
    logic [1:0] active_sensor;

    assign mosi = 1'b0;
    assign ram_data_i = shift_rx;

    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            state      <= ST_IDLE;
            ram_addr   <= 8'hFF; 
            shift_rx   <= 8'd0;
            bit_cnt    <= 3'd0;
            active_sensor <= 2'b00;
            sclk       <= 1'b0;
            se         <= 4'b0000;
            ram_we     <= 1'b0;
            ready      <= 1'b0;
        end else begin
            ram_we <= 1'b0; 

            case (state)
                ST_IDLE: begin
                    sclk <= 1'b0;
                    if (start) begin
                        ram_addr      <= ram_addr + 1'b1; 
                        active_sensor <= reg_id;
                        bit_cnt       <= 3'd0;
                        se[reg_id]    <= 1'b1; 
                        ready         <= 1'b0; 
                        state         <= ST_SPI_LOW;
                    end else begin
                        ready <= 1'b1; 
                        se    <= 4'b0000;
                    end
                end
                
                ST_SPI_LOW: begin
                    se[active_sensor] <= 1'b1;
                    sclk              <= 1'b0;
                    state             <= ST_SPI_HIGH;
                end

                ST_SPI_HIGH: begin
                    se[active_sensor] <= 1'b1;
                    sclk              <= 1'b1; 
                    shift_rx          <= {shift_rx[6:0], miso}; 
                    bit_cnt           <= bit_cnt + 1'b1;
                    
                    if (bit_cnt == 3'd7) begin
                        state <= ST_MEM_WRITE;
                    end else begin
                        state <= ST_SPI_LOW;
                    end
                end

                ST_MEM_WRITE: begin
                    sclk       <= 1'b0;
                    se         <= 4'b0000;
                    ram_we     <= 1'b1; 
                    state      <= ST_MEM_UPDATE;
                end

                ST_MEM_UPDATE: begin
                    state      <= ST_IDLE;         
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule