/**
 * This sketch scans the serial port for readings from the box of weights, and uses
 * them to activate/deactivate buttons on a graphical representation of the box.
 *
 * The sketch outputs an arpeggio, controlled by the buttons on the bottom row
 * (parameters) and the buttons on the top row (value of the parameters).
 *
 * The code for the serial communication between Arduino and Processing was adapted
 * from the 'SimpleRead' Processing Example.
 *
 * The implementation of the sounds using the Minim library was informed by the
 * Minim documentation, notably by the two following entries:
 * http://code.compartmental.net/minim/audiooutput_method_playnote.html
 * http://code.compartmental.net/minim/oscil_method_patch.html
 */

// create variables for colours
int backgroundColour = 35; // dark grey background
float foregroundAlpha = 0; // alpha to darken the screen is the box is closed
int offColour = 80; // medium grey to show which buttons are off
int onColour = 150; // light grey to show which buttons are on
color gold = #E6AF2E; // gold to highlight which parameter is being changed

// create variables for font
PFont font14, font30;

// create variables for button coordinates
float[] buttonX = new float[8];
float[] buttonY = new float[8];
float[] buttonDiameter = new float[8];
float[] YOffset = new float[8];

// create variables to draw the buttons depending on the screen width and height
float[] XMultiplier = {.085, .262, .446, .645, .876, .854, .529, .174};
float[] YMultiplier = {.83, .83, .83, .83, .83, .17, .17, .17};
float[] DiameterMultiplier = {.107, .121, .121, .15, .186, .228, .228, .286};
// and to offset the top and bottom rows compared to the centre lines
float YOffsetMultiplier = .02;
float[] YOffsetDirection = {-1, -1, -1, -1, -1, 1, 1, 1};

// create variables for text below bottom row buttons
String[] buttonText = {"SCALE", "NOTES", "SIGNATURE", "WAVE", "MODULATOR"};
// and values displayed as strings by the buttons
String[] buttonValue = {" ", " ", " ", " ", " ", " ", " ", " "};

// setup serial communication 
import processing.serial.*;
Serial port; // serial port
String inString; // input string from serial port

// create variables for Arduino sensor states taken from serial port
boolean photocellState; // false for dark, true for bright
boolean[] weightState = new boolean [8]; // false for out, true for in

// create variables for last activated button in top and bottom rows
int lastBottomButtonOn; // 0 if last button on was button 1, 1 for button 2, etc.
int lastTopButtonOn; // 5 for button 6, 6 for button 7, etc.
// and for last state of each top row button
boolean lastButton6State, lastButton7State, 
  lastButton8State; // false for off, true for on

// setup minim library to generate and play sounds
import ddf.minim.*;
import ddf.minim.ugens.*;
Minim minim;
AudioOutput out; 

// create variables for sound output
Oscil carrierWave; // wave which carries the tone frequency
Oscil modulatorWave; // modulator wave
Waveform carrierWaveform; // waveform of the carrier wave
int modulatorFrequency; // frequency of the modulator in Hz

// create variables for volume of audio output
float vol = 1; // overall volume of the audio
// default volume of individual notes
float[] defaultVolume = {vol, vol, vol, vol, vol, vol, 
  vol, vol, vol, vol, vol, vol, 
  vol, vol, vol, vol, vol, vol, 
  vol, vol, vol, vol, vol, vol}; 
boolean boxMuted; // false is muted, true if not

// store arpeggio progressions in arrays
String[] major = {"C4", "E4", "G4", "E5", "C5", "G5", // C MAJ
  "A4", "C5", "E5", "C6", "A5", "E6", // A MIN
  "D4", "F4", "A4", "F5", "D5", "A5", // D MIN
  "G4", "B4", "D5", "B5", "G5", "D6"}; // G MAJ
String[] minor = {"C4", "Eb4", "G4", "Eb5", "C5", "G5", // C MIN
  "Bb4", "D5", "F5", "D6", "Bb5", "F6", // Bb MAJ
  "Ab4", "C5", "Eb5", "C6", "Ab5", "Eb6", // Ab MAJ
  "Bb4", "D5", "F5", "D6", "Bb5", "F6", }; // Bb MAJ
