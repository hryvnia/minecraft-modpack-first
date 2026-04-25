#!/bin/bash

# Config
PACK_NAME="Spontan"
MC_VERSION="1.21.1"
NEOFORGE_VERSION="21.1.228"
PACK_TOML_URL="https://hryvnia.github.io/minecraft-modpack-first/spontan/pack.toml"
BOOTSTRAP_URL="https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar"
OUTPUT_ZIP="spontan.zip"

echo "Building $PACK_NAME..."

# Clean
rm -rf build_tmp
mkdir -p build_tmp/.minecraft

# Download bootstrap
echo "Downloading packwiz-installer-bootstrap..."
curl -L "$BOOTSTRAP_URL" -o "build_tmp/.minecraft/packwiz-installer-bootstrap.jar"

# Create mmc-pack.json
cat > build_tmp/mmc-pack.json << EOF
{
    "components": [
        {
            "important": true,
            "uid": "net.minecraft",
            "version": "$MC_VERSION"
        },
        {
            "uid": "net.neoforged",
            "version": "$NEOFORGE_VERSION"
        }
    ],
    "formatVersion": 1
}
EOF

# Create instance.cfg
cat > build_tmp/instance.cfg << EOF
InstanceType=OneSix
OverrideCommands=true
PreLaunchCommand="\$INST_JAVA" -jar "\$INST_MC_DIR/packwiz-installer-bootstrap.jar" $PACK_TOML_URL
name=$PACK_NAME
EOF

# Build zip
cd build_tmp
zip -r "../$OUTPUT_ZIP" .
cd ..
rm -rf build_tmp

echo ""
echo "Done! $OUTPUT_ZIP is ready to distribute."
echo "Users: Add Instance -> Import -> select $OUTPUT_ZIP"
