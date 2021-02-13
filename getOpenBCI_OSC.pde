int red,blue, green;

//Necessary for OSC communication with openbci_gui:
import oscP5.*;
import netP5.*;
OscP5 oscP5;
NetAddress dest;
// parameters for open BCI 
int portBCI = 12346;
// pti msi à lyon 192.168.0.29 à mettre sur distant OpenBCI
String patternBCI = "/openbci";
String tagBCI = "ifffff";
/* 
band power
1 message par canal  
canal 1-18 indépendamment de la config. (17-18 spéciaux)
5 floats representing Delta, Theta, Alpha, Beta, Gamma band power for each channel in this exact order
below : position in array;
*/
static int DELTA = 0;
static int THETA = 1;
static int ALPHA = 2;
static int BETA = 3;
static int GAMMA = 4;
static int NB_BAND = 5;
IntList bandPower = new IntList(DELTA,THETA,ALPHA,BETA,GAMMA);
int freqHz = 250; // openBCI data aquisition 
int packetSize = 25;
int nbChannelMax = 18;
IntList channelsFollowed = new IntList(1,2,3,4,5,6,7,8);
float[] lastValues = new float[5];
// place only for retained channels
float[][] aPowerVectorAvg = new float[nbChannelMax][bandPower.size()];
float[][] aPowerVectorAvgMax = new float[nbChannelMax][bandPower.size()];

float[][] aPowerVectorCumul = new float[nbChannelMax][bandPower.size()];
float[][] aPowerVectorMax = new float[nbChannelMax][bandPower.size()];
// %
float[] percentages = new float[NB_BAND];
color[] colorBand = new color[NB_BAND];


// traffic
int receivedMessage = 0;
int receivedInPacket = 0;
int nbReceivedPacket = 0;



void setup() {
    //Initialize OSC communication
    oscP5 = new OscP5(this,portBCI); //listen for OSC messages on port 12345 (openBCI default)
    //dest = new NetAddress("127.0.0.1",6448); //send messages back via localhost if necessary
    
    frameRate(20); // can climb up to 120 in standalone 
    size(600, 600, P3D);
    red = 0; blue = 100; green = 250;
    stroke(red,blue,green);
    background(0);
    println(width);
    
    colorBand[0] = color(15, 157, 232);
    colorBand[1] = color(150, 131, 236);
    colorBand[2] = color(131, 166, 151);
    colorBand[3] = color(252, 220, 18);
    colorBand[4] = color(255, 111, 125); 
}

int x = 0;

int lastReceivedPacket =- 1;
float around = 0;

void draw() {
 
    if (nbReceivedPacket == lastReceivedPacket) return;
    lastReceivedPacket = nbReceivedPacket;
    strokeWeight(2); 
    
    // in processing 3D origin is upper left . in P5 it's centered  
    // to center Y :
    push(); 
    translate(width / 2, 200);

    int aChannelOnly = 2;

    //drawOnRadius(angle,factor,limit,channel,band){
        
    float whereAngle =  nbReceivedPacket %36 *10;    
    for (int b = 0;b < NB_BAND;b++) {
        int angle = ceil(whereAngle + b *2);
        push();

        pop();
        drawOnRadius(angle,aChannelOnly,b);
    }
    pop();

    // ----------------------
    // calculate % of each band on total 
    float sum = 0;
    for (int i = 0; i < NB_BAND;i++) {
        sum = sum + aPowerVectorAvg[aChannelOnly][i];
    }    
    for (int i = 0;i < NB_BAND;i++) {
        percentages[i] = aPowerVectorAvg[aChannelOnly][i] / sum * 100;
        //println("pct"+i+" "+percentages[i]);
    }
    // draw result 
    push(); 
    translate(0,500);
    stroke(0);
    
    float ui = width / 100;
    fill(0);
    rect(0,0,width,-100);
    float pos = 0;
    for (int i = 0;i < NB_BAND;i++) {
        fill(colorBand[i]);
        stroke(colorBand[i]);
        rect(pos,0,percentages[i] * ui,- percentages[i]);
        pos += percentages[i] * ui;
    }
    pop();  
}



void drawOnRadius(int angle,int channel,int band) {
 int limit = 200;
 int factor = 150;
  float s = sin(radians(angle));
  float c = cos(radians(angle));
  float y =  aPowerVectorAvg[channel][band] * factor;
    if (y > limit) { 
        println("out in "+band+" :"+ y);
        y = limit;
    }
  stroke(0,0,0);
  line(0,0,0,s * limit,c * limit,0);
  stroke(colorBand[band]);
  line(s * 15,c * 15,0,s * y,c * y,0);
}


//This is called automatically when OSC message is received
void oscEvent(OscMessage theOscMessage) {
    
    //print("### received an osc message.");
    //print(" addrpattern: " + theOscMessage.addrPattern());
    //println(" typetag:" + theOscMessage.typetag());
    // create an average on 1 s 
    if (receivedInPacket == packetSize) {
        for (int channel = 1;channel <= nbChannelMax; channel++) {
            //traceMessage("max   ",channel, aPowerVectorMax);
            //traceMessage("cumul ",channel, aPowerVectorCumul);
            for (int band = 0;band < 5;band++) {
                aPowerVectorAvg[channel - 1][band] = aPowerVectorCumul[channel - 1][band] / packetSize;
                if (aPowerVectorAvg[channel - 1][band] > aPowerVectorAvgMax[channel - 1][band]) 
                { aPowerVectorAvgMax[channel - 1][band] = aPowerVectorAvg[channel - 1][band];}
                aPowerVectorCumul[channel - 1][band] = 0.0;
          }
            // traceMessage("avg Max"+receivedInPacket+" ",channel, aPowerVectorAvgMax);
      } 
        
        receivedInPacket = 0;
        nbReceivedPacket +=1;
        
    }
    
    
    
    if (theOscMessage.checkAddrPattern(patternBCI) == true) {
        if (theOscMessage.checkTypetag(tagBCI)) {  // don't test with  ==
            // trace first messages only to verify 
            receivedMessage +=1;
            receivedInPacket +=1;
            
            
            int channel = theOscMessage.get(0).intValue();  // 1-18
            if (receivedMessage <= 20) traceMessage("raw ",channel, aPowerVectorCumul);
            // channels: filter list  
            if (channelsFollowed.hasValue(channel)) {
                
                for (int band = 0;band < 5;band++) {
                    float aValue =  theOscMessage.get(band + 1).floatValue();
                    aPowerVectorCumul[channel - 1][band] += aValue;
                    if (aValue > aPowerVectorMax[channel - 1][band]) aPowerVectorMax[channel - 1][band] = aValue;
              }
          } 
      }
    }else {
        println("Error: unexpected params type tag received by Processing");
    }
}

void traceMessage(String context, int channel, float[][] aVector) {
    if (channel!= 1) return;
    print(receivedMessage + " " + context + " channel " + channel + "\t"); 
    for (int band = 0;band < 5;band++) {
        print(aVector[channel - 1][band]);
        print("\t");
    }
    println();
}

/*
to catch exit from programm processing . 
Here to avoid to lock port  
*/
@ Override void exit() {
    //Call finalizing stuff below:
    println("stopping oscP5");
    oscP5.stop();
    //...
    super.exit(); // Now call original exit()
}
