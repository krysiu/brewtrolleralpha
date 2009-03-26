#define PROMPT -1
#define DOUGHIN 0
#define PROTEIN 1
#define SACCH 2
#define MASHOUT 3
#define PROMPT -1

void doAutoBrew() {
  unsigned int delayMins = 0;
  byte stepTemp[4], stepMins[4], spargeTemp;
  unsigned long tgtVol[3] = { 0, 0, getDefBatch() };
  unsigned long grainWeight = 0;
  unsigned int boilMins = 60;
  unsigned int mashRatio = 133;
  byte pitchTemp = 70;
  unsigned int boilAdds = 0;
  
  byte recoveryStep = 0;
  char buf[9];

  if (getPwrRecovery() == 1) {
    recoveryStep = getABRecovery();
    loadSetpoints();
    loadABSteps(stepTemp, stepMins);
    spargeTemp = getABSparge();
    delayMins = getABDelay();
    loadABVols(tgtVol);
    grainWeight = getABGrain();
    boilMins = getABBoil();
    mashRatio = getABRatio();
    pitchTemp = getABPitch();
    boilAdds = getABAdds();
  } else {
    spargeTemp = 168;
    if (sysHERMS) setpoint[HLT] = 180; else setpoint[HLT] = spargeTemp;
  
    strcpy_P(menuopts[0], PSTR("Single Infusion"));
    strcpy_P(menuopts[1], PSTR("Multi-Rest"));

    switch (scrollMenu("AutoBrew Program", menuopts, 2)) {
      case 0:
        stepTemp[DOUGHIN] = 0;
        stepMins[DOUGHIN] = 0;
        stepTemp[PROTEIN] = 0;
        stepMins[PROTEIN] = 0;
        stepTemp[SACCH] = 153;
        stepMins[SACCH] = 60;
        stepTemp[MASHOUT] = 168;
        stepMins[MASHOUT] = 0;
        break;
      case 1:
        stepTemp[DOUGHIN] = 104;
        stepMins[DOUGHIN] = 20;
        stepTemp[PROTEIN] = 122;
        stepMins[PROTEIN] = 20;
        stepTemp[SACCH] = 153;
        stepMins[SACCH] = 60;
        stepTemp[MASHOUT] = 168;
        stepMins[MASHOUT] = 0;
        break;
      default: return;
    }
    if (!unit) {
      //Convert default values from F to C
      setpoint[HLT] = round((setpoint[HLT] - 32) / 1.8);
      spargeTemp = round((spargeTemp - 32) / 1.8);
      for (int i = DOUGHIN; i <= MASHOUT; i++) if (stepTemp[i]) stepTemp[i] = round((stepTemp[i] - 32) / 1.8);
      //Convert mashRatio from qts/lb to l/kg
      mashRatio = round(mashRatio * 2.0863514);
      pitchTemp = round((pitchTemp - 32) / 1.8);
    }
  }
  char volUnit[5] = " l";
  char wtUnit[4] = " kg";
  char tempUnit[2] = "C";
  if (unit) {
    strcpy_P(volUnit, PSTR(" gal"));
    strcpy_P(wtUnit, PSTR(" lb"));
    strcpy_P (tempUnit, PSTR("F"));
  }
  
  boolean inMenu = 1;
  if (recoveryStep) inMenu = 0;
  while (inMenu) {

    strcpy_P(menuopts[0], PSTR("Batch Vol:"));
    strcpy_P(menuopts[1], PSTR("Grain Wt:"));
    strcpy_P(menuopts[2], PSTR("Boil Length:"));
    strcpy_P(menuopts[3], PSTR("Mash Ratio:"));
    strcpy_P(menuopts[4], PSTR("Delay Start:"));
    strcpy_P(menuopts[5], PSTR("HLT Temp:"));
    strcpy_P(menuopts[6], PSTR("Sparge Temp:"));
    strcpy_P(menuopts[7], PSTR("Pitch Temp:"));
    strcpy_P(menuopts[8], PSTR("Mash Schedule"));
    strcpy_P(menuopts[9], PSTR("Boil Additions"));    
    strcpy_P(menuopts[10], PSTR("Start Program"));
    strcpy_P(menuopts[11], PSTR("Exit"));

    ftoa((float)tgtVol[KETTLE]/1000, buf, 2);
    strncat(menuopts[0], buf, 5);
    strcat(menuopts[0], volUnit);

    ftoa((float)grainWeight/1000, buf, 3);
    strncat(menuopts[1], buf, 7);
    strcat(menuopts[1], wtUnit);

    strncat(menuopts[2], itoa(boilMins, buf, 10), 3);
    strcat_P(menuopts[2], PSTR(" min"));

    ftoa((float)mashRatio/100, buf, 2);
    strncat(menuopts[3], buf, 4);
    strcat_P(menuopts[3], PSTR(":1"));

    strncat(menuopts[4], itoa(delayMins/60, buf, 10), 4);
    strcat_P(menuopts[4], PSTR(" hr"));
    
    strncat(menuopts[5], itoa(setpoint[HLT], buf, 10), 3);
    strcat(menuopts[5], tempUnit);
    
    strncat(menuopts[6], itoa(spargeTemp, buf, 10), 3);
    strcat(menuopts[6], tempUnit);

    strncat(menuopts[7], itoa(pitchTemp, buf, 10), 3);
    strcat(menuopts[7], tempUnit);

    switch(scrollMenu("AutoBrew Parameters", menuopts, 12)) {
      case 0:
        tgtVol[KETTLE] = getValue("Batch Volume", tgtVol[KETTLE], 7, 3, 9999999, volUnit);
        break;
      case 1:
        grainWeight = getValue("Grain Weight", grainWeight, 7, 3, 9999999, wtUnit);
        break;
      case 2:
        boilMins = getTimerValue("Boil Length", boilMins);
        break;
      case 3:
        if (unit) mashRatio = getValue("Mash Ratio", mashRatio, 3, 2, 999, " qts/lb"); else mashRatio = getValue("Mash Ratio", mashRatio, 3, 2, 999, " l/kg");
        break;
      case 4:
        delayMins = getTimerValue("Delay Start", delayMins);
        break;
      case 5:
        setpoint[HLT] = getValue("HLT Setpoint", setpoint[HLT], 3, 0, 255, tempUnit);
        break;
      case 6:
        spargeTemp = getValue("HLT Setpoint", spargeTemp, 3, 0, 255, tempUnit);
        break;
      case 7:
        pitchTemp = getValue("Pitch Temp", pitchTemp, 3, 0, 255, tempUnit);
        break;
      case 8:
        editMashSchedule(stepTemp, stepMins);
        break;
      case 9:
        boilAdds = editHopSchedule(boilAdds);
        break;
      case 10:
        inMenu = 0;
        break;
      default:
        if(confirmExit()) {
          setPwrRecovery(0);
          return;
        }
    }
    //Detrmine Total Water Needed (Evap + Deadspaces)
    tgtVol[HLT] = round(tgtVol[KETTLE] / (1.0 - evapRate / 100.0 * boilMins / 60.0) + volLoss[HLT] + volLoss[MASH]);
    //Add Water Lost in Spent Grain
    if (unit) tgtVol[HLT] += round(grainWeight * .2143); else tgtVol[HLT] += round(grainWeight * 1.7884);
    //Calculate mash volume
    tgtVol[MASH] = round(grainWeight * mashRatio / 100.0);
    //Convert qts to gal for US
    if (unit) tgtVol[MASH] = round(tgtVol[MASH] / 4.0);
    tgtVol[HLT] -= tgtVol[MASH];

    {
      //Grain-to-volume factor for mash tun capacity (1 lb = .15 gal)
      float grain2Vol;
      if (unit) grain2Vol = .15; else grain2Vol = 1.25;

      //Check for capacity overages
      if (tgtVol[HLT] > capacity[HLT]) {
        clearLCD();
        printLCD_P(0, 0, PSTR("HLT too small for"));
        printLCD_P(1, 0, PSTR("sparge. Increase"));
        printLCD_P(2, 0, PSTR("mash ratio or"));
        printLCD_P(3, 0, PSTR("decrease batch size."));
        while (!enterStatus) delay(500);
        enterStatus = 0;
      }
      if (tgtVol[MASH] + round(grainWeight * grain2Vol) > capacity[MASH]) {
        clearLCD();
        printLCD_P(0, 0, PSTR("Mash tun too small."));
        printLCD_P(1, 0, PSTR("Decrease mash ratio"));
        printLCD_P(2, 0, PSTR("or grain weight."));
        while (!enterStatus) delay(500);
        enterStatus = 0;
      }
      {
        byte predictedSparge;
        if (sysHERMS) {
          if (unit) predictedSparge = round(((setpoint[HLT] * tgtVol[HLT]) - (stepTemp[MASHOUT] - stepTemp[SACCH]) * (tgtVol[MASH] + grainWeight * .05)) / tgtVol[HLT]);
          else predictedSparge = round(((setpoint[HLT] * tgtVol[HLT]) - (stepTemp[MASHOUT] - stepTemp[SACCH]) * (tgtVol[MASH] + grainWeight * .41)) / tgtVol[HLT]);
        } else predictedSparge = spargeTemp;
        if (predictedSparge > spargeTemp + 3) {
          clearLCD();
          printLCD_P(0, 0, PSTR("HLT setpoint may be"));
          printLCD_P(1, 0, PSTR("too high for sparge."));
          printLCD_P(2, 0, PSTR("Sparge:"));
          printLCD_P(3, 0, PSTR("Predicted HLT:"));
          printLCD(2, 7, itoa(spargeTemp, buf, 10));
          printLCD(3, 14, itoa(predictedSparge, buf, 10));
          printLCD(2, 10, tempUnit);
          printLCD(3, 17, tempUnit);
          while (!enterStatus) delay(500);
          enterStatus = 0;
        }
      }
      //Save Values to EEPROM for Recovery
      setPwrRecovery(1);
      setABRecovery(0);
      saveSetpoints();
      saveABSteps(stepTemp, stepMins);
      setABSparge(spargeTemp);
      setABDelay(delayMins);
      saveABVols(tgtVol);
      setABGrain(grainWeight);
      setABBoil(boilMins);
      setABRatio(mashRatio);
      setABPitch(pitchTemp);
      setABAdds(boilAdds);
    }
  }

  if (recoveryStep <= 1) {
    setABRecovery(1);
    manFill(tgtVol[HLT], tgtVol[MASH]);
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }
  
  if(delayMins && recoveryStep <= 2) {
    if (recoveryStep == 2) {
      delayStart(getTimerRecovery());
    } else { 
      setABRecovery(2);
      delayStart(delayMins);
    }
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }

  if (recoveryStep <= 3) {
    //Find first temp and adjust for strike temp
    byte strikeTemp = 0;
    int i = 0;
    while (strikeTemp == 0 && i <= MASHOUT) strikeTemp = stepTemp[i++];
    if (unit) strikeTemp = round(.2 / (mashRatio / 100.0) * (strikeTemp - 60)) + strikeTemp; else strikeTemp = round(.41 / (mashRatio / 100.0) * (strikeTemp - 16)) + strikeTemp;
    setpoint[MASH] = strikeTemp;
    
    setABRecovery(3);
    mashStep("Preheat", PROMPT);  
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }
  
  inMenu = 0;
  if (recoveryStep <=4) inMenu = 1;
  while(inMenu) {
    setABRecovery(4);
    clearLCD();
    printLCD_P(1, 5, PSTR("Add Grain"));
    printLCD_P(2, 0, PSTR("Press Enter to Start"));
    while(enterStatus == 0) delay(500);
    if (enterStatus == 1) {
      enterStatus = 0;
      inMenu = 0;
    } else {
      enterStatus = 0;
      if (confirmExit() == 1) setPwrRecovery(0); return;
    }
  }

  if (stepTemp[DOUGHIN] && recoveryStep <= 5) {
    setABRecovery(5);
    setpoint[MASH] = stepTemp[DOUGHIN];
    int recoverMins = getTimerRecovery();
    if (recoveryStep == 5 && recoverMins > 0) mashStep("Dough In", recoverMins); else mashStep("Dough In", stepMins[DOUGHIN]);
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }

  if (stepTemp[PROTEIN] && recoveryStep <= 6) {
    setABRecovery(6);
    setpoint[MASH] = stepTemp[PROTEIN];
    int recoverMins = getTimerRecovery();
    if (recoveryStep == 6 && recoverMins > 0) mashStep("Protein Rest", recoverMins); else mashStep("Protein Rest", stepMins[PROTEIN]);
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }

  if (stepTemp[SACCH] && recoveryStep <= 7) {
    setABRecovery(7);
    setpoint[MASH] = stepTemp[SACCH];
    int recoverMins = getTimerRecovery();
    if (recoveryStep == 7 && recoverMins > 0) mashStep("Sacch Rest", recoverMins); else mashStep("Sacch Rest", stepMins[SACCH]);
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }

  if (stepTemp[MASHOUT] && recoveryStep <= 8) {
    setABRecovery(8);
    setpoint[HLT] = spargeTemp;
    setpoint[MASH] = stepTemp[MASHOUT];
    int recoverMins = getTimerRecovery();
    if (recoveryStep == 8 && recoverMins > 0) mashStep("Mash Out", recoverMins); else mashStep("Mash Out", stepMins[MASHOUT]);
    if (enterStatus == 2) { enterStatus = 0; setPwrRecovery(0); return; }
  }

  //Hold last mash temp until user exits
  if (recoveryStep <= 9) {
    setABRecovery(9); 
    mashStep("Mash Complete", PROMPT);
    setpoint[HLT] = 0;
    setpoint[MASH] = 0;
  }
  
  if (recoveryStep <= 10) {
    setABRecovery(10); 
    manSparge();
  }
  
  if (recoveryStep <= 11) {
    setABRecovery(11); 
    setpoint[KETTLE] = 212;
    boilStage(boilMins, boilAdds);
  }
  
  if (recoveryStep <= 12) {
    setABRecovery(12); 
    manChill(pitchTemp);
  }
  
  enterStatus = 0;
  setABRecovery(0);
  setPwrRecovery(0);
}

