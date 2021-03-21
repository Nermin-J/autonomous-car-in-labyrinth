module TOP
(
	input  		 clk	,
	input  		 echoR,	
	input  		 echoL,
	input  		 echoM,
	
	output 		 trigR,	//R - right, L - left, M-middle
	output 		 trigL,
	output 		 trigM,
	
	output 		 Tx	,
	output [3:0] motors_PWM,
	
	output 		 led,
	output 		 buzzer
);

wire [ 7:0] dataTransmit;
wire 			TxEnable 	;
wire [19:0] distanceR	;
wire [19:0] distanceL	;
wire [19:0] distanceM	;
wire 			endR 			;
wire 			endL			;
wire 			endM			;
wire [27:0]	duty			;

UART_Tx UART_Transmitter(
   .i_Clock(clk)        	,
	.i_TX_DV(TxEnable)     	,
   .i_TX_Byte(dataTransmit),
	.o_TX_Serial(Tx) 
);

algoritamKretanja AK
(
	.clk(clk)		,
	.USR(distanceR),
	.USL(distanceL),
	.USM(distanceM),
	.endR(endR)		,
	.endL(endL)		,
	.endM(endM)		,
	.TxEnable(TxEnable)	,
	.TxData(dataTransmit),
	.duty(duty),
	.led(led),
	.buzzer(buzzer)
);

hcsr04 UltrasonicR
(
	.clk(clk)		,
	.echoPin(echoR),
	.trigPin(trigR),
	.o_distance(distanceR),
	.M_end(endR)
);

hcsr04 UltrasonicL
(
	.clk(clk)		,
	.echoPin(echoL),
	.trigPin(trigL),
	.o_distance(distanceL),
	.M_end(endL)	
);

hcsr04 UltrasonicM
(
	.clk(clk)		,
	.echoPin(echoM),
	.trigPin(trigM),
	.o_distance(distanceM),
	.M_end(endM)
);

PWM_generator PWM
(
	.clk(clk)	,
	.duty(duty)	,
	.IN(motors_PWM)
);
endmodule
