@echo off
setlocal

set NEOFORGE_VERSION=21.1.228
set PACK_TOML_URL=https://hryvnia.github.io/minecraft-modpack-first/spontan/pack.toml
set INSTALLER=neoforge-%NEOFORGE_VERSION%-installer.jar
set BOOTSTRAP=packwiz-installer-bootstrap.jar

echo === Spontan Server Setup ===

echo Downloading NeoForge %NEOFORGE_VERSION% installer...
curl -L "https://maven.neoforged.net/releases/net/neoforged/neoforge/%NEOFORGE_VERSION%/neoforge-%NEOFORGE_VERSION%-installer.jar" -o "%INSTALLER%"

echo Installing NeoForge server...
java -jar "%INSTALLER%" --installServer
del "%INSTALLER%"

echo Downloading packwiz-installer-bootstrap...
curl -L "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar" -o "%BOOTSTRAP%"

echo Creating start.bat...
(
    echo @echo off
    echo java -jar packwiz-installer-bootstrap.jar --side server %PACK_TOML_URL%
    echo call run.bat
) > start.bat

echo.
echo Done! Run start.bat to launch the server.
endlocal
