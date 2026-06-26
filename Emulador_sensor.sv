module sensor #(
    parameter SENSOR_ID = 0,
    parameter REG_COUNT = 4,
    parameter REG_WIDTH = 8
)(
    input  logic clock,
    input  logic reset,

    input  logic se,
    output logic miso,
    input  logic mosi,
    input  logic sclk
);

    logic [REG_WIDTH-1:0] regs [REG_COUNT-1:0];
    logic [$clog2(REG_COUNT)-1:0] reg_index;
    

    logic [2:0] bit_idx; 

    // --- 1. Inicialização dos Sensores ---
    always_ff @(posedge clock or negedge reset) begin   
        if (!reset) begin
            for (int i = 0; i < REG_COUNT; i++) begin
                regs[i] <= $random; // Removida a seed fixa para evitar falhas de compilação
            end
        end
    end

    // --- 2. Controle de Endereçamento dos Registradores ---
    always_ff @(negedge se or negedge reset) begin
        if (!reset) begin
            reg_index <= '0;
        end else begin
            if (reg_index == REG_COUNT - 1)
                reg_index <= '0;
            else
                reg_index <= reg_index + 1'b1;
        end
    end

    // --- 3. Controle Mux SPI (Imune a estados 'x') ---
    // Triple-trigger garante que a variável inicie e limpe de forma imaculada
    always_ff @(negedge sclk or negedge se or negedge reset) begin
        if (!reset) begin
            bit_idx <= 3'd7;
        end else if (!se) begin
            bit_idx <= 3'd7;       // Reinicia o ponteiro quando o Master desliga a linha
        end else begin
            bit_idx <= bit_idx - 1'b1; // Desloca para o próximo bit no clock do Master
        end
    end

    // --- 4. Saída MISO ---
    // Joga o bit exato diretamente na saída.
    assign miso = se ? regs[reg_index][bit_idx] : 1'b0;

endmodule