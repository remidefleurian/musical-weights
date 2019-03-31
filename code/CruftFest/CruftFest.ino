/**
 * This sketch takes in/out readings for the eight brass weights, and converts
 * the photocell reading to a dark/bright reading, before sending these readings
 * to Processing over the serial port.
 * 
 * The debouncing part of the code was adapted from Mellis's 2006 Arduino
 * Tutorial, available on: https://www.arduino.cc/en/Tutorial/Debounce
 */

// assign pin numbers to variables
int photocell = A4; // pin A4 for photocell
int weight[8]; // 8 pin values for brass weights

// create variables for readings
int photocellValue; // 0 for dark up to 1023 for bright
boolean lastPhotocellReading; // 0 for dark, 1 for bright (last reading)
boolean photocellReading; // 0 for dark, 1 for bright (current reading)
boolean photocellState; // 0 for dark, 1 for bright (current debounced state)
// same principle with weight readings, with 0 for out, 1 for in
boolean lastWeightReading[8], weightReading[8], weightState[8];

// create variables for debouncing
// first variable records the last time each sensor was toggled on or off
unsigned long lastDebounceTime[9]; // [0-7] for weights, [8] for photocell
// second variable sets the debounce delay below which signals will ignored
unsigned long debounceDelay = 100; // delay increased to 100 ms for stability

void setup() {
  // declare photocell pin as input
  pinMode(photocell, INPUT);
  // assign pin numbers to weights and declare as inputs
  for(int i = 0; i <= 7; i++) {
    weight[i] = i + 2; // first weight on pin 2, second on pin 3, etc.
    pinMode(i + 2, INPUT);
  }
  // start serial communication at 115200 bps
  Serial.begin(115200);
}

void loop() {
  // code separated in two functions for clarity
  sendPhotocellState(); // update photocell state on serial port if needed
  sendWeightState(); // update weight state on serial port if needed
}

void sendPhotocellState() {
  // read current value on photocell
  photocellValue = analogRead(photocell);
  // update current photocell reading
  if(photocellValue < 50)
    photocellReading = 0; // dark
  else
    photocellReading = 1; // bright
  // reset the debounce timer if the photocell reading has changed
  if(photocellReading != lastPhotocellReading)
    lastDebounceTime[8] = millis();
  // if the reading is different from the current state, and not accidental
  if((millis() - lastDebounceTime[8]) > debounceDelay 
    && photocellReading != photocellState) {
    // consider the reading as the new current state
    photocellState = photocellReading;
    // send dark/bright to the serial port depending on the state
    if (!photocellState)
      Serial.println("d"); // dark
    if (photocellState)
      Serial.println("b"); // bright
  }
  // in any case, update the last photocell reading
  lastPhotocellReading = photocellReading;
}

void sendWeightState() {
  // repeat the process below for each weight
  for(int i = 0; i <= 7; i++) {
    // read current pin state  
    weightReading[i] =  digitalRead(weight[i]);
    // reset the debounce timer if the pin reading has changed
    if(weightReading[i] != lastWeightReading[i])
      lastDebounceTime[i] = millis();
    // if the reading is different from the current state, and not accidental
    if ((millis() - lastDebounceTime[i]) > debounceDelay 
      && weightReading[i] != weightState[i]) {
      // consider the reading as the new current state
      weightState[i] = weightReading[i];
      // send value to the serial port depending on the state
      if(!weightState[i]) {
        Serial.print(i+1); // weight number
        Serial.println("o"); // out
      }
      if(weightState[i]) {
        Serial.print(i+1); // weight number
        Serial.println("i"); // in
      }
    }
    // in any case, update the last photocell reading
    lastWeightReading[i] = weightReading[i];
  }
}
