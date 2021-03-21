module algoritamKretanja
(	
	input 					clk,
	input 		 [19:0] 	USR,		//izmjerena udaljenost sa desnog  ultrason. senzora
	input 		 [19:0]	USL,		//izmjerena udaljenost sa lijevog ultrason. senzora
	input 		 [19:0]	USM,		//izmjerena udaljenost sa ultrason. senzora u sredini	
	input 					endR,		//znak za zavrsetak mjerenja sa  desnog ultras. senzora
	input 					endL,		//znak za zavrsetak mjerenja sa lijevog ultras. senzora
	input 					endM,		//znak za zavrsetak mjerenja   srednjeg ultras. senzora
	output 	reg			TxEnable,//enable signal za slanje vrijednosti preko bluetooth
	output 	reg [ 7:0] 	TxData,	//podaci koje saljemo preko BT
	output 	reg [27:0]	duty,		//ispunjenost impulsom za svaki od ulaza drajvera. Prvih 7 bita (s desna na lijevo) 
											//je za smijer >nazad< motora 2, sljedecih 7 za smijer >nazad< motora 1, sljedecih 7
											//smijer >naprijed< motora 2, zadnjih 7 smijer >naprijed< motor 1 
	output 	reg led,
	output 	reg buzzer
);

reg [26:0] 	statesCounter 	 = 0;		//brojac koji se koristi u stanjima
reg [21:0] 	counterSlanje 	 = 0;		//brojac za "stalno" slanje podataka na racunar preko BT
reg [16:0] 	countSlanjeINIT = 0;		//brojač koji se koristi za odgodu između slanja poruke da je izvrsena inicijalizacija,
												//i vrijednosti udaljenosti dobijene inicijalizacijom												

/***Udaljenosti koje ocitavamo sa senzora***/
reg [	7:0] 	udaljenostL 	= 0;
reg [	7:0] 	udaljenostD 	= 0;
reg [ 7:0]  udaljenostS 	= 0;		

reg [26:0] pravo = 70500000	;           //nakon sto se detektuje da auto moze skrenuti u neku stranu, nekoliko vremena 
														//se krece ravno dok ne pocne skretati. to vrijeme je odredjeno ovim brojacem
reg [25:0] vrijemeSkretanja = 55000000;	//vrijeme potrebno da auto skrene odredjeno ovim brojacem
reg [25:0] pause				 = 50000000;	//prije nego se pocne okretati saceka 1 sekundu
reg [26:0] vrijemeOkret		 = 80000000;	//vrijeme potrebno da se okrene oko svoje ose
reg [26:0] countSlanjeSkretanja =    0;   //dok ovaj brojac ne izbroji do vrijednosti "pravo" (tj dok ne pocne skretanje)
												      //ima dozvolu za slanje udaljenosti sa srednjeg senzora  

//varijable potrebne pri inicijalnom mjerenju
reg [ 7:0]  initS	  	   =  0;		//vrijednost udaljenosti dobijena pri inicijalizaciji sa srednjeg senzora
reg 		  	initEnd		=  0;		//registar za označavanje da (ni)je završena inicijalizacija
reg [ 5:0]	brMjerenja	= 32;		//broj mjerenja koliko želimo izvršiti pri inicijalizaciji
reg [ 5:0]  Nmjerenja	= 	0;		//broj mjerenja koliko je izvršeno pri inicijalizaciji
reg [13:0]	suma			=  0;		//suma mjerenja pri inicijalizaciji

/**********FSM konfiguracija************/
reg [ 2:0] 	STATE;					//varijabla za spremanje stanja  
//stanja
parameter IDLE 				= 3'b000;	
parameter INIT 				= 3'b001;	
parameter slanjeINIT 		= 3'b010;	
parameter PRAVO 				= 3'b011;
parameter skretanjeDESNO 	= 3'b100;
parameter skretanjeLIJEVO	= 3'b101;
parameter OKRET 				= 3'b110;
parameter KRAJ 				= 3'b111; 

//specijalne poruke koje šaljemo preko BT
parameter inicijalizacija 	= 3'd1;
parameter skrenuoDesno 		= 3'd2;
parameter skrenuoLijevo 	= 3'd3;
parameter okrenuoSe 			= 3'd4; 