void manFill(unsigned long hltVol, unsigned long mashVol) {
  char fString[7], buf[5];
  int fillHLT = getValveCfg(FILLHLT);
  int fillMash = getValveCfg(FILLMASH);
  int fillBoth = fillHLT || fillMash;

  while (1) {
    clearLCD();
    printLCD_P(0, 0, PSTR("HLT"));
    if (unit) printLCD_P(0, 5, PSTR("Fill (gal)")); else printLCD_P(0, 6, PSTR("Fill (l)"));
    printLCD_P(0, 16, PSTR("Mash"));

    printLCD_P(1, 7, PSTR("Target"));
    printLCD_P(2, 7, PSTR("Actual"));
    unsigned long whole = hltVol / 1000;
    //Throw away the last digit
    unsigned long frac = round ((hltVol - whole * 1000)/10.0);
    //Build string to align left

    strcpy(fString, ltoa(whole, buf, 10));
    strcat(fString, ".");
    strcat(fString, ltoa(frac, buf, 10));
    printLCD(1, 0, fString);

    whole = mashVol / 1000;
    //Throw away the last digit
    frac = round ((mashVol - whole * 1000)/10.0) ;
    printLCDPad(1, 14, ltoa(whole, buf, 10), 3, ' ');
    printLCD_P(1, 17, PSTR("."));
    printLCDPad(1, 18, ltoa(frac, buf, 10), 2, '0');

    setValves(0);
    printLCD_P(3, 0, PSTR("Off"));
    printLCD_P(3, 17, PSTR("Off"));

    encMin = 0;
    encMax = 5;
    encCount = 0;
    int lastCount = 1;
    
    boolean redraw = 0;
    while(!redraw) {
      if (encCount != lastCount) {
        switch(encCount) {
          case 0: printLCD_P(3, 4, PSTR("> Continue <")); break;
          case 1: printLCD_P(3, 4, PSTR("> Fill HLT <")); break;
          case 2: printLCD_P(3, 4, PSTR("> Fill Mash<")); break;
          case 3: printLCD_P(3, 4, PSTR("> Fill Both<")); break;
          case 4: printLCD_P(3, 4, PSTR(">  All Off <")); break;
          case 5: printLCD_P(3, 4, PSTR(">   Abort  <")); break;
        }
        lastCount = encCount;
      }
      if (enterStatus == 1) {
        enterStatus = 0;
        switch(encCount) {
          case 0: return;
          case 1:
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(fillHLT);
            break;
          case 2:
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(fillMash);
            break;
          case 3:
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(fillBoth);
            break;
          case 4:
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(0);
            break;
          case 5: if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
        }
      } else if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
      }
    }
  }
}

