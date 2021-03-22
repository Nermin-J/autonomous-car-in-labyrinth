module algoritamKretanja
(	
	input 				clk,
	input 		 [19:0] USR,		//izmjerena udaljenost sa desnog  ultrason. senzora
	input 		 [19:0]	USL,		//izmjerena udaljenost sa lijevog ultrason. senzora
	input 		 [19:0]	USM,		//izmjerena udaljenost sa ultrason. senzora u sredini	
	input 				endR,		//znak za zavrsetak mjerenja sa  desnog ultras. senzora
	input 				endL,		//znak za zavrsetak mjerenja sa lijevog ultras. senzora
	input 				endM,		//znak za zavrsetak mjerenja   srednjeg ultras. senzora
	output 	reg			TxEnable,//enable signal za slanje vrijednosti preko bluetooth
	output 	reg [ 7:0] 	TxData,	//podaci koje saljemo preko BT
	output 	reg [27:0]	duty,		//ispunjenost impulsom za svaki od ulaza drajvera. Prvih 7 bita (s desna na lijevo) 
											//je za smijer >nazad< motora 2, sljedecih 7 za smijer >nazad< motora 1, sljedecih 7
											//smijer >naprijed< motora 2, zadnjih 7 smijer >naprijed< motor 1 
	output 	reg led,
	output 	reg buzzer
);

reg [26:0] 	statesCounter 	 = 0;		//brojac koji se koristi u stanjima
reg [21:0] 	counterSending 	 = 0;		//brojac za "stalno" slanje podataka na racunar preko BT
reg [16:0] 	countSendingINIT = 0;		//brojač koji se koristi za odgodu između slanja poruke da je izvrsena initialization,
												//i vrijednosti udaljenosti dobijene inicijalizacijom												

/***Udaljenosti koje ocitavamo sa senzora***/
reg [	7:0] distanceL 	= 0;
reg [	7:0] distanceD 	= 0;
reg [ 7:0]   distanceS 	= 0;		

reg [26:0] straight = 70500000	;           //nakon sto se detektuje da auto moze skrenuti u neku stranu, nekoliko vremena 
														//se krece ravno dok ne pocne skretati. to vrijeme je odredjeno ovim brojacem
reg [25:0] turningTime = 55000000;	//vrijeme potrebno da auto skrene odredjeno ovim brojacem
reg [25:0] pause				 = 50000000;	//prije nego se pocne okretati saceka 1 sekundu
reg [26:0] turnTime		 = 80000000;	//vrijeme potrebno da se okrene oko svoje ose
reg [26:0] countSendingTurns =    0;   //dok ovaj brojac ne izbroji do vrijednosti "straight" (tj dok ne pocne skretanje)
												      //ima dozvolu za slanje udaljenosti sa srednjeg senzora  

//varijable potrebne pri inicijalnom mjerenju
reg [ 7:0]  initS	  	   =  0;		//vrijednost udaljenosti dobijena pri inicijalizaciji sa srednjeg senzora
reg 		initEnd		=  0;		//registar za označavanje da (ni)je završena initialization
reg [ 5:0]	numberOfMeasures	= 32;		//broj mjerenja koliko želimo izvršiti pri inicijalizaciji
reg [ 5:0]  NMeasures	= 	0;		//broj mjerenja koliko je izvršeno pri inicijalizaciji
reg [13:0]	sum			=  0;		//sum mjerenja pri inicijalizaciji

/**********FSM konfiguracija************/
reg [ 2:0] 	STATE;					//varijabla za spremanje stanja  
//stanja
parameter IDLE 				= 3'b000;	
parameter INIT 				= 3'b001;	
parameter sendingINIT 		= 3'b010;	
parameter STRAIGHT 			= 3'b011;
parameter turningRIGHT 	= 3'b100;
parameter turningLEFT	= 3'b101;
parameter TURN 			= 3'b110;
parameter END 				= 3'b111; 

//specijalne poruke koje šaljemo preko BT
parameter initialization 	= 3'd1;
parameter turnedRight 		= 3'd2;
parameter turnedLeft 	= 3'd3;
parameter turned 		= 3'd4; 