String[] harmonic = {"C4", "Eb4", "G4", "Eb5", "C5", "G5", // C MIN
  "Ab4", "C5", "Eb5", "C6", "Ab5", "Eb6", // Ab MAJ
  "F4", "Ab4", "C5", "Ab5", "F5", "C6", // F MIN
  "G4", "B4", "D5", "B5", "G5", "D6"}; // G MAJ

// create variables for notes being currently played
long time; // tracker for when notes need to be played
int noteDelay; // delay between each note in milliseconds
int noteIndex = 0; // tracker for array position of next note to be played
String[] currentScale = new String[24]; // scale being currently played
float[] currentVolume = new float[24]; // volume for each note being currently played
int numberOfNotes; // number of notes in the arpeggio being currently played

void setup() {
  // set the screen size
  fullScreen();
  // start serial communication
  printArray(Serial.list()); // list the ports in console
  port = new Serial(this, Serial.list()[1], 115200); // choose the Arduino Uno port
  // load the font and set the text alignment
  font14 = createFont("Avenir.ttc", 14);
  font30 = createFont("Avenir.ttc", 30);
  textAlign(CENTER, TOP);  
  // set the button diameters and coordinates depending on screen size
  for (int i = 0; i <= 7; i++) {
    buttonX[i] = width * XMultiplier[i]; // X coordinates for button centres
    buttonDiameter[i] = width * DiameterMultiplier[i]; // button diameters
    YOffset[i] = YOffsetDirection[i] * (buttonDiameter[i] / 2 - 
      height * YOffsetMultiplier); // vertical offset from each line
    buttonY[i] = height * YMultiplier[i] + YOffset[i]; // Y for button centres
  }
  // setup audio output
  minim = new Minim(this);
  out = minim.getLineOut();
  // initialise the waves 
  carrierWaveform = Waves.PHASOR; // start with phasor waveform
  carrierWave = new Oscil(Frequency.ofPitch("C4"), .5, carrierWaveform);
  modulatorWave = new Oscil(1, 1, Waves.SINE);
  modulatorWave.patch(carrierWave.amplitude); // connect the modulator
  carrierWave.patch(out); // start the audio
  // initialise the volume of each note being played
  arrayCopy(defaultVolume, currentVolume);
  // initialise the sound mute status
  boxMuted = false;
  // initialise the state of each remaining button in bottom row (waveform done above)
  arrayCopy(harmonic, currentScale); // start with the harmonic scale
  numberOfNotes = 6; // start with 6 notes in the arpeggio
  noteDelay = 510; // start with a 3/4 time signature
  modulatorFrequency = 1; // start the modulator at 1 Hz
}

void draw() {
  background(backgroundColour);
  readSensorStates(); // scan the serial port for updates on sensor states
  boxStatus(); // mute sound and change foreground transparency if box is closed
  assignButton1Value(); // assign value to button 1 depending on buttons in top row
  assignButton2Value(); // same
  assignButton3Value(); // same
  assignButton4Value(); // same
  assignButton5Value(); // same
  drawButtonLines(); // draw the button outlines
  writeButtonText(); // write the text by each button 
  playNotes(); // change the sound output based on each parameter
  fill(backgroundColour, foregroundAlpha); // set the transparency of foreground
  rect(0, 0, width, height); // draw foreground
}

void readSensorStates() {
  // if there is data on the serial port
  if (port.available() > 0) {
    // read the data
    inString = port.readStringUntil('\n');
    // and update the sensor states
    if (inString != null) {
      // for each weight [1-8]
      for (int i = 0; i <= 7; i++) {
        int weightNumber = i+1;
        if (inString.contains(str(weightNumber)+"o"))
          weightState[i] = false; // weight is out
        if (inString.contains(str(weightNumber)+"i")) {
          weightState[i] = true; // weight is in
          // store which bottom row weight was put in last
          if (i <= 4)
            lastBottomButtonOn = i;
          // store which top row button was put in last
          if (i >= 5)
            lastTopButtonOn = i;
        }
      }
      // and for the photocell
      if (inString.contains("d"))
        photocellState = false; // box is closed
      if (inString.contains("b"))
        photocellState = true; // box is open
    }
  }
}

