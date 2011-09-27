/*  
   Copyright (C) 2009, 2010 Matt Reba, Jeremiah Dillingham

    This file is part of BrewTroller.

    BrewTroller is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    BrewTroller is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with BrewTroller.  If not, see <http://www.gnu.org/licenses/>.


BrewTroller - Open Source Brewing Computer
Software Lead: Matt Reba (matt_AT_brewtroller_DOT_com)
Hardware Lead: Jeremiah Dillingham (jeremiah_AT_brewtroller_DOT_com)

Documentation, Forums and more information available at http://www.brewtroller.com
*/
#include "wiring_private.h"

#include "Config.h"
#include "Enum.h"
#include "HWProfile.h"
#include "PVOut.h"

#ifdef PID_FLOW_CONTROL 
  #define LAST_HEAT_OUTPUT VS_PUMP // not this is mostly done for code readability as VS_PUMP = VS_STEAM
#else
  #ifdef USESTEAM
    #define LAST_HEAT_OUTPUT VS_STEAM
  #elif DIRECT_FIRED_RIMS
    #define LAST_HEAT_OUTPUT VS_STEAM
  #else
    #define LAST_HEAT_OUTPUT VS_KETTLE
  #endif
#endif


// set what the PID cycle time should be based on how fast the temp sensors will respond
#if TS_ONEWIRE_RES == 12
  #define PID_CYCLE_TIME 750
#elif TS_ONEWIRE_RES == 11
  #define PID_CYCLE_TIME 375
#elif TS_ONEWIRE_RES == 10
  #define PID_CYCLE_TIME 188
#elif TS_ONEWIRE_RES == 9
  #define PID_CYCLE_TIME 94
#else
  // should not be this value, fail the compile
  #ERROR
#endif

#ifdef PWM_BY_TIMER
// note there are some assumptions here, we assume that the COM1A1, COM1B1, COM1A0, and COM1B0 
// bits are all 0 (as they should be on power up)
void pwmInit( void )
{
    // set timer 1 prescale factor to 0
    sbi(TCCR1B, CS10);
    cbi(TCCR1B, CS12);
    cbi(TCCR1B, CS11);

    //clear timer 1 out of 8 bit phase correct PWM mode from sanguino init
    cbi(TCCR1A, WGM10);
    //set timer 1 into 16 bit phase and frequency correct PWM mode with ICR1 as TOP
    sbi(TCCR1B, WGM13);
    //set TOP as 1000, which makes the overflow on return to bottom for this mode happen ever 
    // 125uS given a 16mhz input clock, aka 8khz PWM frequency, the overflow ISR will handle 
    // the PWM outputs that are slower than 8khz, and the OCR1A/B ISR will handle the 8khz PWM outputs
    ICR1 = 1000; 

    //enable timer 1 overflow interrupt (in this mode overflow happens when the timer counds down to BOTTOM
    // after counting UP from BOTTOM to TOP. 
    sbi(TIMSK1, TOIE1);

}

