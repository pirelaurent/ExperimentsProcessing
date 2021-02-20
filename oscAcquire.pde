/*
       This is called automatically when OSC message is received
    
   */
   void oscEvent(OscMessage theOscMessage) {
       
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
                       if (aValue<0.1) aValue=0.1;
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
   float log10(float x) {
       return(log(x) / LOG10);
}