reg [7:0] skretanja = 0;	//registar za spremanje skretanja kada moze skrenuti na neku stranu i kada moze nastaviti pravo  
									//(bit 1 znaci da je u tom slucaju skrenuo desno, 0 - skrenuo lijevo)
reg [7:0] okretanja = 0;	//registar koji sluzi za oznacavanje da se auto, nakon sto je skrenulo u neku stranu a moglo je 
									//nastaviti pravo, zaokrenulo tj nije naslo izlaz. bit 1 - auto se zaokrenulo, bt 0 - nije se
									//zaokrenulo. Index bita odgovara indexu bita koji u registru "skretanja" oznacava da je auto 
									//skrenulo u neku stranu iako je moglo nastaviti pravo.
integer index = 0;			//index za kretanje po registru (bitima) 

initial begin
	STATE <= IDLE;
	duty   	<= {7'd0, 7'd0, 7'd0, 7'd0};
end

wire desniVeci;
wire lijeviVeci;
wire srednjiManji9;
wire srednjiVeci43;

/***assign na wire koje se koriste prilikom odlučivanja da li ce auto skrenuti, zaokrenuti se itd***/
assign desniVeci = udaljenostD > 21;
assign lijeviVeci = udaljenostL > 21;
assign srednjiVeci43 = udaljenostS > 43;
assign srednjiManji9 = udaljenostS <= 9;

/*******Ažuriranje vrijednosti udaljenosti kada senzor završi mjerenje. Ažuriranje se vrši na uzlaznu *********
************************ivicu varijable M_end koja se nalazi u modulu hcsr04**********************************/
always@(posedge endR)
begin
	udaljenostD = USR >> 11;		//šiftanje bita za 11 mjesta - ekvivalentno dijeljenju sa 2^11 = 2048
end

always@(posedge endL)
begin
	udaljenostL = USL >> 11;
end

