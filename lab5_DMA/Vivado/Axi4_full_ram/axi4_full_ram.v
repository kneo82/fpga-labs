// axi4_full_ram.v
// Простий AXI4 (Full) slave. Порти названі за офіційною конвенцією
// Vivado (interface_name + "_" + AXI signal name, тут "s_axi_..."),
// щоб Package IP міг АВТОМАТИЧНО розпізнати AXI4-інтерфейс без
// ручного втручання (підтверджено офіційною документацією UG1118).
//
// ЗМІНЕНО: доступ до масиву mem винесено в окремий always-блок без
// скиду. Оригінальна версія читала й писала mem усередині блоків з
// асинхронним скидом (negedge s_axi_aresetn). Для MEM_DEPTH = 256 це
// не заважало -- 8 Кбіт синтезатор розкладав у LUT. Для 16384 слів
// (512 Кбіт) масив ОБОВ'ЯЗКОВО має лягти у block RAM, а BRAM у 7-й
// серії не підтримує асинхронний скид вихідного регістра. Звідси
// помилка Synth 8-3391 "Unable to infer a block/distributed RAM".
//
// Автомати керування залишилися без змін -- вони працюють зі скидом,
// як і раніше. Змінилося лише те, ЯК вони звертаються до пам'яті:
// через сигнали mem_we / mem_re / адреси замість прямого індексування.

module axi4_full_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter MEM_DEPTH  = 256
) (
    input  wire                        s_axi_aclk,
    input  wire                        s_axi_aresetn,

    input  wire [ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  wire [7:0]                  s_axi_awlen,
    input  wire [2:0]                  s_axi_awsize,
    input  wire [1:0]                  s_axi_awburst,
    input  wire                        s_axi_awvalid,
    output wire                        s_axi_awready,

    input  wire [DATA_WIDTH-1:0]       s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0]     s_axi_wstrb,
    input  wire                        s_axi_wlast,
    input  wire                        s_axi_wvalid,
    output wire                        s_axi_wready,

    output reg  [1:0]                  s_axi_bresp,
    output reg                         s_axi_bvalid,
    input  wire                        s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]       s_axi_araddr,
    input  wire [7:0]                  s_axi_arlen,
    input  wire [2:0]                  s_axi_arsize,
    input  wire [1:0]                  s_axi_arburst,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,

    output reg  [DATA_WIDTH-1:0]       s_axi_rdata,
    output reg                         s_axi_rlast,
    output reg  [1:0]                  s_axi_rresp,
    output reg                         s_axi_rvalid,
    input  wire                        s_axi_rready
);

    localparam integer INDEX_WIDTH = ADDR_WIDTH - 2;

    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // ------------------------------------------------------------------
    // Write channel FSM
    // ------------------------------------------------------------------
    localparam WRIDLE = 2'd0, WRDATA = 2'd1, WRRESP = 2'd2;
    reg [1:0] wstate;
    reg [ADDR_WIDTH-1:0] waddr_cur;
    reg [7:0] wburst_cnt;

    assign s_axi_awready = (wstate == WRIDLE);
    assign s_axi_wready  = (wstate == WRDATA);

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            wstate <= WRIDLE;
            s_axi_bvalid <= 1'b0;
        end else case (wstate)
            WRIDLE: begin
                if (s_axi_awvalid) begin
                    waddr_cur  <= s_axi_awaddr;
                    wburst_cnt <= s_axi_awlen;
                    wstate     <= WRDATA;
                end
            end
            WRDATA: begin
                if (s_axi_wvalid && s_axi_wready) begin
                    // The array itself is written in the dedicated block
                    // below; here only the address advances.
                    waddr_cur <= waddr_cur + 4;
                    if (wburst_cnt == 0) begin
                        wstate <= WRRESP;
                    end else begin
                        wburst_cnt <= wburst_cnt - 1'b1;
                    end
                end
            end
            WRRESP: begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    wstate <= WRIDLE;
                end
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Read channel FSM
    // ------------------------------------------------------------------
    localparam RDIDLE = 2'd0, RDDATA = 2'd1;
    reg [1:0] rstate;
    reg [ADDR_WIDTH-1:0] raddr_cur;
    reg [7:0] rburst_cnt;

    assign s_axi_arready = (rstate == RDIDLE);

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            rstate <= RDIDLE;
            s_axi_rvalid <= 1'b0;
        end else case (rstate)
            RDIDLE: begin
                s_axi_rvalid <= 1'b0;
                if (s_axi_arvalid) begin
                    raddr_cur  <= s_axi_araddr;
                    rburst_cnt <= s_axi_arlen;
                    rstate     <= RDDATA;
                end
            end
            RDDATA: begin
                if (!s_axi_rvalid || (s_axi_rvalid && s_axi_rready)) begin
                    // s_axi_rdata is driven by the memory block below, in
                    // the very same clock edge, so the timing is unchanged.
                    s_axi_rresp  <= 2'b00;
                    s_axi_rvalid <= 1'b1;
                    s_axi_rlast  <= (rburst_cnt == 0);
                    if (rburst_cnt != 0) begin
                        raddr_cur  <= raddr_cur + 4;
                        rburst_cnt <= rburst_cnt - 1'b1;
                    end else if (s_axi_rvalid && s_axi_rready) begin
                        rstate <= RDIDLE;
                    end
                end
            end
        endcase
    end

    // ------------------------------------------------------------------
    // Memory array
    //
    // No reset of any kind here: this is what lets the synthesiser map
    // the array onto block RAM. BRAM contents come from the bitstream,
    // not from a reset, so nothing is lost by dropping it.
    //
    // Byte strobes are ignored, exactly as in the original module. The
    // DMA writes whole 32-bit words, so partial writes never occur.
    // ------------------------------------------------------------------
    wire                   mem_we    = (wstate == WRDATA) && s_axi_wvalid && s_axi_wready;
    wire                   mem_re    = (rstate == RDDATA) && (!s_axi_rvalid || s_axi_rready);
    wire [INDEX_WIDTH-1:0] mem_waddr = waddr_cur[ADDR_WIDTH-1:2];
    wire [INDEX_WIDTH-1:0] mem_raddr = raddr_cur[ADDR_WIDTH-1:2];

    always @(posedge s_axi_aclk) begin
        if (mem_we) begin
            mem[mem_waddr] <= s_axi_wdata;
        end
        if (mem_re) begin
            s_axi_rdata <= mem[mem_raddr];
        end
    end

endmodule