//note that the code in any SIGNAL function is an ISR, and the code needs to kept short and fast
// it is important to avoid divides by non power of 2 numbers, remainder (mod) calculations, wait loops,
// or calls to functions that have wait loops. It's also not a good idea to write into any global that may be 
// used else where in the code inside here without interrupt protecting all accesses to that variable in 
// non ISR code, or making sure that if we do write to it in the ISR, we dont write/read to it in non ISR code
// (for example, below the heatPin objects are not written to if PIDEnable[i] = 1;
//
// Also the below ISR is set to nonblock so that interrupts are enabled as we enter the function
// this is done to make sure that we can run low counts in the compare registers, for example, 
// a count of 1 could cause an interrupts 1 processor clock cycle after this interrupt is called 
// sense it's called at bottom, and sense this has a fair amount of code in it, it's good to let the 
// compare interrupts interrupt this interrupt (same with the UART and timer0 interrupts)
ISR(TIMER1_OVF_vect, ISR_NOBLOCK )
{
    //count the number of times this has been called 
    timer1_overflow_count++;
    for(byte i = 0; i <= LAST_HEAT_OUTPUT; i++)
    {
        // if PID is enabled, and NOT one of the 8khz PWM outputs then we can use this
        if(PIDEnabled[i])
        {
            //init the cyclestart counter if needed
            if(cycleStart[i] == 0 ) cycleStart[i] = timer1_overflow_count; 
            //if our period just ended, update to when the next period ends
            if((timer1_overflow_count - cycleStart[i]) > PIDOutputCountEquivalent[i][0]) 
                cycleStart[i] += PIDOutputCountEquivalent[i][0];
            //check to see if the pin should be high or low (note when our 16 bit integer wraps we will have 1 period where 
            // the PWM % if cut short, because from the time of wrap until the next period 
            if (PIDOutputCountEquivalent[i][1] >= timer1_overflow_count - cycleStart[i] 
                  && timer1_overflow_count != cycleStart[i]) 
                heatPin[i].set(HIGH); else heatPin[i].set(LOW);
        }
    }
}

#endif //PWM_BY_TIMER


void pinInit() {
  alarmPin.setup(ALARM_PIN, OUTPUT);
  #ifdef HLTHEAT_PIN
    heatPin[VS_HLT].setup(HLTHEAT_PIN, OUTPUT);
  #endif
  #ifdef MASHHEAT_PIN
    heatPin[VS_MASH].setup(MASHHEAT_PIN, OUTPUT);
  #endif
  #ifdef HLT_AS_KETTLE
    #ifdef HLTHEAT_PIN
      heatPin[VS_KETTLE].setup(HLTHEAT_PIN, OUTPUT);
    #endif      
  #else
    #ifdef KETTLEHEAT_PIN
      heatPin[VS_KETTLE].setup(KETTLEHEAT_PIN, OUTPUT);
    #endif
  #endif

  #ifdef DIRECT_FIRED_RIMS
    //MASHHEAT_PIN should be defined, so setup above.
    heatPin[VS_STEAM].setup(STEAMHEAT_PIN, OUTPUT);
  #endif

  #ifdef USESTEAM
    #ifdef STEAMHEAT_PIN
      heatPin[VS_STEAM].setup(STEAMHEAT_PIN, OUTPUT);
    #endif
  #endif
  #ifdef PID_FLOW_CONTROL
    #ifdef PWMPUMP_PIN
      heatPin[VS_PUMP].setup(PWMPUMP_PIN, OUTPUT);
    #endif
  #endif

  #ifdef HEARTBEAT
    hbPin.setup(HEARTBEAT_PIN, OUTPUT);
  #endif
  
  #ifdef DIGITAL_INPUTS
    digInPin[0].setup(DIGIN1_PIN, INPUT);
    digInPin[1].setup(DIGIN2_PIN, INPUT);
    digInPin[2].setup(DIGIN3_PIN, INPUT);
    digInPin[3].setup(DIGIN4_PIN, INPUT);
    digInPin[4].setup(DIGIN5_PIN, INPUT);
  #endif
}