reg [7:0] turns = 0;	//registar za spremanje turns kada moze skrenuti na neku stranu i kada moze nastaviti straight  
									//(bit 1 znaci da je u tom slucaju skrenuo desno, 0 - skrenuo lijevo)
reg [7:0] turning = 0;	//registar koji sluzi za oznacavanje da se auto, nakon sto je skrenulo u neku stranu a moglo je 
									//nastaviti straight, zaokrenulo tj nije naslo izlaz. bit 1 - auto se zaokrenulo, bt 0 - nije se
									//zaokrenulo. Index bita odgovara indexu bita koji u registru "turns" oznacava da je auto 
									//skrenulo u neku stranu iako je moglo nastaviti straight.
integer index = 0;			//index za kretanje po registru (bitima) 

initial begin
	STATE <= IDLE;
	duty   	<= {7'd0, 7'd0, 7'd0, 7'd0};
end

wire rightBigger;
wire leftBigger;
wire centralSmaller9;
wire centralBigger43;

/***assign na wire koje se koriste prilikom odlučivanja da li ce auto skrenuti, zaokrenuti se itd***/
assign rightBigger = distanceD > 21;
assign leftBigger = distanceL > 21;
assign centralBigger43 = distanceS > 43;
assign centralSmaller9 = distanceS <= 9;

/*******Ažuriranje vrijednosti udaljenosti kada senzor završi mjerenje. Ažuriranje se vrši na uzlaznu *********
************************ivicu varijable M_end koja se nalazi u modulu hcsr04**********************************/
always@(posedge endR)
begin
	distanceD = USR >> 11;		//šiftanje bita za 11 mjesta - ekvivalentno dijeljenju sa 2^11 = 2048
end

always@(posedge endL)
begin
	distanceL = USL >> 11;
end

always@(posedge endM)
begin
		if(STATE == INIT)				//Ako je STATE == INIT ne vršimo jednostavno ažuriranje vrijednosti nego moramo izvršiti
		begin								//više mjerenja u cilju inicijalizacije	
			NMeasures = NMeasures + 1;
			distanceS = USM >> 11;
			sum = sum + distanceS;
			if(NMeasures == numberOfMeasures) 
			begin
				initS = sum >> 5;	//Izvršili smo 32 mjerenja i umjesto da u cilju dobijanja srednje vrijedsnoti mjerenja 
				initEnd = 1;			//sumu podijelimo sa 32, vršimo šiftanje bita za 5 mjesta što je ekvivalentno dijeljenju 
			end							//sa 2^5 = 32 što je mnogo "jeftinija" operacija
		end
		
		else 
		begin
			sum <= 0;
			NMeasures <= 0;
			distanceS <= USM >> 11;
			initEnd <= 0;
		end
end
/***************Kod za ažuriranje mjerenja - kraj*****************/

