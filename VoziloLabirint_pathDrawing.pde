
import processing.serial.*;

int xt, yt, xs, ys, xu, yu;  // t - transformisano, s - stare koordinate odakle krece
                             //crtanje linije, u - ulazni podatak koji je poslan preko
                             //bluetooth-a
int xp, yp;                  //Koordinate tačke odakle se počinje crtanje svaki put kada se izvrši initialization
Serial BtPort;               //The serial port(bluetooth port)
int shift;                   //shift po osi koji napravimo kada se udaljenost promijeni za 1cm
int sum = 0;                //za pronalazak srednje vrijednosti
int nMeasures=0;             //broj mjerenja koliko smo izvršili pri pronalasku srednje vrijednosti
int step;                   //varijabla koja moze poprimiti vrijednosti -shift i +shift cime je olaksana realizacija promjena koje je potrebno izvrsiti kada auto skrene, okrene se itd
int color[] = {255,0,0};      
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
  shift = (2*height)/(3 * 180); //maksimalna vrijednost udaljenosti 180cm a imamo na raspolaganju 2/3 visine(ili duzine jer su iste dimenzije) prozora
  step = shift;
  xu=0;
  yu=0;
  xp=0;
  yp=0;
  background(255);
}

int message=0;                   //varijabla za smjestanje primljene poruke
//varijable za oznacavanje da su poslane neke od specijalnih message
boolean initialization=false;    
boolean turnedRight = false;
boolean turnedLeft = false;
boolean turned = false;
//

String fixedAxis = "x";          //fixedAxis osa(osa čija koordinata je fiksne vrijednosti za vrijeme kretanja) po kojoj se vrsi crtanje(na pocetku je to x)
int initValue=0;              //varijabla za smjestanje inicijalne vrijednosti na osnovu cije vrijednosti se vrsi proracun sljedecih koordinata
int previousValue = initValue;   //varijabla za smjestanje prethodne vrijednosti mjerenja koju koristimo za provjeru kako ne bi doslo do velikog odstupanja uzastopnih mjerenja 
int numberOfMeasures = 4;           //broj mjerenja koliko želimo izvršiti pri pronalasku srednje vrijednosti
int allowedDeviation = 5;          //dozvoljeno odstupanje vrijednosti dva uzastopna mjerenja

void draw()
{
  CoordinateTransformation(xu, yu);  //transformacija koordinata iz koordinata Kartezijevog koordinatnog sistema koje mi proracunavamo u funkciji "coordinatesCalculation" 
  strokeWeight(7);                   //postavljanje debljine linije
  stroke(color[0],color[1],color[2]);   //postavljanje boje linije
  line(xs, ys, xt, yt);              //crtanje linije
  xs=xt;
  ys=yt;
}

//funkcija za proracun koordinata koje processing "razumije" pri čemu su argumenti funkcije koordinate Kartezijevog koordinatnog sistema 
void CoordinateTransformation(int x, int y)
{
  xt = width/6 + x;
  yt = height-height/6 - y;
}

//proracun koordinata na osnovu udaljenosti koju primimo kao podatak preko BT
void coordinatesCalculation(int udaljenost)
{
  if(fixedAxis == "x") 
    yu=yp+step*(initValue-udaljenost);
  else              
    xu=xp+step*(initValue-udaljenost);
}

//interrupt rutina koja se izvrsava kada se desi slanje podataka
void serialEvent(Serial BtPort)
{
  message = BtPort.read();  //citanje poslanih podataka
  if(message <= 240)        //prevencija primanja podataka koji nisu u opsegu koji ocekujemo
  {
    if(initialization) 
    {                                            
      if(turnedRight)
      {
        if(fixedAxis=="x") 
        {
          fixedAxis = "y";
          step = step > 0 ? shift : -shift;    //kretanje u + ili - nakon skretanja zavisi od toga u kom smijeru (u + ili -) se auto prethodno kretalo po fiksnoj x osi 
        }
        
        else if(fixedAxis=="y") 
        {
          fixedAxis = "x";
          step = step > 0 ? -shift : shift;
        }
      }
      
      else if(turnedLeft)
      {
        if(fixedAxis=="x") 
        {
          fixedAxis = "y";
          step = step > 0 ? -shift : shift;
        }
        
        else if(fixedAxis=="y") 
        {
          fixedAxis = "x";
          step = step > 0 ? shift : -shift;
        }
      }
      
      else if(turned) 
      {
        step = step > 0 ? -shift : shift;    //nema promjene fiksne ose. samo se desava inverzija pomaka   
        for(int j=0; j<3; j++) 
          color[j] = 0;
        color[i]=255;                           //svaki put kada se auto okrene promijeni se color za crtanje kako bi se vidjele obje putanje(i kada tek dolazi i kad se vraća)
        if(++i == 3) i=0;
      }
       
      //nakon inicijalizacije (sto znaci da je auto skrenulo ili se okrenulo oko svoje ose) vrsi se proracun pocetne tačke odakle se dalje kreće
      xp=xs-width/6;
      yp=(height-height/6)-ys;
      
      initValue = (message*2048)/2900;      //proracun vrijednosti udaljenosti u cm (nije neophodno)
      previousValue = initValue;
      nMeasures = 0;
      sum = 0;
      initialization = false; 
      turnedRight = false;
      turnedLeft = false;
      turned = false;
    }
  
    else
    {
      if (message==1) 
        initialization = true;
      else if (message==2) 
        turnedRight = true;
      else if (message==3) 
        turnedLeft = true;
      else if (message==4) 
        turned = true;
      else if (abs(previousValue - message*2048/2900) <= allowedDeviation && (previousValue - message*2048/2900) >= 0) 
      {
        nMeasures+=1;
        sum = sum + (message*2048)/2900;
        if(nMeasures == numberOfMeasures) 
        {
          message = sum / numberOfMeasures;
          coordinatesCalculation(message);
          previousValue = message;
          sum=0;
          nMeasures = 0;
        }
      }
    }
  }
}