always@(posedge endM)
begin
		if(STATE == INIT)				//Ako je STATE == INIT ne vršimo jednostavno ažuriranje vrijednosti nego moramo izvršiti
		begin								//više mjerenja u cilju inicijalizacije	
			Nmjerenja = Nmjerenja + 1;
			udaljenostS = USM >> 11;
			suma = suma + udaljenostS;
			if(Nmjerenja == brMjerenja) 
			begin
				initS = suma >> 5;	//Izvršili smo 32 mjerenja i umjesto da u cilju dobijanja srednje vrijedsnoti mjerenja 
				initEnd = 1;			//sumu podijelimo sa 32, vršimo šiftanje bita za 5 mjesta što je ekvivalentno dijeljenju 
			end							//sa 2^5 = 32 što je mnogo "jeftinija" operacija
		end
		
		else 
		begin
			suma <= 0;
			Nmjerenja <= 0;
			udaljenostS <= USM >> 11;
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
			if(initEnd) STATE <= slanjeINIT;		//nakon što dobijemo informaciju da je završena inicijalizacija prelazimo u
			else STATE 			<= INIT;				//stanje u kome šaljemo poruku da je izvršena inicijalizacija i šaljemo
		end												//poruku o inicijalnoj vrijednosti	
		
		slanjeINIT:
		begin
			duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			statesCounter <= statesCounter + 1;
			if(statesCounter == 100005) 	//cekamo da se posalju podaci (poruka da je izvrsena inicijalizacija i slanje 
			begin									//inicijalne vrijednosti) iz modula koji sluzi za slanje. Cekamo malo vise nego
				STATE <= PRAVO;				//traje slanje (100001) 
				statesCounter <= 0; 
			end
			else STATE 			<= slanjeINIT;
		end
		
		PRAVO:
		begin
			if(okretanja[index]==0) normalnoKretanje;	//ako se auto nije zaokrenulo(kada ne nadje izlaz) krece se "normalno"
																	//ovo kretanje je određeno taskom "normalnoKretanje" koji se nalazi ispod
			else	//ako se auto zaokrenulo oko svoje ose skreće gdje god može osim u slučaju	da može nastaviti i ravno. 
			begin		//Ovo kretanje traje sve dok auto ne dodje u situaciju da može skrenuti i lijevo i desno. U tom slučaju
				case({desniVeci, lijeviVeci, srednjiVeci43})	//odluku gdje će skrenuti donosi na osnovu informacije iz registra	
					3'b110:												//skretanja, gdje je spremljena informacija u kom smijeru je auto
					begin													//skrenulo kada je uslo u ovu "sporednu" putanju
						index = index - 1;					
						if(skretanja[index+1] == 1)
							STATE <= skretanjeDESNO;
						else 
							STATE <= skretanjeLIJEVO;
					end
								
					3'b100: STATE <= skretanjeDESNO;	
					
					3'b010:
					begin
						statesCounter = statesCounter + 1;
						if(statesCounter==3001000) 
						begin
							if({desniVeci, lijeviVeci, srednjiVeci43}==3'b010) 
							begin 
								STATE <= skretanjeLIJEVO; 
								statesCounter = 0; 
							end
						end
					end
					
					3'b000: 
					begin
						if(srednjiManji9) STATE <= OKRET;
					end
					
					3'b101, 3'b001: pratiLijevi;
					3'b011: pratiDesni;			
				endcase
			end
		end
				
		skretanjeLIJEVO:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= pravo)
				duty <= {7'd60, 7'd60, 7'd0, 7'd0};
			
			else if(statesCounter > pravo && statesCounter < pravo + vrijemeSkretanja)
				duty <= {7'd80, 7'd0, 7'd0, 7'd0};
			
			else if (statesCounter == pravo + vrijemeSkretanja)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			end
		end
		
		skretanjeDESNO:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= pravo)
				duty <= {7'd60, 7'd60, 7'd0, 7'd0};
			
			else if(statesCounter > pravo && statesCounter < pravo + vrijemeSkretanja)
				duty <= {7'd0, 7'd80, 7'd0, 7'd0};
			
			else if (statesCounter == pravo + vrijemeSkretanja)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			end
		end
		
		OKRET:
		begin
			statesCounter <= statesCounter + 1;
			if(statesCounter <= pause)
				duty <= {7'd0, 7'd0, 7'd0, 7'd0};
			
			else if(statesCounter > 50000000 && statesCounter < 50000000 + vrijemeOkret)
				begin duty <= {7'd0, 7'd65, 7'd75, 7'd0};
					end
			else if (statesCounter == 50000000 + vrijemeOkret)
			begin
				statesCounter <= 0;
				STATE <= IDLE;
				okretanja[index] = 1;
			end
		end
		
		KRAJ:
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
task normalnoKretanje;
	if(!lijeviVeci && !desniVeci && !srednjiManji9) pratiLijevi;	//ako se auto nalazi između dva zida prati lijevi zid		
	else if(lijeviVeci && srednjiVeci43 && udaljenostD > 11 && !desniVeci) STATE <= KRAJ; 	//u slucaju specificisnih 
																								//vrijednosti - znak da je dosao do kraja tj izasao
	else if(lijeviVeci || desniVeci)							//moze skrenuti lijevo ili desno
	begin
		if(srednjiVeci43)											//moze skrenuti lijevo(ili desno) a moze ici i ravno
		begin
			index = index + 1;
			okretanja[index] = 0;
			skretanja[index] = lijeviVeci ? 0 : 1;			//memorisemo da je na raskrsnici skrenuo lijevo(0) ili desno(1)
		end
		STATE <= lijeviVeci ? skretanjeLIJEVO : skretanjeDESNO; 	//i ako je mogao nastaviti i ako nije, skrenut ce
	end
	else if(!lijeviVeci && !desniVeci && srednjiManji9) 			//dosao do kraja zida
	begin
		STATE <= OKRET;
	end
endtask

task pratiLijevi;
	if(udaljenostL == 11)	  duty <= {7'd55, 7'd55, 7'd0, 7'd0};  //11 -> 8cm
	if(udaljenostL < 11) 	  duty <= {7'd55, 7'd65, 7'd0, 7'd0};
	else if(udaljenostL > 11) duty <= {7'd65, 7'd55, 7'd0, 7'd0};
endtask

task pratiDesni;
	if(udaljenostD == 11)	  duty <= {7'd55, 7'd55, 7'd0, 7'd0};
	if(udaljenostD < 11) 	  duty <= {7'd65, 7'd55, 7'd0, 7'd0};
	else if(udaljenostD > 11) duty <= {7'd55, 7'd65, 7'd0, 7'd0};
endtask
/*************task-ovi za kretanje - kraj ************/


