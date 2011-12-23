#define BUILD 770
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

/*
Compiled on Arduino-0019 (http://arduino.cc/en/Main/Software)
  With Sanguino Software "Sanguino-0018r2_1_4.zip" (http://code.google.com/p/sanguino/downloads/list)

  Using the following libraries:
    PID  v0.6 (Beta 6) (http://www.arduino.cc/playground/Code/PIDLibrary)
    OneWire 2.0 (http://www.pjrc.com/teensy/arduino_libraries/OneWire.zip)
    Encoder by CodeRage ()
    FastPin and modified LiquidCrystal with FastPin by CodeRage (http://www.brewtroller.com/forum/showthread.php?t=626)
*/

#include "Config.h"
#include "Enum.h"

//*****************************************************************************************************************************
// BEGIN CODE
//*****************************************************************************************************************************
#include <avr/pgmspace.h>
#include <PID_Beta6.h>
#include <pin.h>
#include <menu.h>

void(* softReset) (void) = 0;

//**********************************************************************************
// Compile Time Logic
//**********************************************************************************

// Disable On board pump/valve outputs for BT Board 3.0 and older boards using steam
// Set MUXBOARDS 0 for boards without on board or MUX Pump/valve outputs

#if (defined BTBOARD_3 || defined BTBOARD_4) && !defined MUXBOARDS
  #define MUXBOARDS 2
#endif

#if !defined BTBOARD_3 && !defined BTBOARD_4 && !defined USESTEAM && !defined MUXBOARDS
  #define ONBOARDPV
#else
  #if !defined MUXBOARDS
    #define MUXBOARDS 0
  #endif
#endif

//Enable Mash Avergaing Logic if any Mash_AVG_AUXx options were enabled
#if defined MASH_AVG_AUX1 || defined MASH_AVG_AUX2 || defined MASH_AVG_AUX3
  #define MASH_AVG
#endif

//Use I2C LCD for BTBoard_4
#ifdef BTBOARD_4
  #define UI_LCD_I2C
  #define HEARTBEAT
#endif

//Select OneWire Comm Type
#ifdef TS_ONEWIRE
  #ifdef BTBOARD_4
    #define TS_ONEWIRE_I2C //BTBOARD_4 uses I2C if OneWire support is used
  #else
    #ifndef TS_ONEWIRE_I2C
      #define TS_ONEWIRE_GPIO //Previous boards use GPIO unless explicitly configured for I2C
    #endif
  #endif
#endif

#ifdef USEMETRIC
  #define SETPOINT_MULT 50
  #define SETPOINT_DIV 2
#else
  #define SETPOINT_MULT 100
  #define SETPOINT_DIV 1
#endif

#ifndef STRIKE_TEMP_OFFSET
  #define STRIKE_TEMP_OFFSET 0
#endif

#if COM_SERIAL0 == BTNIC || defined BTNIC_EMBEDDED
  #define BTNIC_PROTOCOL
#endif

#if defined BTPD_SUPPORT || defined UI_I2C_LCD || defined TS_I2C_ONEWIRE || defined BTNIC_EMBEDDED
  #define USE_I2C
#endif

#ifdef BOIL_OFF_GALLONS
  #ifdef USEMETRIC
    #define EvapRateConversion 1000
  #else
    #define EvapRateConversion 100
  #endif
#endif

#ifdef USE_I2C
  #include <Wire.h>
#endif

//**********************************************************************************
// Globals
//**********************************************************************************

//Heat Output Pin Array
pin heatPin[4], alarmPin;

#ifdef ONBOARDPV
  pin valvePin[11];
#endif

#if MUXBOARDS > 0
  pin muxLatchPin, muxDataPin, muxClockPin;
  #ifdef BTBOARD_4
    pin muxMRPin;
  #else
    pin muxOEPin;
  #endif
#endif

#ifdef BTBOARD_4
  pin digInPin[6];
  pin hbPin;
#endif

//Volume Sensor Pin Array
#ifdef HLT_AS_KETTLE
  byte vSensor[3] = { HLTVOL_APIN, MASHVOL_APIN, HLTVOL_APIN};
#else
  byte vSensor[3] = { HLTVOL_APIN, MASHVOL_APIN, KETTLEVOL_APIN};
#endif

//8-byte Temperature Sensor Address x9 Sensors
byte tSensor[9][8];
int temp[9];

//Volume in (thousandths of gal/l)
unsigned long tgtVol[3], volAvg[3], calibVols[3][10];
unsigned int calibVals[3][10];
#ifdef SPARGE_IN_PUMP_CONTROL
unsigned long prevSpargeVol[2] = {0,0};
#endif

#ifdef HLT_MIN_REFILL
unsigned long SpargeVol = 0;
#endif

#ifdef FLOWRATE_CALCS
//Flowrate in thousandths of gal/l per minute
long flowRate[3] = {0,0,0};
#endif

//Valve Variables
unsigned long vlvConfig[NUM_VLVCFGS], actProfiles;
boolean autoValve[NUM_AV];

