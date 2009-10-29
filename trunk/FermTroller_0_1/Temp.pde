#include <OneWire.h>
//One Wire Bus on 
OneWire ds(5);

void getDSAddr(byte addrRet[8]){
  byte scanAddr[8];
  ds.reset_search();
  byte limit = 0;
  //Scan at most 10 sensors (In case the One Wire Search loop issue occurs)
  while (limit <= 10) {
    if (!ds.search(scanAddr)) {
      //No Sensor found, Return
      ds.reset_search();
      return;
    }
    boolean found = 0;
    for (byte i = 0; i < NUM_ZONES + 1; i++) {
      if (scanAddr[0] == tSensor[i][0] &&
          scanAddr[1] == tSensor[i][1] &&
          scanAddr[2] == tSensor[i][2] &&
          scanAddr[3] == tSensor[i][3] &&
          scanAddr[4] == tSensor[i][4] &&
          scanAddr[5] == tSensor[i][5] &&
          scanAddr[6] == tSensor[i][6] &&
          scanAddr[7] == tSensor[i][7])
      { 
          found = 1;
          break;
      }
    }
    if (!found) {
      for (byte i = 0; i < 8; i++) addrRet[i] = scanAddr[i];
      return;
    }
    limit++;
  }
}

void convertAll() {
  ds.reset();
  ds.skip();
  ds.write(0x44,1);         // start conversion, with parasite power on at the end
}

float read_temp(byte* addr) {
  float temp;
  int rawtemp;
  byte data[12];
  ds.reset();
  ds.select(addr);   
  ds.write(0xBE);         // Read Scratchpad
  for (byte i = 0; i < 9; i++) data[i] = ds.read();
  if ( OneWire::crc8( data, 8) != data[8]) return -1;
  
  rawtemp = (data[1] << 8) + data[0];
  if ( addr[0] != 0x28) temp = (float)rawtemp * 0.5; else temp = (float)rawtemp * 0.0625;
  #ifdef USEMETRIC
    return temp;  
  #else
    return (temp * 1.8) + 32.0;
  #endif
}