void delayStart(int iMins) {
  setTimer(iMins);
  while(1) {
    boolean redraw = 0;
    clearLCD();
    printLCD_P(0,0,PSTR("Delay Start"));
    printLCD_P(0,14,PSTR("(WAIT)"));
    while(timerValue > 0) { 
      printTimer(1,7);
      if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit() == 1) {
          enterStatus = 2;
          return;
        } else redraw = 1; break;
      }
    }
    if (!redraw) return;
  }
}

void mashStep(char sTitle[ ], int iMins) {
  char buf[6];
  float temp[2] = { 0, 0 };
  char sTempUnit[2] = "C";
  unsigned long convStart = 0;
  unsigned long cycleStart[2] = { 0, 0 };
  boolean heatStatus[2] = { 0, 0 };
  boolean preheated = 0;
  setAlarm(0);
  boolean doPrompt = 0;
  if (iMins == PROMPT) doPrompt = 1;
  timerValue = 0;
  
  for (int i = HLT; i <= MASH; i++) {
    if (PIDEnabled[i]) {
      pid[i].SetInputLimits(0, 255);
      pid[i].SetOutputLimits(0, PIDCycle[i] * 1000);
      PIDOutput[i] = 0;
      cycleStart[i] = millis();
    }
  }
  
  if (unit) strcpy_P(sTempUnit, PSTR("F"));

  while(1) {
    boolean redraw = 0;
    timerLastWrite = 0;
    clearLCD();
    printLCD(0,0,sTitle);
    printLCD_P(0,14,PSTR("(WAIT)"));
    printLCD_P(1,2,PSTR("HLT"));
    printLCD_P(3,0,PSTR("[    ]"));
    printLCD(2, 4, sTempUnit);
    printLCD(3, 4, sTempUnit);
    printLCD_P(1,15,PSTR("Mash"));
    printLCD_P(3,14,PSTR("[    ]"));
    printLCD(2, 18, sTempUnit);
    printLCD(3, 18, sTempUnit);
    
    while(!preheated || timerValue > 0 || doPrompt) {
      if (!preheated && temp[MASH] >= setpoint[MASH]) {
        preheated = 1;
        printLCD(0,14,"      ");
        if(doPrompt) printLCD_P(1, 0, PSTR("    > Continue <    ")); else setTimer(iMins);
      }

      for (int i = HLT; i <= MASH; i++) {
        if (temp[i] == -1) printLCD_P(2, i * 14 + 1, PSTR("---")); else printLCDPad(2, i * 14 + 1, itoa(temp[i], buf, 10), 3, ' ');
        printLCDPad(3, i * 14 + 1, itoa(setpoint[i], buf, 10), 3, ' ');
        if (PIDEnabled[i]) {
          byte pct = PIDOutput[i] / PIDCycle[i] / 10;
          switch (pct) {
            case 0: strcpy_P(buf, PSTR("Off")); break;
            case 100: strcpy_P(buf, PSTR(" On")); break;
            default: itoa(pct, buf, 10); strcat(buf, "%"); break;
          }
        } else if (heatStatus[i]) strcpy_P(buf, PSTR(" On")); else strcpy_P(buf, PSTR("Off")); 
        printLCDPad(3, i * 5 + 6, buf, 3, ' ');
      }
      if (!doPrompt) printTimer(1,7);

      if (convStart == 0) {
        convertAll();
        convStart = millis();
      } else if (millis() - convStart >= 750) {
        for (int i = HLT; i <= MASH; i++) temp[i] = read_temp(unit, tSensor[i]);
        convStart = 0;
      }

      for (int i = HLT; i <= MASH; i++) {
        boolean setOut;
        if (PIDEnabled[i]) {
          if (temp[i] == -1) {
            pid[i].SetMode(MANUAL);
            PIDOutput[i] = 0;
          } else {
            pid[i].SetMode(AUTO);
            PIDInput[i] = temp[i];
            pid[i].Compute();
          }
          if (millis() - cycleStart[i] > PIDCycle[i] * 1000) cycleStart[i] += PIDCycle[i] * 1000;
          if (PIDOutput[i] > millis() - cycleStart[i]) setOut = 1; else setOut = 0;
        } else {
          if (heatStatus[i]) {
            if (temp[i] == -1 || temp[i] >= setpoint[i]) {
              setOut = 0;
              heatStatus[i] = 0;
            } else setOut = 1;
          } else { 
            if (temp[i] != -1 && (float)(setpoint[i] - temp[i]) >= (float) hysteresis[i] / 10.0) {
              setOut = 1;
              heatStatus[i] = 1;
            } else setOut = 0;
          }
        }
        switch(i) {
          case HLT: digitalWrite(HLTHEAT_PIN, setOut); break;
          case MASH: digitalWrite(MASHHEAT_PIN, setOut); break;
          case KETTLE: digitalWrite(KETTLEHEAT_PIN, setOut); break;
        }
      }
      if (doPrompt && preheated && enterStatus == 1) { enterStatus = 0; break; }
      if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit() == 1) enterStatus = 2; else redraw = 1;
        break;
      }
    }
    if (!redraw) {
       //Turn off HLT and MASH outputs
       for (int i = HLT; i <= MASH; i++) { if (PIDEnabled[i]) pid[i].SetMode(MANUAL); }
       digitalWrite(HLTHEAT_PIN, LOW);
       digitalWrite(MASHHEAT_PIN, LOW);
       digitalWrite(KETTLEHEAT_PIN, LOW);
       //Exit
      return;
    }
  }
}

