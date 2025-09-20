@echo off
echo Connecting to droplet and fixing services...
echo.

REM Copy the fix script to the droplet
scp fix-droplet-services.sh root@159.89.243.148:/tmp/fix-services.sh

REM SSH and run the fix
ssh root@159.89.243.148 "bash /tmp/fix-services.sh"

echo.
echo Fix complete! Testing services...
timeout /t 5 /nobreak > nul

curl -I http://159.89.243.148:3000
curl -I http://159.89.243.148:9090

echo.
echo Services should now be accessible at:
echo   Grafana: http://159.89.243.148:3000
echo   Prometheus: http://159.89.243.148:9090
echo   Alertmanager: http://159.89.243.148:9093
pause