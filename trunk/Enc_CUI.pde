unsigned int encBounceDelay = 50;
volatile unsigned long lastEncUpd = millis();
unsigned long enterStart;
  
void doEncoderA() {
  if (millis() - lastEncUpd < encBounceDelay) return;
  if (digitalRead(encBPin) == LOW) encCount++; else encCount--;
  if (encCount == -1) encCount = 0; else if (encCount < encMin) { encCount = encMin; } else if (encCount > encMax) { encCount = encMax; }
  lastEncUpd = millis();
} 

void doEnter() {
  if (digitalRead(enterPin) == HIGH) {
    enterStart = millis();
  } else {
    if (millis() - enterStart > 1000) {
    enterStatus = 2;
    } else {
    enterStatus = 1;
    }
  }
}

