module hcsr04
(
	input  					clk			,
	input  					echoPin		,	//echo pin ultrasoničnog senzora
	output reg 				trigPin		,	//triger pin senzora
	output wire [19:0]	o_distance	, 	//udaljenost izracunata na osnovu izmjerenog vremena trajanja impulsa na echo pinu 
	output reg 				M_end				//varijabla kojom se vrši "dojava" glavnom modulu da preuzme izračunatu vrijednost 
													//udaljenosti (tranzicija iz 0 u 1)
);

//brzina zvuka = 331.4 + 0.6*temperatura 
//counter_1cm = (2*0.01 / brzina zvuka) * 50 000 000
reg [21:0] 	counter			 =    0; //brojac za mjerenje vremena trajanja HIGH(LOW) level na triger pinu 
reg [19:0]	echoHighCounter =    0;	//brojac za mjerenje trajanja HIGH level-a na echo pinu (daje informaciju o udaljenosti) 	
reg [11:0] 	counter_1cm		 = 2900;	//sirina impulsa na echo pinu ukoliko je izmjerenja udaljenost 1cm
reg [19:0]  distance;


initial begin
	M_end   <= 0;
	trigPin <= 0;
end

always@(posedge clk) 
begin		
	counter = counter + 1;
	if(counter <= 500)
		trigPin <= 1;
	else
		trigPin <= 0;
	
	if(echoPin) 
		echoHighCounter <= echoHighCounter + 1;
	
	else 
	begin
		if(echoHighCounter!=0)
		begin 
			distance = echoHighCounter;
			echoHighCounter <= 0;
		   if(distance >= 5*counter_1cm && distance <= 180*counter_1cm) M_end = 1;	//vrijednosti udaljenosti ispod 5 i iznad 180 cm 
			else M_end = 0;																			//se odbacuju			
		end
	end
	
	if(counter == 3000500) 
	begin
		counter = 0;
		M_end  <= 0;
	end
end

assign o_distance = distance;
endmodule 