void boxStatus() {
  // if the box is open, brighten the screen
  if (photocellState && foregroundAlpha > 0)
    foregroundAlpha -= 5;
  // if the box is open, increase the volume
  if (photocellState && vol < 1) {
    vol += .02;
    modulatorWave.setAmplitude(vol);
  }
  // if the box is closed, darken the screen
  if (!photocellState && foregroundAlpha < 255)
    foregroundAlpha += 5;
  // if the box is closed, decrease the volume
  if (!photocellState &&  vol >= 0.02) {
    vol -= .02;
    modulatorWave.setAmplitude(vol);
  }
  // if the volume is really low, mute the sound
  if (!photocellState &&  vol <= .02) {
    modulatorWave.setAmplitude(0);
    // and track the sound mute state so other functions stop affecting volume
    boxMuted = true;
  } else
    boxMuted = false;
}

void assignButton1Value() {
  // return if button 1 is not on and has not been activated last
  if (lastBottomButtonOn != 0 || !weightState[0])
    return;
  else {
    // setup the values to print for top row buttons
    buttonValue[5] = "MAJ";
    buttonValue[6] = "MIN";
    buttonValue[7] = "HAR";
    // update value to print and scale to play depending on last top button pressed
    if (lastTopButtonOn == 5) {
      buttonValue[0] = "MAJOR";
      arrayCopy(major, currentScale);
    }
    if (lastTopButtonOn == 6) {
      buttonValue[0] = "MINOR";
      arrayCopy(minor, currentScale);
    }
    if (lastTopButtonOn == 7) {
      buttonValue[0] = "HARMONIC";
      arrayCopy(harmonic, currentScale);
    }
  }
}

void assignButton2Value() {
  // return if button 2 is not on and has not been activated last
  if (lastBottomButtonOn != 1 || !weightState[1])
    return;
  else {
    // setup the values to print for top row buttons
    buttonValue[5] = "+1";
    buttonValue[6] = "+2";
    buttonValue[7] = "+3";
    // add the values of the top buttons which are currently on
    numberOfNotes = 0;
    if (weightState[5])
      numberOfNotes += 1;
    if (weightState[6])
      numberOfNotes += 2;
    if (weightState[7])
      numberOfNotes += 3;
    // update value to print for button 2
    buttonValue[1] = str(numberOfNotes);
    // reinitialise the current values in volume array in case we added more notes
    arrayCopy(defaultVolume, currentVolume);
    // and remove specific notes by turning their individual volume down to 0
    if (numberOfNotes <= 5) { // if 5 notes or less are on
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i+4] = 0; // mute the fifth note for each chord
    }
    if (numberOfNotes <= 4) { // also, if 4 notes or less are on
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i+1] = 0; // mute the second note for each chord
    }
    if (numberOfNotes <= 3) { // etc.
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i+2] = 0;
    }
    if (numberOfNotes <= 2) {
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i+5] = 0;
    }
    if (numberOfNotes <= 1) {
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i+3] = 0;
    }
    if (numberOfNotes == 0) {
      for (int i = 0; i <= 3; i++)
        currentVolume[6*i] = 0;
    }
  }
}

void assignButton3Value() {
  // return if button 3 is not on and has not been activated last
  if (lastBottomButtonOn != 2 || !weightState[2])
    return;
  else {
    // setup the values to print for top row buttons
    buttonValue[5] = "6/8";
    buttonValue[6] = "4/4";
    buttonValue[7] = "3/4";
    // check which top button was last pressed and update value to print for button 3
    buttonValue[2] = buttonValue[lastTopButtonOn];
    // update arpeggio's perceived time signature by changing delay between note onsets
    if (lastTopButtonOn == 5)
      noteDelay = 255; // half of 3/4
    if (lastTopButtonOn == 6)
      noteDelay = 340; // two thirds or 3/4
    if (lastTopButtonOn == 7)
      noteDelay = 510; // 3/4
  }
}

void assignButton4Value() {
  // return if button 4 is not on and has not been activated last
  if (lastBottomButtonOn != 3 || !weightState[3])
    return;
  else {
    // setup the values to print for top row buttons
    buttonValue[5] = "SIN";
    buttonValue[6] = "TRI";
    buttonValue[7] = "PHA";
    // update value to print for button 4, and waveform of carrier wave
    if (lastTopButtonOn == 5) {
      buttonValue[3] = "SINE";
      carrierWaveform = Waves.SINE;
    }
    if (lastTopButtonOn == 6) {
      buttonValue[3] = "TRIANGLE";
      carrierWaveform = Waves.TRIANGLE;
    }
    if (lastTopButtonOn == 7) {
      buttonValue[3] = "PHASOR";
      carrierWaveform = Waves.PHASOR;
    }
  }
}

