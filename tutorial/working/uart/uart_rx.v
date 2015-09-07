`include "baudgen.vh"

`default_nettype none

module uart_rx(
   input wire clk,         //-- Relog del sistema
   input wire rstn,        //-- Reset sincrono activo a nivel bajo
   input wire rx,          //-- Datos provenientes de la linea serie
   output wire [7:0] data,  //-- Datos recibidos
   output wire rs         //-- Validacion de los datos (para su captura)
);

parameter BAUD = `B115200;

wire ser_clk;
reg restart = 0;

//-- GENERADOR DEL RELOJ
baudgen #(BAUD >> 1)
  DIV0 (
    .clk_in(clk),
    .restart(restart),
    .clk_out(ser_clk)
  );


//-- CONTADOR DE CARACTERES RECIBIDOS (PARA DEBUG)
reg [3:0] car_counter;
reg car_counter_enable = 0;

always @(posedge clk)
  if (!rstn)
    car_counter <= 0;
  else if (car_counter_enable)
    car_counter <= car_counter + 1;

//-- REGISTRO DE DATO RECIBIDO
reg regdata_load = 0;

//-- CONTADOR DE TICS
reg [4:0] tics_counter = 0;
reg bitcounter_enable = 0;


always @(posedge clk)
  if (!rstn)
    tics_counter <= 0;
  else if (!bitcounter_enable)
    tics_counter <= 0;
  else if (ser_clk)
    tics_counter <= tics_counter + 1;



//-- REGISTRO DE DESPLAZAMIENTO
reg [8:0] shifter = 0;
reg shift = 0;  //-- Modo: shift = 1 desplzamiento, 0 stop (no habilitado)


always @(posedge ser_clk)
  if (!rstn)
    shifter <= 9'b1_1111_1111;
  else if (shift & tics_counter[0]==1)
    shifter <= {rx, shifter[8:1]};

reg [7:0] regdata;

always @(posedge clk)
  if (!rstn)
    regdata <= 0;
  else if (regdata_load)
    regdata <= shifter[7:0];

//-- MAQUINA DE ESTADOS
localparam IDLE = 0;
localparam START = 1;
localparam RECEIVING = 2;
localparam FINISH = 3;
localparam READY = 4;

reg [2:0] state = IDLE;
reg ready = 0;

//assign data = (state == FINISH) ? 8'h04 : 0;

//assign data = {4'b0000, car_counter[0], shifter[2:0]};

//assign data = {4'b0000, car_counter};

assign data =  regdata; //shifter[7:0]; //regdata;

assign rs = ready;//regdata_load;

//-- Salidas del automata del receptor
always @* begin
  case (state)
    IDLE: begin
      restart <= 1;
      shift <= 0;
      bitcounter_enable <= 0;
      car_counter_enable <= 0;
      regdata_load <= 0;
      ready <= 0;
      end

    START: begin
        restart <= 0;  //-- Arrancar reloj
        shift <= 1;    //-- activar reg. de desplazamiento
        bitcounter_enable <= 1;
        car_counter_enable <= 0;
        regdata_load <= 0;
        ready <= 0;
      end

    RECEIVING: begin
        restart <= 0;
        shift <= 1;
        bitcounter_enable <= 1;
        car_counter_enable <= 0;
        regdata_load <= 0;
        ready <= 0;
      end

    FINISH: begin
        restart <= 1;
        shift <= 0;
        bitcounter_enable <= 0;
        car_counter_enable <= 1;
        regdata_load <= 1;
        ready <= 0;
      end

    READY: begin
        restart <= 1;
        shift <= 0;
        bitcounter_enable <= 0;
        car_counter_enable <= 0;
        regdata_load <= 0;
        ready <= 1;
      end

    default: begin
      restart <= 1; 
      shift <= 0;
      bitcounter_enable <= 0;
      car_counter_enable <= 0;
      regdata_load <= 0;
      ready <= 0;
      end

  endcase
end

//-- Estados del automata
always @(posedge clk)
  if (!rstn)
    state <= IDLE;
  else
    case (state)
     
      //-- Esta inicial. Reposo
      IDLE:
        if (rx == 0)
          state <= START;
        else
          state <= IDLE;

      //-- Recibido bit de start. Arrancar el reloj serie
      //-- Habilitar registro de desplazamiento
      START:
         state <= RECEIVING; //RECEIVING;

      
      //-- Recibiendo datos sobremuesreados en el reg de desplazamiento
      RECEIVING:
         if (tics_counter == 20)
           state <= FINISH;
         else
           state <= RECEIVING;
        
      //-- Terminado. Dato disponible
      FINISH:
           state <= READY;

      READY:
           state <= IDLE;
        
      default:
        state <= IDLE;
    endcase


endmodule





