**INAV DASHBOARD FOR ETHOS**

Inav dashboard is provides  a simple widget for inav that presents core inav information in an easy to use way.

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash1.png?raw=true" width="800" alt="DASH1">

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash2.png?raw=true" width="800" alt="DASH2">

<img src="https://github.com/robthomson/inav-dashboard-ethos/blob/main/.github/gfx/dash3.png?raw=true" width="800" alt="DASH3">

----
**Protocols Support**
The dashboard supports ELRS, CRSF, FBUS, FPORT, SPORT sensors.  Support for frsky sensors requires inav 8 and higher.

**Inav Support**
Due to ethos not recognising the malformed Tmp sensor that was used for 'satellite' info, the dashboard will only work with Inav 8.0 and higher when using Frsky Protocols.

**Setup Notes**
Download the release and place it on your radio in SD:/scripts/inav-dashboard/.  The widget will then be availiable to use in any of the full screen layouts.

**Sensor configuration**
If using frsky, you are adviced to use the following cli commands:

```
set frsky_pitch_roll = ON
```

This will ensure the artificial horizon works.

**Changing layouts**
To change the layout, make sure the widget is selected then press the middle button on the left hand button pad.  There are three layouts to cycle through.  The system will remember the last selected layout and show that on reboot.


-----
I hope you enjoy this widget. It has been a fun one to make.   Feel free to provide feedback via git.    Round 2 cant happen without constructive feedback. 

[![Donate](https://github.com/robthomson/RF2STATUS/blob/main/git/paypal-donate-button.png?raw=true)](https://www.paypal.com/donate/?hosted_button_id=SJVE2326X5R7A)