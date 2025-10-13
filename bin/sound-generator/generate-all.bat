@echo off
setlocal

REM Official voices can be found here:  https://github.com/FrSkyRC/ETHOS-Feedback-Community/blob/1.6/tools/audio_packs.json

REM English - Default
python generate-googleapi.py --csv en.csv --voice en-US-Wavenet-F --base-dir en --variant default --engine google 


REM copy just english to the release folder
xcopy soundpack\en\ ..\..\scripts\inav-dashboard\audio\en\ /E /I /Y

endlocal