void pidInit() {
  //note that the PIDCycle for the 8khz outputs is set to 10 because the TOP of the counter/timer is set to 1000
  // this means that after it is multiplied by the PIDLIMIT it will be the proper value to give you the desired % output
  // it also makes the % calculations work properly in the log, UI, and other area's. 
  #ifdef PID_FLOW_CONTROL
    PIDCycle[VS_PUMP] = 1; // for PID pump flow the STEAM heat output is set to a fixed 10hz signal with 100 step outputs. 
  #endif
  
  for (byte vessel = VS_HLT; vessel <= VS_KETTLE; vessel++) {
    pid[vessel].SetInputLimits(0, 25500);
    pid[vessel].SetOutputLimits(0, PIDCycle[vessel] * pidLimits[vessel]);
    pid[vessel].SetTunings(getPIDp(vessel), getPIDi(vessel), getPIDd(vessel));
    pid[vessel].SetMode(AUTO);
    pid[vessel].SetSampleTime(PID_CYCLE_TIME);
  }
  pid[VS_KETTLE].SetMode(MANUAL);


  #ifdef PID_FLOW_CONTROL
    #ifdef USEMETRIC
      pid[VS_PUMP].SetInputLimits(0, 255000); // equivalent of 25.5 LPM (255 * 100)
    #else
      pid[VS_PUMP].SetInputLimits(0, 6375); // equivalent of 6.375 GPM (255 * 25)
    #endif
    pid[VS_PUMP].SetOutputLimits(PID_FLOW_MIN, PIDCycle[VS_PUMP] * PIDLIMIT_STEAM);
    pid[VS_PUMP].SetTunings(getPIDp(VS_PUMP), getPIDi(VS_PUMP), getPIDd(VS_PUMP));
    #ifdef PID_CONTROL_MANUAL
      pid[VS_PUMP].SetMode(MANUAL);
    #else
      pid[VS_PUMP].SetMode(AUTO);
    #endif
    pid[VS_PUMP].SetSampleTime(FLOWRATE_READ_INTERVAL);
    #ifdef PID_CONTROL_MANUAL
      nextcompute = millis() + FLOWRATE_READ_INTERVAL;
    #endif
  #else
    #ifdef USEMETRIC
      pid[VS_STEAM].SetInputLimits(0, 50000000 / steamPSens);
    #else
      pid[VS_STEAM].SetInputLimits(0, 7250000 / steamPSens);
    #endif
    pid[VS_STEAM].SetOutputLimits(0, PIDCycle[VS_STEAM] * PIDLIMIT_STEAM);
    pid[VS_STEAM].SetTunings(getPIDp(VS_STEAM), getPIDi(VS_STEAM), getPIDd(VS_STEAM));
    pid[VS_STEAM].SetMode(AUTO);
    pid[VS_STEAM].SetSampleTime(PID_CYCLE_TIME);
  #endif

  #ifdef DEBUG_PID_GAIN
    for (byte vessel = VS_HLT; vessel <= VS_STEAM; vessel++) logDebugPIDGain(vessel);
  #endif
}

void resetOutputs() {
  for (byte i = STEP_FILL; i <= STEP_CHILL; i++) stepExit(i); //Go through each step's exit functions to quit clean.
}

void resetHeatOutput(byte vessel) {
  #ifdef PWM_BY_TIMER
    uint8_t oldSREG;
  #endif
  setSetpoint(vessel, 0);
  PIDOutput[vessel] = 0;
  #ifdef PID_FEED_FORWARD
    if(vessel == VS_MASH)
      FFBias = 0;
  #endif
  #ifdef PWM_BY_TIMER
    // need to disable interrupts so a write into here can finish before an interrupt can come in and read it
    oldSREG = SREG;
    cli();
    //if we are not a 8K output then we can set it to 0, but if we are we need to set it to 1000 to make the duty cycle 0
    PIDOutputCountEquivalent[vessel][1] = 0;
  #endif
  heatPin[vessel].set(LOW);
  #ifdef PWM_BY_TIMER
    SREG = oldSREG; // restore interrupts
  #endif
}  

