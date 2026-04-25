@echo off
setlocal

set NEOFORGE_VERSION=21.1.228
set PACK_TOML_URL=https://hryvnia.github.io/minecraft-modpack-first/spontan/pack.toml
set SERVER_DIR=spontan-server

echo === Spontan Server Setup ===

mkdir "%SERVER_DIR%"
cd "%SERVER_DIR%"

echo Downloading NeoForge %NEOFORGE_VERSION% installer...
curl -L "https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar" -o "neoforge-installer.jar"

echo Installing NeoForge server...
java -jar "neoforge-installer.jar" --installServer
del "neoforge-installer.jar"

echo Downloading packwiz-installer-bootstrap...
curl -L "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar" -o "packwiz-installer-bootstrap.jar"

echo Creating start.bat...
(
    echo @echo off
    echo java -jar packwiz-installer-bootstrap.jar --side server %PACK_TOML_URL%
    echo call run.bat
) > start.bat

echo.
echo Done! Server is in .\%SERVER_DIR% — run start.bat to launch.
endlocal