/*********FSM-kretanje*********/
always@(posedge clk)
begin
	case(STATE)		
		IDLE:	
		begin 
			statesCounter = statesCounter + 1;
			duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			if(statesCounter == 50000000) 		//čekamo 1 sekundu
			begin	
				STATE 			<= INIT;				
				statesCounter 	<= 0;					//koristimo isti counter za mjerenja vremena u svim stanjima pa ga svaki put 
			end											//pri prelazu u novo stanje moramo resetovati							
			else STATE 			<= IDLE;
		end
	
		INIT:	
		begin
			duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			if(initEnd) STATE <= sendingINIT;		//nakon što dobijemo informaciju da je završena initialization prelazimo u
			else STATE 			<= INIT;				//stanje u kome šaljemo poruku da je izvršena initialization i šaljemo
		end												//poruku o inicijalnoj vrijednosti	
		
		sendingINIT:
		begin
			duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			statesCounter <= statesCounter + 1;
			if(statesCounter == 100005) 	//cekamo da se posalju podaci (poruka da je izvrsena initialization i slanje 
			begin									//inicijalne vrijednosti) iz modula koji sluzi za slanje. Cekamo malo vise nego
				STATE <= STRAIGHT;				//traje slanje (100001) 
				statesCounter <= 0; 
			end
			else STATE 			<= sendingINIT;
		end
		
		STRAIGHT:
		begin
			if(turning[index]==0) normalMoving;	//ako se auto nije zaokrenulo(kada ne nadje izlaz) krece se "normalno"
																	//ovo kretanje je određeno taskom "normalMoving" koji se nalazi ispod
			else	//ako se auto zaokrenulo oko svoje ose skreće gdje god može osim u slučaju	da može nastaviti i ravno. 
			begin		//Ovo kretanje traje sve dok auto ne dodje u situaciju da može skrenuti i lijevo i desno. U tom slučaju
				case({rightBigger, leftBigger, centralBigger43})	//odluku gdje će skrenuti donosi na osnovu informacije iz registra	
					3'b110:												//turns, gdje je spremljena informacija u kom smijeru je auto
					begin													//skrenulo kada je uslo u ovu "sporednu" putanju
						index = index - 1;					
						if(turns[index+1] == 1)
							STATE <= turningRIGHT;
						else 
							STATE <= turningLEFT;
					end
								
					3'b100: STATE <= turningRIGHT;	
					
					3'b010:
					begin
						statesCounter = statesCounter + 1;
						if(statesCounter==3001000) 
						begin
							if({rightBigger, leftBigger, centralBigger43}==3'b010) 
							begin 
								STATE <= turningLEFT; 
								statesCounter = 0; 
							end
						end
					end
					
					3'b000: 
					begin
						if(centralSmaller9) STATE <= TURN;
					end
					
					3'b101, 3'b001: followLeft;
					3'b011: followRight;			
				endcase
			end
		end
				
		turningLEFT:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= straight)
				duty <= {7'd60, 7'd60, 7'd0, 7'd0};
			
			else if(statesCounter > straight && statesCounter < straight + turningTime)
				duty <= {7'd80, 7'd0, 7'd0, 7'd0};
			
			else if (statesCounter == straight + turningTime)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			end
		end
		
		turningRIGHT:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= straight)
				duty <= {7'd60, 7'd60, 7'd0, 7'd0};
			
			else if(statesCounter > straight && statesCounter < straight + turningTime)
				duty <= {7'd0, 7'd80, 7'd0, 7'd0};
			
			else if (statesCounter == straight + turningTime)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			end
		end
		
		TURN:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= pause)
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			
			else if(statesCounter > 50000000 && statesCounter < 50000000 + turnTime)
				begin duty <= {7'd0, 7'd65, 7'd75, 7'd0};
					end
			else if (statesCounter == 50000000 + turnTime)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				turning[index] = 1;
			end
		end
		
		END:
		begin
			duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			statesCounter <= statesCounter + 1;
			if(statesCounter == 25000000)
			begin
				led <= !led;
				buzzer <= !buzzer;
				statesCounter <= 0;
			end
		end
		
		default:
        STATE <= IDLE;
	endcase
end


/********task-ovi za kretanje********/ 
task normalMoving;
	if(!leftBigger && !rightBigger && !centralSmaller9) followLeft;	//ako se auto nalazi između dva zida prati lijevi zid		
	else if(leftBigger && centralBigger43 && distanceD > 11 && !rightBigger) STATE <= END; 	//u slucaju specificisnih 
																								//vrijednosti - znak da je dosao do kraja tj izasao
	else if(leftBigger || rightBigger)							//moze skrenuti lijevo ili desno
	begin
		if(centralBigger43)											//moze skrenuti lijevo(ili desno) a moze ici i ravno
		begin
			index = index + 1;
			turning[index] = 0;
			turns[index] = leftBigger ? 0 : 1;			//memorisemo da je na raskrsnici skrenuo lijevo(0) ili desno(1)
		end
		STATE <= leftBigger ? turningLEFT : turningRIGHT; 	//i ako je mogao nastaviti i ako nije, skrenut ce
	end
	else if(!leftBigger && !rightBigger && centralSmaller9) 			//dosao do kraja zida
	begin
		STATE <= TURN;
	end
endtask

task followLeft;
	if(distanceL == 11)	  duty <= {7'd55, 7'd55, 7'd0, 7'd0};  //11 -> 8cm
	if(distanceL < 11) 	  duty <= {7'd55, 7'd65, 7'd0, 7'd0};
	else if(distanceL > 11) duty <= {7'd65, 7'd55, 7'd0, 7'd0};
endtask

