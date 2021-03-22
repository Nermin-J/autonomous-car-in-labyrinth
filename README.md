# autonomous-car-in-labyrinth

Main code is inside Folder "src" -> main.

This is multi-threading (used CMSIS RTOS API) application with 4 periodical tasks:
  1. task - reads the zero channel of the ADC with 30s period. The mean and variance of the last 20 samples are then calculated and sent in mailqueue in structure named "data".
  2. task - reads the first channel of the ADC with 40s period. The mean and variance of the last 20 samples are then calculated and sent in mailqueue in structure named "data".
  3. task - reads the second channel of the ADC with 50s period. The mean and variance of the last 20 samples are then calculated and sent in mailqueue in structure named "data".
  4. task - used for communication. In the example, we just read data from mailqueue. In real app, these data can be sent to the supervisory computer over communication interface.