void editMashSchedule(byte stepTemp[4], byte stepMins[4]) {
  char buf[4];
  char tempUnit[2] = "C";
  if (unit) strcpy (tempUnit, "F");
  while (1) {
    strcpy_P(menuopts[0], PSTR("Dough In:"));
    strcpy_P(menuopts[1], PSTR("Dough In:"));
    strcpy_P(menuopts[2], PSTR("Protein Rest:"));
    strcpy_P(menuopts[3], PSTR("Protein Rest:"));
    strcpy_P(menuopts[4], PSTR("Sacch Rest:"));
    strcpy_P(menuopts[5], PSTR("Sacch Rest:"));
    strcpy_P(menuopts[6], PSTR("Mash Out:"));
    strcpy_P(menuopts[7], PSTR("Mash Out:"));
    strcpy_P(menuopts[8], PSTR("Exit"));
  
    strncat(menuopts[0], itoa(stepMins[DOUGHIN], buf, 10), 2);
    strcat(menuopts[0], " min");

    strncat(menuopts[1], itoa(stepTemp[DOUGHIN], buf, 10), 3);
    strcat(menuopts[1], tempUnit);
    
    strncat(menuopts[2], itoa(stepMins[PROTEIN], buf, 10), 2);
    strcat(menuopts[2], " min");

    strncat(menuopts[3], itoa(stepTemp[PROTEIN], buf, 10), 3);
    strcat(menuopts[3], tempUnit);
    
    strncat(menuopts[4], itoa(stepMins[SACCH], buf, 10), 2);
    strcat(menuopts[4], " min");

    strncat(menuopts[5], itoa(stepTemp[SACCH], buf, 10), 3);
    strcat(menuopts[5], tempUnit);
    
    strncat(menuopts[6], itoa(stepMins[MASHOUT], buf, 10), 2);
    strcat(menuopts[6], " min");

    strncat(menuopts[7], itoa(stepTemp[MASHOUT], buf, 10), 3);
    strcat(menuopts[7], tempUnit);

    switch (scrollMenu("Mash Schedule", menuopts, 9)) {
      case 0:
        stepMins[DOUGHIN] = getTimerValue("Dough In", stepMins[DOUGHIN]);
        break;
      case 1:
        stepTemp[DOUGHIN] = getValue("Dough In", stepTemp[DOUGHIN], 3, 0, 255, tempUnit);
        break;
      case 2:
        stepMins[PROTEIN] = getTimerValue("Protein Rest", stepMins[PROTEIN]);
        break;
      case 3:
        stepTemp[PROTEIN] = getValue("Protein Rest", stepTemp[PROTEIN], 3, 0, 255, tempUnit);
        break;
      case 4:
        stepMins[SACCH] = getTimerValue("Sacch Rest", stepMins[SACCH]);
        break;
      case 5:
        stepTemp[SACCH] = getValue("Sacch Rest", stepTemp[SACCH], 3, 0, 255, tempUnit);
        break;
      case 6:
        stepMins[MASHOUT] = getTimerValue("Mash Out", stepMins[MASHOUT]);
        break;
      case 7:
        stepTemp[MASHOUT] = getValue("Mash Out", stepTemp[MASHOUT], 3, 0, 255, tempUnit);
        break;
      default:
        return;
    }
  }
}