/*********FSM za slanje podataka**********/
always@(posedge clk)				//always blok koji služi za slanje podataka preko BT
begin
	case(STATE)
		slanjeINIT:
		begin
			countSlanjeINIT = countSlanjeINIT + 1; 
			if(countSlanjeINIT == 1)
			begin
				TxData 	<= inicijalizacija;  //specijalna poruka koju saljemo kako bismo oznacili da je izvrsena inicijalizacija
				TxEnable <= 1;
			end
				
			else if(countSlanjeINIT == 100000)  //malo sacekamo nako slanja poruke da je izvrsena inicijalizacija
			begin
				TxData 	<= initS;					//šaljemo inicijalnu vrijednost 				
				TxEnable <= 1;
			end 
				
			else if(countSlanjeINIT == 100001)
			begin
				TxEnable 		 <= 0;
				counterSlanje	 <= 0;
				//countSlanjeINIT <= 0;  //NE resetovati ovdje
			end
				
			else TxEnable <= 0;
		end
		
		PRAVO:
		begin
			countSlanjeSkretanja <= 0;
			counterSlanje <= counterSlanje + 1;
			if(counterSlanje==3000500)	//podatke od udaljenosti šaljemo nakon svakom mjerenja (jedan ciklus mjerenja traje
			begin								//60ms (3000500 ciklusa za klok 50MHz) što je određeno u modulu hcsr04
				TxData 			 <= udaljenostS;
				TxEnable 		 <= 1;
				counterSlanje	 <= 0;
				countSlanjeINIT <= 0;			//resetujemo ga ovdje a ne ispod u slucaju kada je stanje "slanjeINIT" i kada je
			end										//counterSlanjeINIT == 100001. Kada bismo ga resetovali ispod, moglo bi se desiti 
														//da više puta pošalje istu poruku iz razloga što je uslov "STATE == slanjeINIT"
			else										//a u ovom stanju ostajemo neko vrijeme (if-ovi za prelaz na sljedece stanje i 
				TxEnable <= 0;						//ostanak u stanju slanjeINIT iznad u kodu (FSM za kretanje)). Jedan od načina 
		end											//rješenja problema, kada ne bismo ovdje vrsili reset jeste da postavimo isti 
														//tajmer u uslovima za prelaz u sljedece stanje ali je ovako sigurnije
		skretanjeLIJEVO:
		begin
			countSlanjeSkretanja = countSlanjeSkretanja + 1;
			if(countSlanjeSkretanja <= pravo) //dok ne pocne skretati i dalje salje vrijednosti o udaljenosti jer se dok ne 	 
			begin										 //izbroji do "pravo" kreće ravno
				counterSlanje <= counterSlanje + 1;
				if(counterSlanje==3000500)
				begin
					TxData 			<= udaljenostS;
					TxEnable 		<= 1;
					counterSlanje	<= 0;
				end										 									
				else				
					TxEnable <= 0;	
			end
			
			else 
			begin
				if(TxData != skrenuoLijevo)		//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
				begin										//TxData ostaje spremljena ova poruka)
					TxData 	<= skrenuoLijevo;
					TxEnable <= 1;
				end
				else TxEnable <= 0;
			end
		end
		
		skretanjeDESNO:
		begin
			countSlanjeSkretanja = countSlanjeSkretanja + 1;
			if(countSlanjeSkretanja <= pravo) 
			begin
				counterSlanje <= counterSlanje + 1;
				if(counterSlanje==3000500)
				begin
					TxData 			<= udaljenostS;
					TxEnable 		<= 1;
					counterSlanje	<= 0;				
				end										 									
				else				
					TxEnable <= 0;	
			end
			
			else
			begin
				if(TxData != skrenuoDesno)			//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
				begin										//TxData ostaje spremljena ova poruka)
					TxData 	<= skrenuoDesno;
					TxEnable <= 1; 
				end
				else TxEnable <= 0;
			end
		end
		
		OKRET:
		begin
			if(TxData != okrenuoSe)				//prevencija visestrukog slanja iste poruke (jednom kad je posalje u registru 
			begin										//TxData ostaje spremljena ova poruka)
				TxData 	<= okrenuoSe;
				TxEnable <= 1;
			end
			else TxEnable <= 0;
		end
	endcase
	
end

endmodule
