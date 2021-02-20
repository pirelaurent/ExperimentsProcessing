import processing.core.*; 
import processing.data.*; 
import processing.event.*; 
import processing.opengl.*; 

import oscP5.*; 
import netP5.*; 

import java.util.HashMap; 
import java.util.ArrayList; 
import java.io.File; 
import java.io.BufferedReader; 
import java.io.PrintWriter; 
import java.io.InputStream; 
import java.io.OutputStream; 
import java.io.IOException; 

public class ExperimentsProcessing extends PApplet {

int red,blue, green;

//Necessary for OSC communication with openbci_gui:


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
int[] colorBand = new int[EXPECTED_BANDS];


// traffic
int receivedMessage = 0;
// draw bars 
int nextBarPercentage = 0;


public void setup() {
    //Initialize OSC communication
    println("listen to port "+portBCI);
    oscP5 = new OscP5(this,portBCI); //listen for OSC messages on port 12345 (openBCI default)
    //dest = new NetAddress("127.0.0.1",6448); //send messages back via localhost if necessary
    
    frameRate(20); // can climb up to 120 in standalone 
    
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
    
    public void draw() {
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
    
    
    
    public void drawOnRadius(int angle,float value, int couleur) {
       float limit = 250;
       // log seems to go from 10^-1 to 10^3 
       float factor = limit/3.2f;
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

    public @Override void exit() {
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
    
/*
mix [channel][band]  in [band] applying a spatial filter
ex: spatialFilter= new float[] {0,1,0,0,0,0,0,0}; will retain only channel 2
*/
   public float[]  applySpatialFilter(float[][] chanBand,float[] filter) {
     // nb colonnes pris sur la 1ère ligne
     int nbBand = chanBand[0].length;
     int nbChan = chanBand.length;
     // controle 
     if (filter.length != nbChan) {
        println("*** applyFilter : wrong size to multiply matrix of " + nbChan + " and vector of " + filter.length + "**");
        // leave it to crash for the day 
     }
     
     float[] result = new float[nbBand];
     // nb de lignes de la matrice  égale au nombre de colonnes du filtre 
     for (int band = 0; band < nbBand;band++) {
        result[band] = 0;
        for (int chan = 0;chan < nbChan;chan++) {
            result[band] += filter[chan] * chanBand[chan][band];
        }  
    } // band
    return result;
 }

 /*
  transform a set of BandPower values in relative % of each on the whole
 */
  public float[] vector2Percentage(float[] vector) {
       float sum = 0;
       for (int i = 0; i < vector.length;i++) {
           sum = sum + vector[i];
       }   
       float[] result = new float[vector.length];

       for (int i = 0; i < vector.length; i++) {
           result[i] = vector[i] / sum * 100;
       }
       return result;
  }
  /*
   calculate the col mean of a series of rows  
   tamponPV = new float[WINDOW_OF_BANDS][EXPECTED_BANDS];
  */

  public float[] windowAverage(float[][] bufferedData) {
      int nbCols = bufferedData[0].length;
      int nbRows = bufferedData.length;
      float[] result = new float[nbCols];
      for (int row = 0; row < nbRows;row++) {
          for (int col = 0;col < nbCols;col++) {
            result[col] += bufferedData[row][col];
          }
      }
    // now the mean 
    for (int col = 0;col < nbCols;col++) {
        result[col] = result[col] / nbRows; 
    }
    return result;
  }

  /*
   print a vector 
  */
  public void printVector(float[] v){
      for (int i=0;i<v.length;i++){
          print(v[i]+"\t");
      }
    println();
  }
/*
       This is called automatically when OSC message is received
    
   */
   public void oscEvent(OscMessage theOscMessage) {
       
       //print("### received an osc message.");
       //print(" addrpattern: " + theOscMessage.addrPattern());
       //println(" typetag:" + theOscMessage.typetag());
    
       //------------------- reception of a line of power. 1 message per channel
       if (theOscMessage.checkAddrPattern(patternBCI) == true) {
           if (theOscMessage.checkTypetag(tagBCI)) {  // don't test with  ==
               int channel = theOscMessage.get(0).intValue();
            
                   if (storeRawPowerOSC) {
                       outputOSC.print(channel + " ");
                   }
                   for (int band = 0;band < EXPECTED_BANDS;band++) {
                       // band begins after channel so get +1
                       float aValue =  theOscMessage.get(band + 1).floatValue();
                       if (storeRawPowerOSC) {
                           outputOSC.print(aValue + " ");
                       }
                      // normalize in log10 . set minima at 0.1 
                       if (aValue<0.1f) aValue=0.1f;
                //     -> log10(0.1)= -1 . Move to a 0 as root 
                       float rectifiedValue = log10(aValue) +1;
                        // chan 1 is at index 0 in the array 
                       currentPowerVector[channel - 1][band] = rectifiedValue;
                       if (rectifiedValue > maxLogSeen) {
                           maxLogSeen = rectifiedValue;
                    //println("maxLogSeen :"+maxLogSeen+" on chan "+ band +" for "+aValue);
                           } 
                   }
                   if (storeRawPowerOSC) {
                       outputOSC.println();
                   }
            // calculate spatialfiltered value once last channel received 
            if (channel == EXPECTED_CHANNELS) {
                
                filteredPowerVector = applySpatialFilter(currentPowerVector,spatialFilter);
                //print("filteredPV: ");
                //printVector(filteredPowerVector);
                
                tamponPV[nbInTamponPV] = filteredPowerVector;
                nbInTamponPV +=1;
                // once all channels received, can apply filter 
                
                if (nbInTamponPV == WINDOW_OF_BANDS) {
                    //println("row "+nbInTamponPV+" on "+WINDOW_OF_BANDS);
                    averagePV = windowAverage(tamponPV);
                    //print ("averagePV:");
                    //printVector(averagePV);
                    lastCalculatedPV +=1;
                    // calculate mean, max, etc. 
                    // restart from beginning of window
                    nbInTamponPV = 0;
                }
            }       
        }
       } else {
           println("Error: unexpected params type tag received by Processing");
       }
   }
//------------------------------------ logarithm useful
   float LOG10 = log(10);
   public float log10(float x) {
       return(log(x) / LOG10);
}
  public void settings() {  size(600, 800, P2D); }
  static public void main(String[] passedArgs) {
    String[] appletArgs = new String[] { "--present", "--window-color=#666666", "--stop-color=#cccccc", "ExperimentsProcessing" };
    if (passedArgs != null) {
      PApplet.main(concat(appletArgs, passedArgs));
    } else {
      PApplet.main(appletArgs);
    }
  }
}
