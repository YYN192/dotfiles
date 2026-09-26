#!/bin/bash

# Slider in the volume popup: clicking/dragging passes the new level in $PERCENTAGE.
# Setting the volume fires volume_change, which updates the bar item and slider.

if [ "$SENDER" = "mouse.clicked" ]; then
  osascript -e "set volume output volume $PERCENTAGE"
fi
