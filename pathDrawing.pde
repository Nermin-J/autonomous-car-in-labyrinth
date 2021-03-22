
import processing.serial.*;

int xt, yt, xs, ys, xu, yu;  // t - transformisano, s - stare koordinate odakle krece
                             //crtanje linije, u - ulazni podatak koji je poslan preko
                             //bluetooth-a
int xp, yp;                  //Koordinate tačke odakle se počinje crtanje svaki put kada se izvrši inicijalizacija
Serial BtPort;               //The serial port(bluetooth port)
int pomak;                   //pomak po osi koji napravimo kada se udaljenost promijeni za 1cm
int suma = 0;                //za pronalazak srednje vrijednosti
int nMjerenja=0;             //broj mjerenja koliko smo izvršili pri pronalasku srednje vrijednosti
int korak;                   //varijabla koja moze poprimiti vrijednosti -pomak i +pomak cime je olaksana realizacija promjena koje je potrebno izvrsiti kada auto skrene, okrene se itd
int boja[] = {255,0,0};      
int i=1;              

void setup()      
{
  size(730, 730);
  printArray(Serial.list());
  // Open the port you are using at the rate you want:
  BtPort = new Serial(this, "COM11", 9600);    //port koji je dodijeljen BT-u na racunaru za razmjenu podataka
  
  //postavljanje inicijalnih vrijednosti
  xt=0;
  yt=0;
  //pocetne(stare tacke na pocetku) proracunate na osnovu velicine prozora u kome se vrsi crtanje
  xs=width/6;              
  ys=height-height/6;
  //
  pomak = (2*height)/(3 * 180); //maksimalna vrijednost udaljenosti 180cm a imamo na raspolaganju 2/3 visine(ili duzine jer su iste dimenzije) prozora
  korak = pomak;
  xu=0;
  yu=0;
  xp=0;
  yp=0;
  background(255);
}

int poruka=0;                   //varijabla za smjestanje primljene poruke
//varijable za oznacavanje da su poslane neke od specijalnih poruka
boolean inicijalizacija=false;    
boolean skrenuoDesno = false;
boolean skrenuoLijevo = false;
boolean okrenuoSe = false;
//

String fiksna = "x";          //fiksna osa(osa čija koordinata je fiksne vrijednosti za vrijeme kretanja) po kojoj se vrsi crtanje(na pocetku je to x)
int initValue=0;              //varijabla za smjestanje inicijalne vrijednosti na osnovu cije vrijednosti se vrsi proracun sljedecih koordinata
int prMjerenje = initValue;   //varijabla za smjestanje prethodne vrijednosti mjerenja koju koristimo za provjeru kako ne bi doslo do velikog odstupanja uzastopnih mjerenja 
int brMjerenja = 4;           //broj mjerenja koliko želimo izvršiti pri pronalasku srednje vrijednosti
int odstupanjeD = 5;          //dozvoljeno odstupanje vrijednosti dva uzastopna mjerenja

void draw()
{
  transformacijaKoordinata(xu, yu);  //transformacija koordinata iz koordinata Kartezijevog koordinatnog sistema koje mi proracunavamo u funkciji "proracunKoordinata" 
  strokeWeight(7);                   //postavljanje debljine linije
  stroke(boja[0],boja[1],boja[2]);   //postavljanje boje linije
  line(xs, ys, xt, yt);              //crtanje linije
  xs=xt;
  ys=yt;
}

//funkcija za proracun koordinata koje processing "razumije" pri čemu su argumenti funkcije koordinate Kartezijevog koordinatnog sistema 
void transformacijaKoordinata(int x, int y)
{
  xt = width/6 + x;
  yt = height-height/6 - y;
}

//proracun koordinata na osnovu udaljenosti koju primimo kao podatak preko BT
void proracunKoordinata(int udaljenost)
{
  if(fiksna == "x") yu=yp+korak*(initValue-udaljenost);
  else              xu=xp+korak*(initValue-udaljenost);
}

//interrupt rutina koja se izvrsava kada se desi slanje podataka
void serialEvent(Serial BtPort)
{
  poruka = BtPort.read();  //citanje poslanih podataka
  if(poruka <= 240)        //prevencija primanja podataka koji nisu u opsegu koji ocekujemo
  {
    if(inicijalizacija) 
    {                                            
      if(skrenuoDesno)
      {
        if(fiksna=="x") 
        {
          fiksna = "y";
          korak = korak > 0 ? pomak : -pomak;    //kretanje u + ili - nakon skretanja zavisi od toga u kom smijeru (u + ili -) se auto prethodno kretalo po fiksnoj x osi 
        }
        
        else if(fiksna=="y") 
        {
          fiksna = "x";
          korak = korak > 0 ? -pomak : pomak;
        }
      }
      
      else if(skrenuoLijevo)
      {
        if(fiksna=="x") 
        {
          fiksna = "y";
          korak = korak > 0 ? -pomak : pomak;
        }
        
        else if(fiksna=="y") 
        {
          fiksna = "x";
          korak = korak > 0 ? pomak : -pomak;
        }
      }
      
      else if(okrenuoSe) 
      {
        korak = korak > 0 ? -pomak : pomak;    //nema promjene fiksne ose. samo se desava inverzija pomaka   
        for(int j=0; j<3; j++) boja[j] = 0;
        boja[i]=255;                           //svaki put kada se auto okrene promijeni se boja za crtanje kako bi se vidjele obje putanje(i kada tek dolazi i kad se vraća)
        if(++i == 3) i=0;
      }
       
      //nakon inicijalizacije (sto znaci da je auto skrenulo ili se okrenulo oko svoje ose) vrsi se proracun pocetne tačke odakle se dalje kreće
      xp=xs-width/6;
      yp=(height-height/6)-ys;
      
      initValue = (poruka*2048)/2900;      //proracun vrijednosti udaljenosti u cm (nije neophodno)
      prMjerenje = initValue;
      nMjerenja = 0;
      suma = 0;
      inicijalizacija = false; 
      skrenuoDesno = false;
      skrenuoLijevo = false;
      okrenuoSe = false;
    }
  
    else
    {
           if (poruka==1) inicijalizacija = true;
      else if (poruka==2) skrenuoDesno = true;
      else if (poruka==3) skrenuoLijevo = true;
      else if (poruka==4) okrenuoSe = true;
      else if (abs(prMjerenje - poruka*2048/2900) <= odstupanjeD && (prMjerenje - poruka*2048/2900) >= 0) 
      {
        nMjerenja+=1;
        suma = suma + (poruka*2048)/2900;
        if(nMjerenja == brMjerenja) 
        {
          poruka = suma / brMjerenja;
          proracunKoordinata(poruka);
          prMjerenje = poruka;
          suma=0;
          nMjerenja = 0;
        }
      }
    }
  }
}
