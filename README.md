# autonomous-car-in-labyrinth

Video link: https://youtu.be/Ii4fzLuS3eI

The main motion algorithm is deployed to FPGA. The FPGA project consists of different parts that are combined into one whole to form a complete algorithm and auxiliary modules.

The main parts of a robot are: 
  1. two motors (whose speeds and direction are controlled by a PWM signal)
  2. 3 ultrasonic sensors:
      - one in the middle to measure distance from the wall in front 
      - two on right and left to keep robot in the middle of the path

Motion algorithm is implemented using FSM:

![image](https://user-images.githubusercontent.com/81052940/111932551-efb4fd00-8abd-11eb-9e6f-56c27fdcfe3f.png)

Drivers for all components done using Verilog (no external microcontrollers).
All components of code are connected like this:
![image](https://user-images.githubusercontent.com/81052940/111932818-8e415e00-8abe-11eb-8fa4-dc4ed09eeaa1.png)

Distance measured by sensor in the middle is sent over BT to the PC. Here we use "Processing" implementation given in "pathDrawing.pde" file. We read message sent over BT and make actions depending on the message (turning and moving).