void assignButton5Value() {
  // return if button 5 is not on and has not been activated last
  if (lastBottomButtonOn != 4 || !weightState[4])
    return;
  else {
    // setup the values to print for top row buttons
    buttonValue[5] = "-=5";
    buttonValue[6] = "+=5";
    buttonValue[7] = "+=1";
    // for each top row button press, add/deduct value from modulator frequency
    if (weightState[5] && weightState[5] != lastButton6State && modulatorFrequency >= 6)
      modulatorFrequency -= 5;
    if (weightState[6] && weightState[6] != lastButton7State && modulatorFrequency <= 45)
      modulatorFrequency += 5;
    if (weightState[7] && weightState[7] != lastButton8State && modulatorFrequency <= 49)
      modulatorFrequency += 1;
    // apply this change to the audio output
    modulatorWave.setFrequency(modulatorFrequency);
    // update value to print for button 5
    buttonValue[4] = str(modulatorFrequency) + " HZ";
    // and update the last state (on/off) for each top row button
    lastButton6State = weightState[5];
    lastButton7State = weightState[6];
    lastButton8State = weightState[7];
  }
}

void drawButtonLines() {
  // draw one horizontal line for each row of buttons
  strokeWeight(2);
  stroke(offColour);
  line(0, height * YMultiplier[0], width, height * YMultiplier[0]); // bottom row
  line(0, height * YMultiplier[5], width, height * YMultiplier[5]); // top row
  // draw the exterior outline of each button
  fill(backgroundColour);
  for (int i = 0; i <= 7; i++)
    ellipse(buttonX[i], buttonY[i], buttonDiameter[i], buttonDiameter[i]);
  // draw the interior outline of each button if the weights are in
  stroke(onColour);
  for (int i = 0; i <= 7; i++) {
    if (weightState[i]) {
      ellipse(buttonX[i], buttonY[i], buttonDiameter[i] - 10, buttonDiameter[i] - 10);
    }
  }
  // mask the edge of each button all the way to the horizontal lines
  noStroke();
  rect(0, height * YMultiplier[0] + 1, width, height); // bottom row
  rect(0, 0, width, height * YMultiplier[5]); // top row
}

void writeButtonText() {
  // write the name of each bottom row button
  for (int i = 0; i <= 4; i++) {
    if (weightState[i])
      fill(onColour); // in white if button is on
    else
      fill(offColour); // in grey if button is off
    textFont(font14);
    text(buttonText[i], buttonX[i], height * YMultiplier[i] + 5);
  }
  // write the value for each bottom row button
  for (int i = 0; i <= 4; i++) {
    if (lastBottomButtonOn == i && weightState[i])
      fill(gold); // in gold if button is on and was the last one activated
    else if (weightState[i])
      fill(onColour); // in white if button is on, but not last one activated
    else
      fill(offColour); // in grey if button is off
    text(buttonValue[i], buttonX[i], height * YMultiplier[i] + 25);
  }
  // don't write values for top buttons if not currently controlled by bottom row button
  if (!weightState[lastBottomButtonOn]) {
    buttonValue[5] = " ";
    buttonValue[6] = " ";
    buttonValue[7] = " ";
  }
  // otherwise, write the value for each top row button
  for (int i = 5; i <= 7; i++) {
    if (weightState[i])
      fill(onColour); // in white if button is on
    else
      fill(offColour); // in grey if button is off
    textFont(font30);
    text(buttonValue[i], buttonX[i], height * YMultiplier[i] - 6);
  }
}

void playNotes() {
  // check if enough time has passed to play a new note
  if (millis() - time > noteDelay) {
    // reset the tracker for when notes need to be played
    time = millis();
    // reset array position tracker of next note being played if end of array is reached
    if (noteIndex > 23)
      noteIndex = 0;
    // set the frequency of the note to play
    carrierWave.setFrequency(Frequency.ofPitch(currentScale[noteIndex]));
    // set the waveform of the carrier frequency
    carrierWave.setWaveform(carrierWaveform);
    // if the box is not currently muted
    if (!boxMuted)
    // set the overall volume depending on whether the note needs to be played or not
      modulatorWave.setAmplitude(currentVolume[noteIndex]);
    // update the array position tracker
    noteIndex++;
  }
}