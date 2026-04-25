#!/bin/bash

NEOFORGE_VERSION="21.1.228"
PACK_TOML_URL="https://hryvnia.github.io/minecraft-modpack-first/spontan/pack.toml"
INSTALLER="neoforge-${NEOFORGE_VERSION}-installer.jar"
BOOTSTRAP="packwiz-installer-bootstrap.jar"

echo "=== Spontan Server Setup ==="

echo "Downloading NeoForge ${NEOFORGE_VERSION} installer..."
curl -L "https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/neoforge-${NEOFORGE_VERSION}-installer.jar" -o "$INSTALLER"

echo "Installing NeoForge server..."
java -jar "$INSTALLER" --installServer
rm "$INSTALLER"

echo "Downloading packwiz-installer-bootstrap..."
curl -L "https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar" -o "$BOOTSTRAP"

echo "Creating start.sh..."
cat > start.sh << EOF
#!/bin/bash
java -jar packwiz-installer-bootstrap.jar --side server $PACK_TOML_URL
./run.sh
EOF
chmod +x start.sh

echo ""
echo "Done! Run ./start.sh to launch the server."
