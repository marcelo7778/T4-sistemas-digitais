`timescale 1ns/1ps

module tb_Top();
    logic clk_100M = 0;
    logic clk_15M  = 0;
    logic clk_40M  = 0;
    logic clk_50M  = 0;
    logic clk_25M  = 0;
    logic reset;

    logic       start;
    logic [1:0] reg_id;
    logic       ready;
    logic [7:0] ram_data_o;


    Top uut (
        .clk_100M(clk_100M),
        .reset(reset),
        .start(start),
        .reg_id(reg_id),
        .ready(ready),
        .ram_data_o(ram_data_o)
    );

    // A diretiva `timescale 1ns/1ps permite o uso de casas decimais
    always #5.00  clk_100M = ~clk_100M; // Período 10ns   (100 MHz)
    always #10.00 clk_50M  = ~clk_50M;  // Período 20ns   (50 MHz)
    always #12.50 clk_40M  = ~clk_40M;  // Período 25ns   (40 MHz)
    always #20.00 clk_25M  = ~clk_25M;  // Período 40ns   (25 MHz)
    always #33.33 clk_15M  = ~clk_15M;  // Período ~66ns  (15 MHz)

    // Variáveis para controle do teste
    int erros = 0;
    int addr_esperado = 0;
    logic [7:0] valor_esperado;

    // --- Task Reutilizável para Leitura e Verificação ---
    task ler_sensor_e_verificar(input logic [1:0] id_alvo, input string nome_sensor);
        begin
            $display("--- Iniciando leitura do Sensor %0d (%s) ---", id_alvo, nome_sensor);
            
            // 1. Sincroniza e envia comando
            @(posedge clk_100M);
            reg_id = id_alvo;
            start = 1'b1;
            
            // 2. CORREÇÃO CRÍTICA: Espera o Master confirmar que começou a trabalhar
            wait(ready == 1'b0);
            
            // 3. Agora podemos desligar o comando start com segurança
            @(posedge clk_100M);
            start = 1'b0;

            // 4. Espia o valor que será salvo (Gabarito)
            case(id_alvo)
                2'b00: valor_esperado = uut.Sensor1.regs[uut.Sensor1.reg_index];
                2'b01: valor_esperado = uut.Sensor2.regs[uut.Sensor2.reg_index];
                2'b10: valor_esperado = uut.Sensor3.regs[uut.Sensor3.reg_index];
                2'b11: valor_esperado = uut.Sensor4.regs[uut.Sensor4.reg_index];
            endcase

            // 5. Espera o Master fazer todas as leituras SPI e voltar a ficar livre
            wait(ready == 1'b1);
            
            // Dá um tempo extra para a RAM atualizar o sinal de saída síncrono
            @(posedge clk_100M);
            @(posedge clk_100M); 

            // 6. Checagem Automática usando a saída oficial do TOP (ram_data_o)
            if (ram_data_o === valor_esperado) begin
                $display("[PASS] Sucesso! Valor lido do Sensor %0d: %h. RAM expos corretamente %h no pino data_o.", id_alvo, valor_esperado, ram_data_o);
            end else begin
                $display("[FAIL] ERRO! Sensor %0d enviou %h, mas a RAM expos %h no pino data_o.", id_alvo, valor_esperado, ram_data_o);
                erros++;
            end
            
            addr_esperado++; 
            $display("--------------------------------------------------");
        end
    endtask

        // --- Rotina Principal de Simulação ---
    initial begin
        $display("==================================================");
        $display("   INICIANDO TESTE DO COLETOR MULTI-CLOCK SPI");
        $display("==================================================");
        
        // Sinais Iniciais
        start  = 0;
        reg_id = 0;
        reset  = 1; // CORREÇÃO: Tem que começar em 1!
        
        #10;
        reset = 0;  // Agora sim ocorre o "negedge" e o sistema inicializa
        
        #100;
        reset = 1; //libera reset
        
        // Aguarda o sistema indicar que está pronto para o primeiro comando
        wait(ready == 1'b1);
        #50; 
        
        
        // Realiza um ciclo de leituras para testar os diferentes clocks e a multiplexação
        ler_sensor_e_verificar(2'b00, "Sensor 1 - 15MHz");
        ler_sensor_e_verificar(2'b01, "Sensor 2 - 40MHz");
        ler_sensor_e_verificar(2'b10, "Sensor 3 - 50MHz");
        ler_sensor_e_verificar(2'b11, "Sensor 4 - 25MHz");
        
        // Realiza uma leitura repetida para garantir que o ponteiro interno e de RAM avancem corretamente
        ler_sensor_e_verificar(2'b00, "Sensor 1 - 15MHz (Leitura Registrador 2)");
        
        $display("\n==================================================");
        if (erros == 0) begin
            $display("RESULTADO FINAL: [PASS] - Todos os testes foram bem sucedidos!");
        end else begin
            $display("RESULTADO FINAL: [FAIL] - Ocorreram %0d erros.", erros);
        end
        $display("==================================================");
        
        $stop;
    end

endmodule