task followRight;
	if(distanceD == 11)	  duty <= {7'd55, 7'd55, 7'd0, 7'd0};
	if(distanceD < 11) 	  duty <= {7'd65, 7'd55, 7'd0, 7'd0};
	else if(distanceD > 11) duty <= {7'd55, 7'd65, 7'd0, 7'd0};
endtask
/*************task-ovi za kretanje - kraj ************/


/*********FSM za slanje podataka**********/
always@(posedge clk)				//always blok koji služi za slanje podataka preko BT
begin
	case(STATE)
		sendingINIT:
		begin
			countSendingINIT = countSendingINIT + 1; 
			if(countSendingINIT == 1)
			begin
				TxData 	<= initialization;  //specijalna poruka koju saljemo kako bismo oznacili da je izvrsena initialization
				TxEnable <= 1;
			end
				
			else if(countSendingINIT == 100000)  //malo sacekamo nako slanja poruke da je izvrsena initialization
			begin
				TxData 	<= initS;					//šaljemo inicijalnu vrijednost 				
				TxEnable <= 1;
			end 
				
			else if(countSendingINIT == 100001)
			begin
				TxEnable 		 <= 0;
				counterSending	 <= 0;
				//countSendingINIT <= 0;  //NE resetovati ovdje
			end
				
			else TxEnable <= 0;
		end
		
		STRAIGHT:
		begin
			countSendingTurns <= 0;
			counterSending <= counterSending + 1;
			if(counterSending==3000500)	//podatke od udaljenosti šaljemo nakon svakom mjerenja (jedan ciklus mjerenja traje
			begin								//60ms (3000500 ciklusa za klok 50MHz) što je određeno u modulu hcsr04
				TxData 			 <= distanceS;
				TxEnable 		 <= 1;
				counterSending	 <= 0;
				countSendingINIT <= 0;			//resetujemo ga ovdje a ne ispod u slucaju kada je stanje "sendingINIT" i kada je
			end										//counterSendingINIT == 100001. Kada bismo ga resetovali ispod, moglo bi se desiti 
														//da više puta pošalje istu poruku iz razloga što je uslov "STATE == sendingINIT"
			else										//a u ovom stanju ostajemo neko vrijeme (if-ovi za prelaz na sljedece stanje i 
				TxEnable <= 0;						//ostanak u stanju sendingINIT iznad u kodu (FSM za kretanje)). Jedan od načina 
		end											//rješenja problema, kada ne bismo ovdje vrsili reset jeste da postavimo isti 
														//tajmer u uslovima za prelaz u sljedece stanje ali je ovako sigurnije
		turningLEFT:
		begin
			countSendingTurns = countSendingTurns + 1;
			if(countSendingTurns <= straight) //dok ne pocne skretati i dalje salje vrijednosti o udaljenosti jer se dok ne 	 
			begin										 //izbroji do "straight" kreće ravno
				counterSending <= counterSending + 1;
				if(counterSending==3000500)
				begin
					TxData 			<= distanceS;
					TxEnable 		<= 1;
					counterSending	<= 0;
				end										 									
				else				
					TxEnable <= 0;	
			end
			
			else 
			begin
				if(TxData != turnedLeft)		//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
				begin										//TxData ostaje spremljena ova poruka)
					TxData 	<= turnedLeft;
					TxEnable <= 1;
				end
				else TxEnable <= 0;
			end
		end
		
		turningRIGHT:
		begin
			countSendingTurns = countSendingTurns + 1;
			if(countSendingTurns <= straight) 
			begin
				counterSending <= counterSending + 1;
				if(counterSending==3000500)
				begin
					TxData 			<= distanceS;
					TxEnable 		<= 1;
					counterSending	<= 0;				
				end										 									
				else				
					TxEnable <= 0;	
			end
			
			else
			begin
				if(TxData != turnedRight)			//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
				begin										//TxData ostaje spremljena ova poruka)
					TxData 	<= turnedRight;
					TxEnable <= 1; 
				end
				else TxEnable <= 0;
			end
		end
		
		TURN:
		begin
			if(TxData != turned)				//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
			begin										//TxData ostaje spremljena ova poruka)
				TxData 	<= turned;
				TxEnable <= 1;
			end
			else TxEnable <= 0;
		end
	endcase
	
end

endmodule
