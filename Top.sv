module Top (
    input logic clk_100M, // Clock primário vindo da placa (100 MHz)
    input logic reset,    // Botão de reset (Ativo em nível BAIXO)

    // --- Interface de Comando (Mapeado para as Chaves/Switches da placa) ---
    input  logic       start,  // Inicia a varredura
    input  logic [1:0] reg_id, // Escolhe qual ID de sensor ler
    output logic       ready,  // Avisa que está ocioso (Mapeado para um LED)

    // --- Interface de Verificação (Mapeado para LEDs da placa) ---
    output logic [7:0] ram_data_o 
);

    // Fios internos para os clocks que o Vivado vai gerar
    logic clk_15M;
    logic clk_40M;
    logic clk_50M;
    logic clk_25M;
    logic locked; // Fica '1' quando as frequências estiverem estáveis

    // --- Instanciação do IP Clocking Wizard (MMCM) ---
    //configure o reset para "Active Low" no viado
    clk_wiz_0 gerador_clocks (
        .clk_in1(clk_100M),
        .resetn(reset),      
        .locked(locked),
        .clk_out1(clk_15M),
        .clk_out2(clk_40M),
        .clk_out3(clk_50M),
        .clk_out4(clk_25M)
    );

    logic rst_interno;
    assign rst_interno = reset & locked;
    //
    logic       sclk_net;
    logic       mosi_net;
    logic       miso_mux; // Saída do Multiplexador que vai para o Master
    logic [3:0] se_net;   // Vetor de Slave Enable (se[0] a se[3])

    // miso de cada sensor
    logic miso_s1, miso_s2, miso_s3, miso_s4;

    logic [7:0] ram_data_i_net;
    logic [7:0] ram_addr_net;
    logic       ram_we_net;
    //
    
    // sensor 1 - 15 MHz
    sensor #(
        .SENSOR_ID(0), // ID 2'b00
        .REG_COUNT(4),
        .REG_WIDTH(8)
    ) Sensor1 (
        .clock(clk_15M),
        .reset(rst_interno),
        .se(se_net[0]),
        .miso(miso_s1),
        .mosi(mosi_net),
        .sclk(sclk_net)
    );

    // sensor 2 - 40 MHz
    sensor #(
        .SENSOR_ID(1), // ID 2'b01
        .REG_COUNT(4),
        .REG_WIDTH(8)
    ) Sensor2 (
        .clock(clk_40M),
        .reset(rst_interno),
        .se(se_net[1]),
        .miso(miso_s2),
        .mosi(mosi_net),
        .sclk(sclk_net)
    );

    // sensor 3 - 50 MHz
    sensor #(
        .SENSOR_ID(2), // ID 2'b10
        .REG_COUNT(4),
        .REG_WIDTH(8)
    ) Sensor3 (
        .clock(clk_50M),
        .reset(rst_interno),
        .se(se_net[2]),
        .miso(miso_s3),
        .mosi(mosi_net),
        .sclk(sclk_net)
    );

    // sensor 4 - 25 MHz
    sensor #(
        .SENSOR_ID(3), // ID 2'b11
        .REG_COUNT(4),
        .REG_WIDTH(8)
    ) Sensor4 (
        .clock(clk_25M),
        .reset(rst_interno),
        .se(se_net[3]),
        .miso(miso_s4),
        .mosi(mosi_net),
        .sclk(sclk_net)
    );


    
    // Isola e conecta o pino MISO correto ao Master com base no chip-select ativo.
    always_comb begin
        case (se_net)
            4'b0001: miso_mux = miso_s1;
            4'b0010: miso_mux = miso_s2;
            4'b0100: miso_mux = miso_s3;
            4'b1000: miso_mux = miso_s4;
            default: miso_mux = 1'b0; // Evita estados indefinidos/alta impedância
        endcase
    end


    Master_Spi spi_master (
        .clk(clk_100M),
        .reset(rst_interno),
        
        // Conexões direcionadas para a interface de controle externa (TB)
        .start(start),
        .reg_id(reg_id),
        .ready(ready),
        
        // Conexões com o barramento SPI
        .sclk(sclk_net),
        .mosi(mosi_net),
        .miso(miso_mux), // Recebe a linha selecionada pelo multiplexador
        .se(se_net),
        
        // Conexões direcionadas à Scratchpad RAM
        .ram_data_i(ram_data_i_net),
        .ram_addr(ram_addr_net),
        .ram_we(ram_we_net)
    );

    scratchpad_ram ram_block (
        .clk(clk_100M),
        .data_i(ram_data_i_net),
        .addr(ram_addr_net),
        .we(ram_we_net),
        .data_o(ram_data_o)
    );

endmodule