void manSparge() {
  char fString[7], buf[5];
  int spargeIn = getValveCfg(SPARGEIN);
  int spargeOut = getValveCfg(SPARGEOUT);
  int spargeFly = spargeIn || spargeOut;

  while (1) {
    clearLCD();
    printLCD_P(0, 8, PSTR("Sparge"));
    printLCD_P(1, 0, PSTR("HLT"));
    printLCD_P(1, 16, PSTR("Mash"));
    printLCD_P(2, 7, PSTR("Volume"));

    setValves(0);
    printLCD_P(3, 0, PSTR("Off"));
    printLCD_P(3, 17, PSTR("Off"));

    encMin = 0;
    encMax = 5;
    encCount = 0;
    int lastCount = 1;
    
    boolean redraw = 0;
    while(!redraw) {
      if (encCount != lastCount) {
        switch(encCount) {
          case 0: printLCD_P(3, 4, PSTR("> Continue <")); break;
          case 1: printLCD_P(3, 4, PSTR("> Sparge In<")); break;
          case 2: printLCD_P(3, 4, PSTR(">Sparge Out<")); break;
          case 3: printLCD_P(3, 4, PSTR(">Fly Sparge<")); break;
          case 4: printLCD_P(3, 4, PSTR(">  All Off <")); break;
          case 5: printLCD_P(3, 4, PSTR(">   Abort  <")); break;
        }
        lastCount = encCount;
      }
      if (enterStatus == 1) {
        enterStatus = 0;
        switch(encCount) {
          case 0: return;
          case 1:
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(spargeIn);
            break;
          case 2:
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(spargeOut);
            break;
          case 3:
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(spargeFly);
            break;
          case 4:
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(0);
            break;
          case 5: if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
        }
      } else if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
      }
    }
  }  
}

