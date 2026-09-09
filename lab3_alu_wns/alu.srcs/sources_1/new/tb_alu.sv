// tb_alu.sv
// Testbench для alu.sv: task + self-checking (===) + специфікатори $display
// + явна демонстрація станів X і Z.
//
// ВАЖЛИВО: alu.sv має РЕЄСТРОВІ входи Й реєстровий вихід -> результат
// з'являється не на наступному такті, а через ДВА такти після зміни
// входів. check_alu враховує це явно (два @(posedge clk) поспіль).
//
// Запуск через GUI (Vivado): Run Simulation -> Run Behavioral Simulation.
// Запуск через консоль (Vivado XSim):
//     xvlog alu.sv tb_alu.sv
//     xelab tb_alu -s tb_sim
//     xsim tb_sim -R
// Запуск локально (Icarus Verilog, для швидкої перевірки без Vivado):
//     iverilog -g2012 -o sim alu.sv tb_alu.sv
//     vvp sim

module tb_alu;

    logic        clk;
    logic        rst;
    logic [3:0]  a, b;
    logic [1:0]  op;
    logic        oe;
    logic [3:0]  result;

    alu dut (
        .clk(clk), .rst(rst),
        .a(a), .b(b), .op(op),
        .oe(oe), .result(result)
    );

    // ---- Генератор такту ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Self-checking task (з урахуванням 2-тактової затримки) ----
    task automatic check_alu(
        input [3:0]  a_val,
        input [3:0]  b_val,
        input [3:0]  expected,
        input [1:0]  op_val,
        input string name
    );
        a = a_val;  b = b_val;  op = op_val;
        @(posedge clk); #1;     // такт 1: входи потрапляють у a_reg/b_reg/op_reg
        @(posedge clk); #1;     // такт 2: result_reg оновлюється з alu_result
        if (result === expected)
            $display("[%0t нс] PASS: %-8s -> result=%0d (0x%h, %b)",
                      $time, name, result, result, result);
        else
            $display("[%0t нс] FAIL: %-8s -> had to be %0d, got %0d (may be X/Z: %b)",
                      $time, name, expected, result, result);
    endtask

    initial begin
        // ---- 1. Демонстрація стану X: одразу після старту, до reset ----
        oe = 1;
        $display("[%0t ns] before reset: result = %b  <- state X, result_reg didn't get any value",
                  $time, result);

        // ---- 2. Reset ----
        rst = 1;  a = 4'd0;  b = 4'd0;  op = 2'd0;
        @(posedge clk); #1;
        rst = 0;
        $display("[%0t ns] after reset: result = %0d", $time, result);

        // ---- 3. Self-checking перевірка всіх 4 операцій ----
        check_alu(4'd5, 4'd3, 4'd8, 2'b00, "5+3=8");
        check_alu(4'd7, 4'd2, 4'd5, 2'b01, "7-2=5");
        check_alu(4'd6, 4'd5, 4'd4, 2'b10, "6&5=4");
        check_alu(4'd6, 4'd5, 4'd7, 2'b11, "6|5=7");

        // ---- 4. Демонстрація стану Z: вимикаємо вихід через oe ----
        oe = 0;
        #1;
        $display("[%0t ns] oe=0: result = %b  <- state Z, Not connected", $time, result);
        oe = 1;
        #1;
        $display("[%0t ns] oe=1: result = %b  <- Output returned", $time, result);

        $display("[%0t ns] Simulation complete", $time);
        $finish;
    end

endmodule
