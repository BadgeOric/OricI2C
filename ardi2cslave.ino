/// Wire Slave Receiver
// by Nicholas Zambetti <http://www.zambetti.com>

// Demonstrates use of the Wire library
// Receives data as an I2C/TWI slave device
// Refer to the "Wire Master Writer" example for use with this

// Created 29 March 2006

// This example code is in the public domain.


#include <Wire.h>
int incomingByte = 0; // for incoming serial data
int bufflen = 0;// count of serial inputs
int mybuff[33]={};
int curpos=0;
int bufffull=0;
void setup()
{
  Wire.begin(4);                // join i2c bus with address #4
  Wire.onReceive(receiveEvent); // register event
  Wire.onRequest(requestEvent);
  Serial.begin(9600);           // start serial for output
}

void loop()
{
  if (Serial.available()>0) {
          if(bufffull==1){
            // do nothing
                      }
          else
          {
            incomingByte=Serial.read();
            mybuff[curpos]=incomingByte;
            Serial.write(incomingByte);
            curpos++;
            if(curpos>32) {bufffull=1;}
          }
      }
  

}

// function that executes whenever data is received from master
// this function is registered as an event, see setup()
void receiveEvent(int howMany)
{
  while(1 < Wire.available()) // loop through all but the last
  {
    char c = Wire.read(); // receive byte as a character
    Serial.print(c);         // print the character
  }
  int x = Wire.read();    // receive byte as an integer
  if (x!=0){
  Serial.write(x);         // print the integer as a character
  if (x==13) { Serial.write("\r\n"); }    //cr and lf

  }
  
}


void requestEvent()
{
  for (byte i = 0; i < 32; i = i + 1) {
    if(i<=curpos){
          Wire.write(mybuff[i]);
          mybuff[i]=0;
          }        
      }
      curpos=0;
      bufffull=0;  
}