void boilStage(unsigned int iMins, byte boilAdds) {
  char buf[6];
  float temp = 0;
  char sTempUnit[2] = "C";
  unsigned long convStart = 0;
  unsigned long cycleStart = 0;
  boolean heatStatus = 0;
  boolean preheated = 0;
  setAlarm(0);
  timerValue = 0;
  
  if (PIDEnabled[KETTLE]) {
    pid[KETTLE].SetInputLimits(0, 255);
    pid[KETTLE].SetOutputLimits(0, PIDCycle[KETTLE] * 1000);
    PIDOutput[KETTLE] = 0;
    cycleStart = millis();
  }
  
  if (unit) strcpy_P(sTempUnit, PSTR("F"));

  while(1) {
    boolean redraw = 0;
    timerLastWrite = 0;
    clearLCD();
    printLCD_P(0,8,PSTR("Boil"));
    printLCD_P(0,14,PSTR("(WAIT)"));
    printLCD_P(3,0,PSTR("[    ]"));
    printLCD(2, 4, sTempUnit);
    printLCD(3, 4, sTempUnit);
    
    while(!preheated || timerValue > 0) {
      if (!preheated && temp >= setpoint[KETTLE]) {
        preheated = 1;
        printLCD_P(0,14,PSTR("      "));
        setTimer(iMins);
      }

      if (temp == -1) printLCD_P(2, 1, PSTR("---")); else printLCDPad(2, 1, itoa(temp, buf, 10), 3, ' ');
      printLCDPad(3, 1, itoa(setpoint[KETTLE], buf, 10), 3, ' ');
      if (PIDEnabled[KETTLE]) {
        byte pct = PIDOutput[KETTLE] / PIDCycle[KETTLE] / 10;
        switch (pct) {
          case 0: strcpy_P(buf, PSTR("Off")); break;
          case 100: strcpy_P(buf, PSTR(" On")); break;
          default: itoa(pct, buf, 10); strcat(buf, "%"); break;
        }
      } else if (heatStatus) strcpy_P(buf, PSTR(" On")); else strcpy_P(buf, PSTR("Off")); 
      printLCDPad(3, 6, buf, 3, ' ');

      printTimer(1,7);

      if (convStart == 0) {
        convertAll();
        convStart = millis();
      } else if (millis() - convStart >= 750) {
        temp = read_temp(unit, tSensor[KETTLE]);
        convStart = 0;
      }

      if (PIDEnabled[KETTLE]) {
        if (temp == -1) {
          pid[KETTLE].SetMode(MANUAL);
          PIDOutput[KETTLE] = 0;
        } else {
          pid[KETTLE].SetMode(AUTO);
          PIDInput[KETTLE] = temp;
          pid[KETTLE].Compute();
        }
        if (millis() - cycleStart > PIDCycle[KETTLE] * 1000) cycleStart += PIDCycle[KETTLE] * 1000;
        if (PIDOutput[KETTLE] > millis() - cycleStart) digitalWrite(KETTLEHEAT_PIN, HIGH); else digitalWrite(KETTLEHEAT_PIN, LOW);
      } else {
        if (heatStatus) {
          if (temp == -1 || temp >= setpoint[KETTLE]) {
            digitalWrite(KETTLEHEAT_PIN, LOW);
            heatStatus = 0;
          } else digitalWrite(KETTLEHEAT_PIN, HIGH);
        } else { 
          if (temp != -1 && (float)(setpoint[KETTLE] - temp) >= (float) hysteresis[KETTLE] / 10.0) {
            digitalWrite(KETTLEHEAT_PIN, HIGH);
            heatStatus = 1;
          } else digitalWrite(KETTLEHEAT_PIN, LOW);
        }
      }

      if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit() == 1) enterStatus = 2; else redraw = 1;
        break;
      }
    }
    if (!redraw) {
       //Turn off output
       if (PIDEnabled[KETTLE]) pid[KETTLE].SetMode(MANUAL);
       digitalWrite(KETTLEHEAT_PIN, LOW);
       //Exit
      return;
    }
  }
}

