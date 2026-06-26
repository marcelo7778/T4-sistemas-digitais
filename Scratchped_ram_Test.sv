module scratchpad_ram (
    input  logic       clk,      
    input  logic [7:0] data_i,   
    input  logic [7:0] addr,     
    input  logic       we,       
    output logic [7:0] data_o    
);
    // inicializa a leitura com 0
    logic [7:0] memory [256] = '{default: 8'd0};

    always_ff @(posedge clk) begin
        if (we) begin
            memory[addr] <= data_i; 
        end
        data_o <= memory[addr]; 
    end
endmodule