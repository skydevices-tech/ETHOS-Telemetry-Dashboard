**INAV DASHBOARD FOR ETHOS**

Inav dashboard provides a simple widget for inav that presents core inav information in an easy to use way.

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash1.png?raw=true" width="800" alt="DASH1">

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash2.png?raw=true" width="800" alt="DASH2">

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash3.png?raw=true" width="800" alt="DASH3">

----
**Protocols Support**
The dashboard supports ELRS, CRSF, FBUS, FPORT, SPORT, MLRS sensors.  Support for frsky sensors requires Inav 8 and higher.

**Inav Support**
Due to ethos not recognising the malformed Tmp sensor that was used for 'satellite' info, the dashboard will only work with Inav 8.0 and higher when using Frsky Protocols.

**Setup Notes**
Download the release and place it on your radio in SD:/scripts/inav-dashboard/.  The widget will then be availiable to use in any of the full screen layouts.
Optionally you can use the Ethos Suite to install the widget for you. 
Remember to clear and rediscover sensors in the telemetry tab in your radio
If you want to use non metric system (for example altitude in feet) then you need to modify the discovered sensors and change the unit there. Ethos will automatically convert the data so your 120m will be displayed as 400ft.

**Sensor configuration**
If using frsky, you are adviced to use the following command in INAV Configurator CLI tab:

```
set frsky_pitch_roll = ON
```

This will ensure the artificial horizon works.

**Changing layouts**
To change the layout, make sure the widget is selected by pressing the middle button of the rotary selector on the right, then press the middle button on the left hand button pad.  There are three layouts to cycle through.  The system will remember the last selected layout and show that on reboot.


-----
I hope you enjoy this widget. It has been a fun one to make.   Feel free to provide feedback via git.    Round 2 can't happen without constructive feedback. 

[![Donate](https://github.com/robthomson/RF2STATUS/blob/main/git/paypal-donate-button.png?raw=true)](https://www.paypal.com/donate/?hosted_button_id=SJVE2326X5R7A)
