module PWM_generator 
(
	input 					clk	,
	input  		[27:0] 	duty	,	//proslijeđene (iz modula "algoritamKretanja") vrijednosti duty za svaki od ulaza 
											//driver-a L298N(za svaki ulaz duty zapisan sa 7 bita -> 4*7=28 bita registar)
	output reg 	[ 3:0] 	IN			//izlazi na driver (ulazi driver-a oznaceni sa IN1, IN2, IN3, IN4) 	
);

//Na driver dovodimo PWM signale frekvencije 8kHz što odgovara 6250 klok ciklusa 50MHz-nog kloka. Zbog lakšeg proračuna
//ispunjenosti impulsom (pišemo 62*duty), umjesto 6250 uzet ćemo 6200 ciklusa pri čemu se frekvencija vrlo malo promijeni
reg [12:0] counter; //maksimalna vrijednost za counter 6200 -> dovoljno 13 bita za spremanje vrijednosti

always@(posedge clk)
begin
	counter = counter + 1;
	if(counter <= 62*duty[6:0])	
		IN[0] <= 1;
	else 
		IN[0] <= 0;
	
		if(counter <= 62*duty[13:7])
		IN[1] <= 1;
	else 
		IN[1] <= 0;
		
	if(counter <= 62*duty[20:14])
		IN[2] <= 1;
	else 
		IN[2] <= 0;
				
	if(counter <= 62*duty[27:21])
		IN[3] <= 1;
	else 
		IN[3] <= 0;
	
	if(counter == 6200)
		counter <= 0;
end

endmodule 