void processHeatOutputs() {
  //Process Heat Outputs
  unsigned long millistemp;
  #ifdef PWM_BY_TIMER
    uint8_t oldSREG;
  #endif

  #ifdef RIMS_MLT_SETPOINT_DELAY
    if(timetoset <= millis() && timetoset != 0){
      RIMStimeExpired = 1;
      timetoset = 0;
      setSetpoint(TS_MASH, getProgMashTemp(stepProgram[steptoset], steptoset - 5));
    }
  #endif
  
  for (byte i = VS_HLT; i <= LAST_HEAT_OUTPUT; i++) {
    #ifdef HLT_AS_KETTLE
      if (i == VS_KETTLE && setpoint[VS_HLT]) continue;
    #endif
    if (PIDEnabled[i]) {
      if (i != VS_STEAM && i != VS_KETTLE && temp[i] == BAD_TEMP) {
        PIDOutput[i] = 0;
      } else {
        if (pid[i].GetMode() == AUTO) {
      #ifdef PID_FLOW_CONTROL
        if(i == VS_PUMP) PIDInput[i] = flowRate[VS_KETTLE];
      #else
        #ifndef DIRECT_FIRE_RIMS
          if (i == VS_STEAM) PIDInput[i] = steamPressure; 
        #endif
      #endif
          else { 
            PIDInput[i] = temp[i];
      #ifdef PID_FEED_FORWARD
            if(i == VS_MASH ) FFBias = temp[FEED_FORWARD_SENSOR];
      #endif
          }
          pid[i].Compute();
        #ifdef PID_FLOW_CONTROL
          if(i == VS_PUMP && setpoint[i] == 0) PIDOutput[i] = 0; // if the setpoint is 0 then make sure we output 0, as dont want the min output always on. 
        #endif
        #ifdef PID_FEED_FORWARD
          if(i == VS_MASH && setpoint[i] == 0) PIDOutput[i] = 0; // found a bug where the mash output could be turned on if setpoint was 0 but FFBias was not 0. 
                                                                 // this fixes the bug but still lets the integral gain learn to compensate for the FFBias while 
                                                                 // the setpoint is 0. 
        #endif
        #ifdef HLT_KET_ELEMENT_SAVE
          if(i == VS_HLT && volAvg[i] < HLT_MIN_HEAT_VOL) PIDOutput[i] = 0;
          if(i == VS_KETTLE && volAvg[i] < KET_MIN_HEAT_VOL) PIDOutput[i] = 0;
        #endif
        }
      #if defined PID_FLOW_CONTROL && defined PID_CONTROL_MANUAL
        else if(i == VS_PUMP){ //manual control if PID isnt working due to long sample times or other reasons
          millistemp = millis();
          if(millistemp >= nextcompute){
            nextcompute += FLOWRATE_READ_INTERVAL;
            if(setpoint[i] == 0) PIDOutput[i] = 0;
            else{
              if((long)setpoint[i] - flowRate[VS_KETTLE] > 100){
                additioncount[0]++;
                additioncount[1] = 0;
                if(additioncount[0] > 5){    // this is here to break a case where adding 10 causes a change of 100 but lowering 10 causes a change of 100 off the setpoint and we just oscilate. 
                  additioncount[0] = 0;
                  PIDOutput[i] += 5;
                }
                else PIDOutput[i] += 10;
              }
              else if((long)setpoint[i] - flowRate[VS_KETTLE] < -100){
                additioncount[0]++;
                additioncount[1] = 0;
                if(additioncount[0] > 5){    // this is here to break a case where adding 10 causes a change of 100 but lowering 10 causes a change of 100 off the setpoint and we just oscilate. 
                 additioncount[0] = 0;
                 PIDOutput[i] -= 5;
               }
               else PIDOutput[i] -= 10;
              }
              else if((long)setpoint[i] - flowRate[VS_KETTLE] > 50){ 
                additioncount[0] = 0;
                additioncount[1]++;
                if(additioncount[0] > 5){    // this is here to break a case where adding 5 causes a change of 50 but lowering 5 causes a change of 50 off the setpoint and we just oscilate. 
                  additioncount[1] = 0;
                  PIDOutput[i] += 1;
                }
                else PIDOutput[i] += 5;
              }
              else if((long)setpoint[i] - flowRate[VS_KETTLE] < -50){ 
                additioncount[0] = 0;
                additioncount[1]++;
                if(additioncount[0] > 5){    // this is here to break a case where adding 5 causes a change of 50 but lowering 5 causes a change of 50 off the setpoint and we just oscilate. 
                  additioncount[1] = 0;
                  PIDOutput[i] -= 1;
                }
                else PIDOutput[i] -= 5;
              }
              else if((long)setpoint[i] - flowRate[VS_KETTLE] > 10) PIDOutput[i] += 1;
              else if((long)setpoint[i] - flowRate[VS_KETTLE] < -10) PIDOutput[i] -= 1;
              
              if(PIDOutput[i] > pid[i].GetOUTMax()) PIDOutput[i] = pid[i].GetOUTMax();
              else if(PIDOutput[i] < pid[i].GetOUTMin()) PIDOutput[i] = pid[i].GetOUTMin();
            }
          }
        }
      #endif // defined PID_FLOW_CONTROL && defined PID_CONTROL_MANUAL
      }
      #ifndef PWM_BY_TIMER
        //only 1 call to millis needed here, and if we get hit with an interrupt we still want to calculate based on the first read value of it
        millistemp = millis();
        if (cycleStart[i] == 0) cycleStart[i] = millistemp;
        if (millistemp - cycleStart[i] > PIDCycle[i] * 100) cycleStart[i] += PIDCycle[i] * 100;
        if (PIDOutput[i] >= millistemp - cycleStart[i] && millistemp != cycleStart[i]) heatPin[i].set(HIGH); else heatPin[i].set(LOW);
      #else
        //here we do as much math as we can OUT SIDE the ISR, we calculate the PWM cycle time in counter/timer counts
        // and place it in the [i][0] value, then calculate the timer counts to get the desired PWM % and place it in [i][1]
        // need to disable interrupts so a write into here can finish before an interrupt can come in and read it
        oldSREG = SREG;
        cli();
        PIDOutputCountEquivalent[i][0] = PIDCycle[i] * 800;
        PIDOutputCountEquivalent[i][1] = PIDOutput[i] * 8;
        SREG = oldSREG; // restore interrupts
      #endif
      if (PIDOutput[i] == 0)  heatStatus[i] = 0; else heatStatus[i] = 1;
    } else {
      if (heatStatus[i]) {
        if (
            #ifdef DIRECT_FIRE_RIMS
              (temp[i] == BAD_TEMP || temp[i] >= setpoint[i])
            #else
              (i != VS_STEAM && (temp[i] == BAD_TEMP || temp[i] >= setpoint[i]))
            #endif
            #ifndef DIRECT_FIRE_RIMS
              || (i == VS_STEAM && steamPressure >= setpoint[i])
            #endif
        ) {
          // For DIRECT_FIRED_RIMS, the setpoint for both VS_MASH & VS_STEAM should be the same, so nothing to do here.
          heatPin[i].set(LOW);
          heatStatus[i] = 0;
        } else {
          #ifdef DIRECT_FIRED_RIMS
            // When temp[VS_MASH] is less than setpoint[VS_MASH] - RIMS_TEMP_OFFSET, then
            // the VS_MASH pint should be set high, and VS_STEAM set low.  If the different
            // is within RIMS_TEMP_OFFSET, then the opposite.
            if (i == VS_MASH) {
              if (temp[i] >= setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(LOW);
                heatStatus[i] = 0;
              } else if ((temp[i] < setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(HIGH);
                heatStatus[i] = 1;
              }
            } else if (i == VS_STEAM ) {
              if (temp[i] < setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(LOW);
                heatStatus[i] = 0;
              } else if ((temp[i] < RIMS_MAX_TEMP) {
                heatPin[i].set(HIGH);
                heatStatus[i] = 1;
              }
            }
          #else
            heatPin[i].set(HIGH);
          #endif
        }
      } else {
        if (
          #ifdef DIRECT_FIRE_RIMS
            (temp[i] != BAD_TEMP && (setpoint[i] - temp[i]) >= hysteresis[i] * 10) 
          #else
            (i != VS_STEAM && temp[i] != BAD_TEMP && (setpoint[i] - temp[i]) >= hysteresis[i] * 10) 
          #endif
          #ifndef DIRECT_FIRE_RIMS
            || (i == VS_STEAM && (setpoint[i] - steamPressure) >= hysteresis[i] * 100)
          #endif
          ) {
          #ifdef DIRECT_FIRED_RIMS
            // When temp[VS_MASH] is less than setpoint[VS_MASH] - RIMS_TEMP_OFFSET, then
            // the VS_MASH pint should be set high, and VS_STEAM set low.  If the different
            // is within RIMS_TEMP_OFFSET, then the opposite.
            if (i == VS_MASH) {
              if (temp[i] >= setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(LOW);
                heatStatus[i] = 0;
              } else if ((temp[i] < setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(HIGH);
                heatStatus[i] = 1;
              }
            } else if (i == VS_STEAM ) {
              if (temp[i] < setpoint[VS_MASH] - RIMS_TEMP_OFFSET) {
                heatPin[i].set(LOW);
                heatStatus[i] = 0;
              } else if ((temp[i] < RIMS_MAX_TEMP) {
                heatPin[i].set(HIGH);
                heatStatus[i] = 1;
              }
            }
          #else
            heatPin[i].set(HIGH);
            heatStatus[i] = 1;
          #endif
        } else {
          // For DIRECT_FIRED_RIMS, the setpoint for both VS_MASH & VS_STEAM should be the same, so nothing to do here.
          heatPin[i].set(LOW);
        }
      }
    } // if/else PIDEnabled[i]   
  } // for loop
}

#ifdef PVOUT
  unsigned long prevProfiles;
  
  void updateValves() {
    if (actProfiles != prevProfiles) {
      Valves.set(computeValveBits());
      prevProfiles = actProfiles;
    }
  }

  void processAutoValve() {
    #ifdef HLT_MIN_REFILL
      unsigned long HLTStopVol;
    #endif
    //Do Valves
    if (autoValve[AV_FILL]) {
      if (volAvg[VS_HLT] < tgtVol[VS_HLT]) bitSet(actProfiles, VLV_FILLHLT);
        else bitClear(actProfiles, VLV_FILLHLT);
        
      if (volAvg[VS_MASH] < tgtVol[VS_MASH]) bitSet(actProfiles, VLV_FILLMASH);
        else bitClear(actProfiles, VLV_FILLMASH);
    }
    
    //HLT/MASH/KETTLE AV Logic
    for (byte i = VS_HLT; i <= VS_KETTLE; i++) {
      byte vlvHeat = vesselVLVHeat(i);
      byte vlvIdle = vesselVLVIdle(i);
      if (autoValve[vesselAV(i)]) {
        if (heatStatus[i]) {
          if (vlvConfigIsActive(vlvIdle)) bitClear(actProfiles, vlvIdle);
          if (!vlvConfigIsActive(vlvHeat)) bitSet(actProfiles, vlvHeat);
        } else {
          if (vlvConfigIsActive(vlvHeat)) bitClear(actProfiles, vlvHeat);
          if (!vlvConfigIsActive(vlvIdle)) bitSet(actProfiles, vlvIdle); 
        }
      }
    }
    
    if (autoValve[AV_SPARGEIN]) {
      if (volAvg[VS_HLT] > tgtVol[VS_HLT]) bitSet(actProfiles, VLV_SPARGEIN);
        else bitClear(actProfiles, VLV_SPARGEIN);
    }
    if (autoValve[AV_SPARGEOUT]) {
      if (volAvg[VS_KETTLE] < tgtVol[VS_KETTLE]) bitSet(actProfiles, VLV_SPARGEOUT);
      else bitClear(actProfiles, VLV_SPARGEOUT);
    }
    if (autoValve[AV_FLYSPARGE]) {
      if (volAvg[VS_KETTLE] < tgtVol[VS_KETTLE]) {
        #ifdef SPARGE_IN_PUMP_CONTROL
          if((long)volAvg[VS_KETTLE] - (long)prevSpargeVol[0] >= SPARGE_IN_HYSTERESIS)
          {
            #ifdef HLT_MIN_REFILL
               HLTStopVol = (SpargeVol > HLT_MIN_REFILL_VOL ? getVolLoss(VS_HLT) : (HLT_MIN_REFILL_VOL - SpargeVol));
               if(volAvg[VS_HLT] > HLTStopVol + 20)
            #else
               if(volAvg[VS_HLT] > getVolLoss(VS_HLT) + 20)
            #endif
                bitSet(actProfiles, VLV_SPARGEIN);
             prevSpargeVol[0] = volAvg[VS_KETTLE];
          }
          #ifdef HLT_FLY_SPARGE_STOP
          else if((long)prevSpargeVol[1] - (long)volAvg[VS_HLT] >= SPARGE_IN_HYSTERESIS || volAvg[VS_HLT] < HLT_FLY_SPARGE_STOP_VOLUME + 20)
          #else
          else if((long)prevSpargeVol[1] - (long)volAvg[VS_HLT] >= SPARGE_IN_HYSTERESIS || volAvg[VS_HLT] < getVolLoss(VS_HLT) + 20)
          #endif
          {
             bitClear(actProfiles, VLV_SPARGEIN);
             prevSpargeVol[1] = volAvg[VS_HLT];
          }
        #else
          bitSet(actProfiles, VLV_SPARGEIN);
        #endif
        bitSet(actProfiles, VLV_SPARGEOUT);
      } else {
        bitClear(actProfiles, VLV_SPARGEIN);
        bitClear(actProfiles, VLV_SPARGEOUT);
      }
    }
    if (autoValve[AV_CHILL]) {
      //Needs work
      /*
      //If Pumping beer
      if (vlvConfigIsActive(VLV_CHILLBEER)) {
        //Cut beer if exceeds pitch + 1
        if (temp[TS_BEEROUT] > pitchTemp + 1.0) bitClear(actProfiles, VLV_CHILLBEER);
      } else {
        //Enable beer if chiller H2O output is below pitch
        //ADD MIN DELAY!
        if (temp[TS_H2OOUT] < pitchTemp - 1.0) bitSet(actProfiles, VLV_CHILLBEER);
      }
      
      //If chiller water is running
      if (vlvConfigIsActive(VLV_CHILLH2O)) {
        //Cut H2O if beer below pitch - 1
        if (temp[TS_BEEROUT] < pitchTemp - 1.0) bitClear(actProfiles, VLV_CHILLH2O);
      } else {
        //Enable H2O if chiller H2O output is at pitch
        //ADD MIN DELAY!
        if (temp[TS_H2OOUT] >= pitchTemp) bitSet(actProfiles, VLV_CHILLH2O);
      }
      */
    }
  }
#endif //#ifdef PVOUT
  
unsigned long computeValveBits() {
  unsigned long vlvBits = 0;
  for (byte i = 0; i < NUM_VLVCFGS; i++) {
    if (bitRead(actProfiles, i)) {
      vlvBits |= vlvConfig[i];
    }
  }
  return vlvBits;
}

boolean vlvConfigIsActive(byte profile) {
  //An empty valve profile cannot be active
  if (!vlvConfig[profile]) return 0;
  return bitRead(actProfiles, profile);
}


//Map AutoValve Profiles to Vessels
byte vesselAV(byte vessel) {
  if (vessel == VS_HLT) return AV_HLT;
  else if (vessel == VS_MASH) return AV_MASH;
  else if (vessel == VS_KETTLE) return AV_KETTLE;
}

byte vesselVLVHeat(byte vessel) {
  if (vessel == VS_HLT) return VLV_HLTHEAT;
  else if (vessel == VS_MASH) return VLV_MASHHEAT;
  else if (vessel == VS_KETTLE) return VLV_KETTLEHEAT;
}

byte vesselVLVIdle(byte vessel) {
  if (vessel == VS_HLT) return VLV_HLTIDLE;
  else if (vessel == VS_MASH) return VLV_MASHIDLE;
  else if (vessel == VS_KETTLE) return VLV_KETTLEIDLE;
}
