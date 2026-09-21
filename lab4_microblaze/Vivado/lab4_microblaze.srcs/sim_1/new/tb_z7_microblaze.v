// tb_z7_light_microblaze.v
//
// Testbench для повного проєкту: MicroBlaze + AXI GPIO x3 + AXI Timer.
// Behavioral simulation з реальним .elf, підключеним через
// Tools -> Associate ELF Files (колонка Simulation).
//
// .elf має бути зібраний з -DSIM_BUILD: у робочій прошивці крок доріжки
// триває від 0.1 до 5 секунд, тобто до 250 мільйонів тактів на один крок.
// Симулювати таке неможливо, тому симуляційна збірка використовує періоди
// в тактах замість секунд.
//
// Полярності (звірено з .xdc):
//   clk_50m     50 МГц, період 20 нс
//   reset_n     активний низький
//   btn_tri_io  активний низький, відпущена кнопка = 1
//   sw_tri_io   активний низький, 1 = вперед, 0 = назад
//   led_tri_io  активний високий, one-hot: горить рівно один світлодіод

`timescale 1ns / 1ps

module tb_z7_microblaze;

    // ---- Параметри часу --------------------------------------------------
    // Крок за замовчуванням у SIM_BUILD = 400 тактів = 8 мкс.
    // Період опитування = 500 тактів = 10 мкс, антидребезг = 2 відліки.
    // Отже кнопку треба тримати щонайменше 30 мкс, щоб натискання зарахувалось.

    localparam real CLK_PERIOD_NS = 20.0;     // 50 MHz
    localparam      PRESS_NS      = 40_000;   // hold long enough to debounce
    localparam      SETTLE_NS     = 40_000;   // watch a few steps after a press
    localparam      BOOT_NS       = 2_000_000;  // MicroBlaze boot + init margin

    // ---- Сигнали ---------------------------------------------------------
    reg         clk_50m = 1'b0;
    reg         reset_n = 1'b0;

    // Кнопки й перемикач: testbench керує лініями, FPGA тримає їх у Hi-Z,
    // бо відповідні AXI GPIO налаштовані на вхід.
    reg  [3:0]  btn_drv = 4'b1111;   // all released
    reg  [0:0]  sw_drv  = 1'b1;      // forward

    wire [3:0]  btn_tri_io;
    wire [0:0]  sw_tri_io;
    wire [3:0]  led_tri_io;

    assign btn_tri_io = btn_drv;
    assign sw_tri_io  = sw_drv;

    // ---- DUT -------------------------------------------------------------
    z7_light_microblaze_wrapper dut (
        .clk_50m    (clk_50m),
        .reset_n    (reset_n),
        .btn_tri_io (btn_tri_io),
        .sw_tri_io  (sw_tri_io),
        .led_tri_io (led_tri_io)
    );

    // ---- Такт ------------------------------------------------------------
    always #(CLK_PERIOD_NS / 2.0) clk_50m = ~clk_50m;

    // ---- Спостереження за доріжкою --------------------------------------
    // Лічильник кроків дозволяє перевірити, що рух триває, а не завмер.

    reg  [3:0] led_prev  = 4'b0000;
    integer    step_count = 0;

    always @(posedge clk_50m) begin
        if (led_tri_io !== led_prev) begin
            led_prev <= led_tri_io;
            if (led_tri_io !== 4'b0000) begin
                step_count = step_count + 1;
                $display("[%0t ns] led = %b", $time, led_tri_io);
            end
        end
    end

    // ---- Задачі ----------------------------------------------------------

    // Wait until the firmware lights the first LED instead of guessing a
    // fixed boot delay. The timeout guard below catches a dead image.
    task wait_for_boot;
        begin
            $display("[%0t ns] waiting for firmware...", $time);
            wait (led_tri_io !== 4'b0000);
            $display("[%0t ns] firmware alive, led = %b", $time, led_tri_io);
            #SETTLE_NS;
        end
    endtask

    // Натискання кнопки: лінія активна низьким, тому притискаємо біт до нуля.
    task press_button(input integer index);
        begin
            $display("[%0t ns] --- press BTN%0d ---", $time, index);
            btn_drv[index] = 1'b0;
            #PRESS_NS;
            btn_drv[index] = 1'b1;
            #SETTLE_NS;
        end
    endtask

    // Перевірка, що горить рівно один світлодіод.
    task check_one_hot;
        begin
            case (led_tri_io)
                4'b0001, 4'b0010, 4'b0100, 4'b1000:
                    $display("[%0t ns] PASS one-hot: led = %b", $time, led_tri_io);
                default:
                    $display("[%0t ns] FAIL one-hot: led = %b", $time, led_tri_io);
            endcase
        end
    endtask

    // Перевірка, що доріжка рухається: лічильник кроків має зрости.
    task check_moving(input [8*32-1:0] label);
        integer before;
        begin
            before = step_count;
            #SETTLE_NS;
            if (step_count > before) begin
                $display("[%0t ns] PASS %0s: %0d steps", $time, label,
                         step_count - before);
            end else begin
                $display("[%0t ns] FAIL %0s: no movement", $time, label);
            end
        end
    endtask

    // Перевірка, що доріжка стоїть.
    task check_stopped(input [8*32-1:0] label);
        integer before;
        begin
            before = step_count;
            #SETTLE_NS;
            if (step_count == before) begin
                $display("[%0t ns] PASS %0s: stopped", $time, label);
            end else begin
                $display("[%0t ns] FAIL %0s: still moving", $time, label);
            end
        end
    endtask

    // ---- Сценарій --------------------------------------------------------
    initial begin
        $display("=== MicroBlaze running light: behavioral simulation ===");

        // Скид утримується активним (низьким) на старті.
        reset_n = 1'b0;
        #1_000;
        reset_n = 1'b1;
        $display("[%0t ns] reset released", $time);

        // MicroBlaze має завантажитись, ініціалізувати GPIO, таймер і INTC.
        // Запас орієнтовний: скоригувати за реальним waveform.
//        #BOOT_NS;
        wait_for_boot;
        
        check_one_hot;
        check_moving("initial run");

        // Зміна напрямку на ходу.
        $display("[%0t ns] --- switch to reverse ---", $time);
        sw_drv = 1'b0;
        check_moving("reverse");

        $display("[%0t ns] --- switch back to forward ---", $time);
        sw_drv = 1'b1;
        check_moving("forward");

        // Швидкість.
        press_button(0);                  // faster
        check_moving("after speed up");

        press_button(1);                  // slower
        check_moving("after speed down");

        // Зупинка та продовження.
        press_button(2);                  // stop
        check_stopped("after stop");

        press_button(2);                  // resume
        check_moving("after resume");

        // Скид налаштувань.
        press_button(3);                  // reset defaults
        check_one_hot;
        check_moving("after reset");

        $display("=== simulation finished, %0d steps total ===", step_count);
        $finish;
    end

    // ---- Запобіжник ------------------------------------------------------
    // Якщо щось зависне, симуляція не крутитиметься вічно.
    initial begin
        #5_000_000;
        $display("*** TIMEOUT: simulation exceeded 5 ms ***");
        $finish;
    end

endmodule