void manChill(byte settemp) {
  boolean doAuto = 0;
  char fString[7], buf[5];
  int chillLow = getValveCfg(CHILLBEER);
  int chillHigh = getValveCfg(CHILLH2O);
  int chillNorm = chillLow || chillHigh;
  unsigned long convStart = 0;
  float temp[6];
  
  while (1) {
    clearLCD();
    printLCD_P(0, 8, PSTR("Chill"));
    printLCD_P(0, 0, PSTR("Beer"));
    printLCD_P(0, 17, PSTR("H2O"));
    printLCD_P(1, 9, PSTR("IN"));
    printLCD_P(2, 9, PSTR("OUT"));
    if (unit) {
      printLCD_P(1, 3, PSTR("F"));
      printLCD_P(1, 19, PSTR("F"));
      printLCD_P(2, 3, PSTR("F"));
      printLCD_P(2, 19, PSTR("F"));
    } else {
      printLCD_P(1, 3, PSTR("C"));
      printLCD_P(1, 19, PSTR("C"));
      printLCD_P(2, 3, PSTR("C"));
      printLCD_P(2, 19, PSTR("C"));
    }
    
    setValves(0);
    printLCD_P(3, 0, PSTR("Off"));
    printLCD_P(3, 17, PSTR("Off"));

    encMin = 0;
    encMax = 6;
    encCount = 0;
    int lastCount = 1;
    
    boolean redraw = 0;
    while(!redraw) {
      if (encCount != lastCount) {
        switch(encCount) {
          case 0: printLCD_P(3, 4, PSTR("> Continue <")); break;
          case 1: printLCD_P(3, 4, PSTR(">Chill Norm<")); break;
          case 2: printLCD_P(3, 4, PSTR("> H2O Only <")); break;
          case 3: printLCD_P(3, 4, PSTR("> Beer Only<")); break;
          case 4: printLCD_P(3, 4, PSTR(">  All Off <")); break;
          case 5: printLCD_P(3, 4, PSTR(">   Auto   <")); break;
          case 6: printLCD_P(3, 4, PSTR(">   Abort  <")); break;
        }
        lastCount = encCount;
      }
      if (enterStatus == 1) {
        enterStatus = 0;
        switch(encCount) {
          case 0: return;
          case 1:
            doAuto = 0;
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(chillNorm);
            break;
          case 2:
            doAuto = 0;
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(chillHigh);
            break;
          case 3:
            doAuto = 0;
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(chillLow);
            break;
          case 4:
            doAuto = 0;
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(0);
            break;
          case 5:
            doAuto = 1;
            break;  
          case 6: if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
        }
      } else if (enterStatus == 2) {
        enterStatus = 0;
        if (confirmExit()) { enterStatus = 2; return; } else redraw = 1;
      }
      if (convStart == 0) {
        convertAll();
        convStart = millis();
      } else if (millis() - convStart >= 750) {
        for (int i = KETTLE; i <= BEEROUT; i++) temp[i] = read_temp(unit, tSensor[i]);
        convStart = 0;
      }
      if (temp[KETTLE] == -1) printLCD_P(1, 0, PSTR("---")); else printLCDPad(1, 0, itoa(temp[KETTLE], buf, 10), 3, ' ');
      if (temp[BEEROUT] == -1) printLCD_P(2, 0, PSTR("---")); else printLCDPad(2, 0, itoa(temp[BEEROUT], buf, 10), 3, ' ');
      if (temp[H2OIN] == -1) printLCD_P(1, 16, PSTR("---")); else printLCDPad(1, 16, itoa(temp[H2OIN], buf, 10), 3, ' ');
      if (temp[H2OOUT] == -1) printLCD_P(2, 16, PSTR("---")); else printLCDPad(2, 16, itoa(temp[H2OOUT], buf, 10), 3, ' ');
      if (doAuto) {
        if (temp[BEEROUT] > settemp + 1.0) {
            printLCD_P(3, 0, PSTR("Off"));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(chillHigh);
        } else if (temp[BEEROUT] < settemp - 1.0) {
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR("Off"));
            setValves(chillLow);
        } else {
            printLCD_P(3, 0, PSTR("On "));
            printLCD_P(3, 17, PSTR(" On"));
            setValves(chillNorm);
        }
      }
    }
  }  
}

