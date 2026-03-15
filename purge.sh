#!/bin/bash
echo "Purging jsDelivr cache..."
curl -s https://purge.jsdelivr.net/gh/hryvnia/minecraft-modpack-first@main/pack.toml
curl -s https://purge.jsdelivr.net/gh/hryvnia/minecraft-modpack-first@main/index.toml
echo "Done!"
