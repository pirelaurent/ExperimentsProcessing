/*
mix [channel][band]  in [band] applying a spatial filter
ex: spatialFilter= new float[] {0,1,0,0,0,0,0,0}; will retain only channel 2
*/
   float[]  applySpatialFilter(float[][] chanBand,float[] filter) {
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
  float[] vector2Percentage(float[] vector) {
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

  float[] windowAverage(float[][] bufferedData) {
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
  void printVector(float[] v){
      for (int i=0;i<v.length;i++){
          print(v[i]+"\t");
      }
    println();
  }