unsigned int editHopSchedule (unsigned int sched) {
  unsigned int retVal = sched;
  while (1) {
    if (retVal & 1) strcpy_P(menuopts[0], PSTR("Boil: On")); else strcpy_P(menuopts[0], PSTR("Boil: Off"));
    if (retVal & 2) strcpy_P(menuopts[1], PSTR("105 Min: On")); else strcpy_P(menuopts[1], PSTR("105 Min: Off"));
    if (retVal & 4) strcpy_P(menuopts[2], PSTR("90 Min: On")); else strcpy_P(menuopts[2], PSTR("90 Min: Off"));
    if (retVal & 8) strcpy_P(menuopts[3], PSTR("75 Min: On")); else strcpy_P(menuopts[3], PSTR("75 Min: Off"));
    if (retVal & 16) strcpy_P(menuopts[4], PSTR("60 Min: On")); else strcpy_P(menuopts[4], PSTR("60 Min: Off"));
    if (retVal & 32) strcpy_P(menuopts[5], PSTR("45 Min: On")); else strcpy_P(menuopts[5], PSTR("45 Min: Off"));
    if (retVal & 64) strcpy_P(menuopts[6], PSTR("30 Min: On")); else strcpy_P(menuopts[6], PSTR("30 Min: Off"));
    if (retVal & 128) strcpy_P(menuopts[7], PSTR("20 Min: On")); else strcpy_P(menuopts[7], PSTR("20 Min: Off"));
    if (retVal & 256) strcpy_P(menuopts[8], PSTR("15 Min: On")); else strcpy_P(menuopts[8], PSTR("15 Min: Off"));
    if (retVal & 512) strcpy_P(menuopts[9], PSTR("10 Min: On")); else strcpy_P(menuopts[9], PSTR("10 Min: Off"));
    if (retVal & 1028) strcpy_P(menuopts[10], PSTR("5 Min: On")); else strcpy_P(menuopts[10], PSTR("5 Min: Off"));
    if (retVal & 2048) strcpy_P(menuopts[11], PSTR("0 Min: On")); else strcpy_P(menuopts[11], PSTR("0 Min: Off"));
    strcpy_P(menuopts[12], PSTR("Exit")); 
    switch(scrollMenu("Boil Additions", menuopts, 13)) {
      case 0: retVal = retVal ^ 1; break;      
      case 1: retVal = retVal ^ 2; break;
      case 2: retVal = retVal ^ 4; break;
      case 3: retVal = retVal ^ 8; break;
      case 4: retVal = retVal ^ 16; break;
      case 5: retVal = retVal ^ 32; break;
      case 6: retVal = retVal ^ 64; break;
      case 7: retVal = retVal ^ 128; break;      
      case 8: retVal = retVal ^ 256; break;
      case 9: retVal = retVal ^ 512; break;
      case 10: retVal = retVal ^ 1024; break;
      case 11: retVal = retVal ^ 2048; break;
      case 12: return retVal;
      default: return sched;
    }
  }
}
