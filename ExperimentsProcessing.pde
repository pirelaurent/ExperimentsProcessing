int red,blue, green;

//Necessary for OSC communication with openbci_gui:
import oscP5.*;
import netP5.*;
OscP5 oscP5;
NetAddress dest;
// parameters for open BCI 
int portBCI = 12345; // pti msi à lyon 192.168.0.29 à mettre sur distant OpenBCI
String patternBCI = "/openbci";
String tagBCI = "ifffff";
//--------------------------------- store received data in a file 
//ex: 11'43 s ->140760 lignes pour 8 canaux soit 17595 par canal 
// pour 703 secondes soit 25/s pour chaque bande 
// ex :  17984 pour 1'29 soit 2248 / canal pour 89s : 25 par secondes 

boolean storeRawPowerOSC = false;
String fileNameOSC = "results/BandPowerOSC";
PrintWriter outputOSC; 

//---------------------------------
/* 
band power
1 message par canal  
canal 1-18 indépendamment de la config. (17-18 spéciaux)
5 floats representing Delta, Theta, Alpha, Beta, Gamma band power for each channel in this exact order
below : position in array;
*/
static int EXPECTED_BANDS = 5;
static int DELTA = 0;
static int THETA = 1;
static int ALPHA = 2;
static int BETA = 3;
static int GAMMA = 4;


IntList bandPower = new IntList(DELTA,THETA,ALPHA,BETA,GAMMA);

static int EXPECTED_CHANNELS = 8;




int freqHz = 25; // openBCI on band power
// calculate a mean for 
int WINDOW_OF_BANDS = 5;

//float[] lastValues = new float[EXPECTED_BANDS];

// matrix for a full channels receipt 
float [][] currentPowerVector = new float[EXPECTED_CHANNELS][EXPECTED_BANDS];
// choose a channel or a calculation on several with coefficient
float[] spatialFilter= new float[] {0,1,0,0,0,0,0,0};
// calculated powerBand mixing chanels 
float [] filteredPowerVector = new float[EXPECTED_BANDS];
// to check max once value is rectified by log 
float maxLogSeen = 0;
// set a window to sum and average filtered power bands (ie no more channels)
float[][] tamponPV = new float[WINDOW_OF_BANDS][EXPECTED_BANDS];
int nbInTamponPV = 0;
// follow new data to display
float [] averagePV = new float[EXPECTED_BANDS];
int lastCalculatedPV = 0;
int lastDisplayedPV = 0;

// design 
color[] colorBand = new color[EXPECTED_BANDS];


// traffic
int receivedMessage = 0;
// draw bars 
int nextBarPercentage = 0;


void setup() {
    //Initialize OSC communication
    println("listen to port "+portBCI);
    oscP5 = new OscP5(this,portBCI); //listen for OSC messages on port 12345 (openBCI default)
    //dest = new NetAddress("127.0.0.1",6448); //send messages back via localhost if necessary
    
    frameRate(20); // can climb up to 120 in standalone 
    size(600, 800, P2D);
    red = 0; blue = 100; green = 250;
    stroke(red,blue,green);
    background(0);
    
    colorBand[0] = color(15, 157, 232);
    colorBand[1] = color(150, 131, 236);
    colorBand[2] = color(131, 166, 151);
    colorBand[3] = color(252, 220, 18);
    colorBand[4] = color(255, 111, 125); 
    
    //---------------- prepare file if storeRawPowerOSC raw data 
    if (storeRawPowerOSC) {
        fileNameOSC=fileNameOSC+year()+"_"+month()+"_"+day()+"_"+hour()+"_"+minute()+".raw.txt";
        outputOSC = createWriter(fileNameOSC); 
        println("store raw power data in " + fileNameOSC);
    };
    //--------------------------------------------
}
    
    float around = 0;
    
    void draw() {
        // don't add a data at each frame to avoid same  
        if (lastCalculatedPV == lastDisplayedPV) return;
        lastDisplayedPV = lastCalculatedPV;
        strokeWeight(2); 
        
        // in processing 3D origin is upper left . in P5 it's centered  
        // to center Y :
        push(); 
        translate(width / 2, 250);
        
        //drawOnRadius(angle,factor,limit,channel,band){
        
        float whereAngle =  lastCalculatedPV % 36 * 10;    
        for (int b = 0;b < EXPECTED_BANDS;b++) {
            int angle = ceil(whereAngle + b * 2);
            drawOnRadius(angle,averagePV[b],colorBand[b]);
        }
        pop();

        // transform in relative pct 
        float[] percentage = vector2Percentage(averagePV);
/* print("average: ");        
printVector(averagePV);
print("percentage: ");
printVector(percentage); */

        // draw result 
        push(); 

        translate(nextBarPercentage,620);
        int wide = 4;
        nextBarPercentage+=wide;
        if (nextBarPercentage>=width)nextBarPercentage=0;
          // create rectangles 
            int lowY = 0;
        for (int band = 0; band < EXPECTED_BANDS; band++) {
            fill(colorBand[band]);
            stroke(colorBand[band]);
            // to have a clean limit 
            if( band == EXPECTED_BANDS-1) rect(0,lowY,wide,100-lowY);
             else  rect(0,lowY,wide,percentage[band]);
            lowY= lowY+round(percentage[band]);
        }


        // clean next place 
        fill(0);
        stroke(0);
        rect(wide,0,2*wide, 100);
        pop();  
    }
    
    
    
    void drawOnRadius(int angle,float value, color couleur) {
       float limit = 250;
       // log seems to go from 10^-1 to 10^3 
       float factor = limit/3.2;
        float s = sin(radians(angle));
        float c = cos(radians(angle));
        float y =  value * factor;

        if (y > limit) { 
            // println("out of draw in " + band + " :" + y + " from"+averagePV[band]);
            y = limit;
        }
        stroke(0,0,0);
        strokeWeight(4);
        line(0,0,0,s * limit,c * limit,0);
        stroke(couleur);
        strokeWeight(2);
        int decalCenter = 15;
        // 
        line(s* decalCenter,c * decalCenter,s * (y+decalCenter), c * (y+decalCenter));
    }  



    /*
    to catch exit from programm processing . 
    Hereto avoid to lock port  
    */

    @ Override void exit() {
        //Call finalizing stuff below:
        println("stopping oscP5");
        oscP5.stop();
        if( storeRawPowerOSC )
        {   
            println("closing output file");
            outputOSC.flush(); // Writes the remaining data to the file
            outputOSC.close(); // Finishes the file
         }    //...
println("maxLog10Seen: "+maxLogSeen);      
        super.exit(); // Now call original exit()
    }
    