//Shared buffers
char buf[20];

//Output Globals
double PIDInput[4], PIDOutput[4], setpoint[4];
#ifdef PID_FEED_FORWARD
double FFBias;
#endif
byte PIDCycle[4], hysteresis[4];
#ifdef PWM_BY_TIMER
unsigned int cycleStart[4] = {0,0,0,0};
#else
unsigned long cycleStart[4] = {0,0,0,0};
#endif
boolean heatStatus[4], PIDEnabled[4];
unsigned int steamPSens, steamZero;

byte pidLimits[4] = { PIDLIMIT_HLT, PIDLIMIT_MASH, PIDLIMIT_KETTLE, PIDLIMIT_STEAM };

//Steam Pressure in thousandths
unsigned long steamPressure;
byte boilPwr;

PID pid[4] = {
  PID(&PIDInput[VS_HLT], &PIDOutput[VS_HLT], &setpoint[VS_HLT], 3, 4, 1),

  #ifdef PID_FEED_FORWARD
    PID(&PIDInput[VS_MASH], &PIDOutput[VS_MASH], &setpoint[VS_MASH], &FFBias, 3, 4, 1),
  #else
    PID(&PIDInput[VS_MASH], &PIDOutput[VS_MASH], &setpoint[VS_MASH], 3, 4, 1),
  #endif

  PID(&PIDInput[VS_KETTLE], &PIDOutput[VS_KETTLE], &setpoint[VS_KETTLE], 3, 4, 1),

  #ifdef PID_FLOW_CONTROL
    PID(&PIDInput[VS_PUMP], &PIDOutput[VS_PUMP], &setpoint[VS_PUMP], 3, 4, 1)
  #else
    PID(&PIDInput[VS_STEAM], &PIDOutput[VS_STEAM], &setpoint[VS_STEAM], 3, 4, 1)
  #endif
};
#if defined PID_FLOW_CONTROL && defined PID_CONTROL_MANUAL
  unsigned long nextcompute;
  byte additioncount[2];
#endif

#ifdef RIMS_MLT_SETPOINT_DELAY
  byte steptoset = 0;
  byte RIMStimeExpired = 0;
  unsigned long starttime = 0;
  unsigned long timetoset = 0;
#endif

//Timer Globals
unsigned long timerValue[2], lastTime[2];
boolean timerStatus[2], alarmStatus;

//Log Globals
boolean logData = LOG_INITSTATUS;

//Brew Step Logic Globals
//Active program for each brew step
#define PROGRAM_IDLE 255
byte stepProgram[NUM_BREW_STEPS];
boolean preheated[4], doAutoBoil;

//Bit 1 = Boil; Bit 2-11 (See Below); Bit 12 = End of Boil; Bit 13-15 (Open); Bit 16 = Preboil (If Compile Option Enabled)
unsigned int hoptimes[10] = { 105, 90, 75, 60, 45, 30, 20, 15, 10, 5 };
byte pitchTemp;

const char BT[] PROGMEM = "BrewTroller";
const char BTVER[] PROGMEM = "2.3";

//Log Strings
const char LOGCMD[] PROGMEM = "CMD";
const char LOGDEBUG[] PROGMEM = "DEBUG";
const char LOGSYS[] PROGMEM = "SYS";
const char LOGCFG[] PROGMEM = "CFG";
const char LOGDATA[] PROGMEM = "DATA";

//PWM by timer globals
#ifdef PWM_BY_TIMER
unsigned int timer1_overflow_count = 0;
unsigned int PIDOutputCountEquivalent[4][2] = {{0,0},{0,0},{0,0},{0,0}};
#endif

//**********************************************************************************
// Setup
//**********************************************************************************

void setup() {
  #ifdef USE_I2C
    Wire.begin(BT_I2C_ADDR);
  #endif
  
  //Initialize Brew Steps to 'Idle'
  for(byte brewStep = 0; brewStep < NUM_BREW_STEPS; brewStep++) stepProgram[brewStep] = PROGRAM_IDLE;
  
  //Log initialization (Log.pde)
  comInit();

  //Pin initialization (Outputs.pde)
  pinInit();
  
  tempInit();

  //Check for cfgVersion variable and update EEPROM if necessary (EEPROM.pde)
  checkConfig();

  //Load global variable values stored in EEPROM (EEPROM.pde)
  loadSetup();

  //PID Initialization (Outputs.pde)
  pidInit();

  #ifdef PWM_BY_TIMER
  pwmInit();
  #endif

  //User Interface Initialization (UI.pde)
  //Moving this to last of setup() to allow time for I2CLCD to initialize
  #ifndef NOUI
    uiInit();
  #endif
}


//**********************************************************************************
// Loop
//**********************************************************************************

void loop() {
  //User Interface Processing (UI.pde)
  #ifndef NOUI
    uiCore();
  #endif
  
  //Core BrewTroller process code (BrewCore.pde)
  brewCore();
}
